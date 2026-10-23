//! Focus-scoped GTK clipboard for compositors without data-control support.
//! All GTK work is queued onto the embedder's main loop, never a worker thread.
use arboard::{ClipboardData, ClipboardFormat};
use gtk::{gdk, glib, prelude::*, Clipboard, TargetEntry, TargetFlags};
use hbb_common::{bail, ResultType};
use std::{sync::mpsc, time::Duration};

pub fn enabled() -> bool {
    cfg!(feature = "flutter")
        && std::env::var("RUSTDESK_WAYLAND_CLIPBOARD").as_deref() == Ok("1")
        && std::env::var("GDK_BACKEND").as_deref() == Ok("wayland")
}

fn dispatch<T: Send + 'static>(
    work: impl FnOnce(mpsc::Sender<ResultType<T>>) + Send + 'static,
) -> ResultType<T> {
    // Waiting here on GTK's own thread would deadlock the asynchronous request.
    if glib::MainContext::default().is_owner() {
        bail!("Native clipboard must be requested from a worker thread");
    }
    let (tx, rx) = mpsc::channel();
    glib::idle_add_once(move || {
        if let Err(err) = gtk::init() {
            let _ = tx.send(Err(err.into()));
            return;
        }
        work(tx);
    });
    rx.recv_timeout(Duration::from_secs(2))?
}

pub fn get(formats: &[ClipboardFormat]) -> ResultType<Vec<ClipboardData>> {
    let text = formats.iter().any(|f| matches!(f, ClipboardFormat::Text));
    if !text {
        return Ok(Vec::new());
    }
    dispatch(move |tx| {
        let clipboard = Clipboard::get(&gdk::SELECTION_CLIPBOARD);
        // Preserve the existing owner marker so remote updates do not echo back.
        clipboard.request_contents(
            &gdk::Atom::intern(crate::clipboard::RUSTDESK_CLIPBOARD_OWNER_FORMAT),
            move |clipboard, selection| {
                let marker = selection.data();
                clipboard.request_text(move |_, text| {
                    let mut data = Vec::new();
                    if let Some(text) = text {
                        data.push(ClipboardData::Text(text.to_string()));
                    }
                    if !marker.is_empty() {
                        data.push(ClipboardData::Special((
                            crate::clipboard::RUSTDESK_CLIPBOARD_OWNER_FORMAT.to_owned(),
                            marker,
                        )));
                    }
                    let _ = tx.send(Ok(data));
                });
            },
        );
    })
}

pub fn set(data: &[ClipboardData]) -> ResultType<()> {
    let Some(text) = data.iter().find_map(|d| match d {
        ClipboardData::Text(text) => Some(text.clone()),
        _ => None,
    }) else {
        bail!("Native Wayland clipboard currently supports plain text only");
    };
    let marker = data.iter().find_map(|d| match d {
        ClipboardData::Special((name, value))
            if name == crate::clipboard::RUSTDESK_CLIPBOARD_OWNER_FORMAT =>
        {
            Some(value.clone())
        }
        _ => None,
    });
    dispatch(move |tx| {
        let mut targets = vec![
            TargetEntry::new("UTF8_STRING", TargetFlags::empty(), 0),
            TargetEntry::new("text/plain;charset=utf-8", TargetFlags::empty(), 0),
            TargetEntry::new("text/plain", TargetFlags::empty(), 0),
        ];
        if marker.is_some() {
            targets.push(TargetEntry::new(
                crate::clipboard::RUSTDESK_CLIPBOARD_OWNER_FORMAT,
                TargetFlags::empty(),
                1,
            ));
        }
        let ok = Clipboard::get(&gdk::SELECTION_CLIPBOARD).set_with_data(
            &targets,
            move |_, selection, info| {
                if info == 0 {
                    selection.set_text(&text);
                } else if let Some(marker) = &marker {
                    selection.set(&selection.target(), 8, marker);
                }
            },
        );
        let _ = tx.send(if ok {
            Ok(())
        } else {
            Err(hbb_common::anyhow::anyhow!(
                "GTK rejected clipboard ownership"
            ))
        });
    })
}

