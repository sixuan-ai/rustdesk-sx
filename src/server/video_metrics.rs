//! Per-display server stages. Enqueue time does not include socket transmission.
use hbb_common::{log, serde_json::json};
use std::time::{Duration, Instant};

pub struct VideoMetrics {
    start: Instant,
    stages: [Vec<f64>; 4],
}

impl VideoMetrics {
    pub fn new() -> Option<Self> {
        (std::env::var("RUSTDESK_DISPLAY_METRICS").as_deref() == Ok("1")).then(|| Self {
            start: Instant::now(),
            stages: Default::default(),
        })
    }

    pub fn begin(metrics: &Option<Self>) -> Option<Instant> {
        metrics.as_ref().map(|_| Instant::now())
    }

    pub fn end(metrics: &mut Option<Self>, stage: usize, start: Option<Instant>) {
        if let (Some(metrics), Some(start)) = (metrics, start) {
            let samples = &mut metrics.stages[stage];
            if samples.len() < 512 {
                samples.push(start.elapsed().as_secs_f64() * 1000.);
            }
        }
    }

    pub fn report(
        &mut self,
        display: usize,
        dimensions: (usize, usize),
        hardware: bool,
        target_fps: u32,
    ) {
        let elapsed = self.start.elapsed();
        if elapsed < Duration::from_secs(1) {
            return;
        }
        let stages: Vec<_> = self
            .stages
            .iter_mut()
            .map(|samples| {
                samples.sort_unstable_by(f64::total_cmp);
                let n = samples.len();
                let value = if n == 0 {
                    json!({"samples": 0})
                } else {
                    json!({"samples": n, "p50": samples[(n - 1) / 2],
                    "p95": samples[(n * 95).div_ceil(100) - 1], "max": samples[n - 1]})
                };
                samples.clear();
                value
            })
            .collect();
        log::info!(
            "server_display_metrics {}",
            json!({"display": display,
            "width": dimensions.0, "height": dimensions.1, "hardware_encoder": hardware, "target_fps": target_fps,
            "window_ms": elapsed.as_secs_f64() * 1000., "capture_call_ms": stages[0],
            "pixel_convert_ms": stages[1], "encode_ms": stages[2], "enqueue_ms": stages[3]})
        );
        self.start = Instant::now();
    }
}

pub struct VideoSendMetrics {
    displays: std::collections::HashMap<i32, (Instant, usize, Vec<f64>, Vec<f64>)>,
}

impl VideoSendMetrics {
    pub fn new() -> Option<Self> {
        (std::env::var("RUSTDESK_DISPLAY_METRICS").as_deref() == Ok("1")).then(|| Self {
            displays: Default::default(),
        })
    }

    pub fn record(
        &mut self,
        message: &base::message_proto::Message,
        wait: Duration,
        write: Duration,
        depth: usize,
    ) {
        use base::message_proto::message;
        let Some(message::Union::VideoFrame(frame)) = &message.union else {
            return;
        };
        let (start, peak, waits, writes) = self
            .displays
            .entry(frame.display)
            .or_insert_with(|| (Instant::now(), 0, Vec::new(), Vec::new()));
        *peak = (*peak).max(depth);
        if waits.len() < 512 {
            waits.push(wait.as_secs_f64() * 1000.);
            writes.push(write.as_secs_f64() * 1000.);
        }
        if start.elapsed() >= Duration::from_secs(1) {
            waits.sort_unstable_by(f64::total_cmp);
            writes.sort_unstable_by(f64::total_cmp);
            let n = waits.len();
            log::info!(
                "server_video_queue_metrics {}",
                json!({"display": frame.display,
                "shared_queue_peak": *peak, "samples": n,
                "queue_wait_p95_ms": waits[(n * 95).div_ceil(100) - 1],
                "stream_write_p95_ms": writes[(n * 95).div_ceil(100) - 1]})
            );
            *start = Instant::now();
            *peak = 0;
            waits.clear();
            writes.clear();
        }
    }
}

#[cfg(target_os = "linux")]
pub fn append_environment(envs: &mut Vec<(&'static str, String)>) {
    // Ubuntu's sudo fallback intentionally passes only explicit variables to the
    // desktop user. Forward only the explicit capture switch and metrics opt-in.
    if let Ok(value) = std::env::var("RUSTDESK_PIPEWIRE_REUSE_BUFFER") {
        if value == "0" || value == "1" {
            envs.push(("RUSTDESK_PIPEWIRE_REUSE_BUFFER", value));
        }
    }
    if std::env::var("RUSTDESK_DISPLAY_METRICS").as_deref() == Ok("1") {
        envs.push(("RUSTDESK_DISPLAY_METRICS", "1".into()));
        envs.push((
            "RUST_LOG",
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into()),
        ));
    }
}