pub fn listen(
    mut handler: impl clipboard_master::ClipboardHandler + Send + 'static,
    stop: mpsc::Receiver<()>,
) -> ResultType<()> {
    dispatch(|tx| {
        let _ = tx.send(Ok(()));
    })?;
    handler.on_clipboard_ready();
    let mut previous = None;
    loop {
        match stop.recv_timeout(Duration::from_millis(crate::clipboard::CLIPBOARD_INTERVAL)) {
            Ok(()) | Err(mpsc::RecvTimeoutError::Disconnected) => break,
            Err(mpsc::RecvTimeoutError::Timeout) => {}
        }
        // GTK 3's Wayland backend does not emit GDK_OWNER_CHANGE. Poll only
        // while this application's window has focus, as required by wl_data_device.
        let focused = dispatch(|tx| {
            let active = gtk::Window::list_toplevels().iter().any(|w| {
                w.downcast_ref::<gtk::Window>()
                    .map_or(false, |w| w.is_active())
            });
            let _ = tx.send(Ok(active));
        })?;
        if !focused {
            continue;
        }
        let data = match get(&[ClipboardFormat::Text]) {
            Ok(data) => data,
            Err(err) => {
                hbb_common::log::trace!("Native clipboard temporarily unavailable: {}", err);
                continue;
            }
        };
        let mut text = None;
        let mut marker = None;
        for item in data {
            match item {
                ClipboardData::Text(value) => text = Some(value),
                ClipboardData::Special((_, value)) => marker = Some(value),
                _ => {}
            }
        }
        let snapshot = (text, marker);
        if previous.as_ref() != Some(&snapshot) {
            previous = Some(snapshot);
            match handler.on_clipboard_change() {
                clipboard_master::CallbackResult::Next => {}
                clipboard_master::CallbackResult::Stop => break,
                clipboard_master::CallbackResult::StopWithError(err) => return Err(err.into()),
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    #[ignore = "requires a live Wayland session; run with DISPLAY unset and --test-threads=1"]
    fn native_text_and_owner_marker_without_x11() -> hbb_common::ResultType<()> {
        use super::*;
        gtk::init()?;
        let main_loop = glib::MainLoop::new(None, false);
        let quit = main_loop.clone();
        let window = gtk::Window::new(gtk::WindowType::Toplevel);
        window.set_title("RustDesk native clipboard regression");
        window.maximize();
        let button =
            gtk::Button::with_label("Click to verify native Chinese clipboard and owner marker");
        window.add(&button);
        let worker = std::rc::Rc::new(std::cell::RefCell::new(None));
        let saved_worker = worker.clone();
        button.connect_clicked(move |button| {
            if saved_worker.borrow().is_some() {
                return;
            }
            button.set_sensitive(false);
            let quit = quit.clone();
            *saved_worker.borrow_mut() = Some(std::thread::spawn(move || {
                let result = (|| -> ResultType<()> {
                    let _context = crate::clipboard::ClipboardContext::new()?;
                    struct Handler(mpsc::Sender<()>, Option<mpsc::Sender<()>>);
                    impl clipboard_master::ClipboardHandler for Handler {
                        fn on_clipboard_ready(&mut self) {
                            if let Some(tx) = self.1.take() {
                                let _ = tx.send(());
                            }
                        }
                        fn on_clipboard_change(&mut self) -> clipboard_master::CallbackResult {
                            let _ = self.0.send(());
                            clipboard_master::CallbackResult::Next
                        }
                    }
                    let (events, changes) = mpsc::channel();
                    let (ready, started) = mpsc::channel();
                    let (stop, stopped) = mpsc::channel();
                    let listener =
                        std::thread::spawn(move || listen(Handler(events, Some(ready)), stopped));
                    started.recv_timeout(Duration::from_secs(2))?;
                    let expected = "中文剪贴板\nWayland ✅";
                    let marker = vec![1, 0];
                    set(&[
                        ClipboardData::Text(expected.to_owned()),
                        ClipboardData::Special((
                            crate::clipboard::RUSTDESK_CLIPBOARD_OWNER_FORMAT.to_owned(),
                            marker.clone(),
                        )),
                    ])?;
                    let actual = get(&[ClipboardFormat::Text])?;
                    if !actual
                        .iter()
                        .any(|d| matches!(d, ClipboardData::Text(t) if t == expected))
                        || !actual
                            .iter()
                            .any(|d| matches!(d, ClipboardData::Special((_, m)) if *m == marker))
                    {
                        bail!("Native clipboard text/owner marker did not round trip");
                    }
                    changes.recv_timeout(Duration::from_secs(2))?;
                    let duplicated = changes.recv_timeout(Duration::from_millis(800)).is_ok();
                    let _ = stop.send(());
                    listener.join().map_err(|_| {
                        hbb_common::anyhow::anyhow!("Listener test worker panicked")
                    })??;
                    if duplicated {
                        bail!("Unchanged clipboard produced duplicate notifications");
                    }
                    Ok(())
                })();
                glib::idle_add_once(move || quit.quit());
                result
            }));
        });
        window.show_all();
        main_loop.run();
        window.close();
        let worker = worker
            .borrow_mut()
            .take()
            .ok_or_else(|| hbb_common::anyhow::anyhow!("No clipboard test input"))?;
        worker
            .join()
            .map_err(|_| hbb_common::anyhow::anyhow!("Clipboard test worker panicked"))?
    }
}
