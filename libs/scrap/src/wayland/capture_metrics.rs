//! PipeWire-local timing: PTS deltas and monotonic arrival deltas have different clocks.
use hbb_common::{
    log,
    serde_json::{self, json},
};
use std::time::{Duration, Instant};

pub struct CaptureMetrics {
    node: u64,
    start: Instant,
    last_pts: Option<u64>,
    last_arrival: Option<Instant>,
    last_size: (usize, usize),
    pulled: usize,
    timeouts: usize,
    duplicates: usize,
    accepted: usize,
    invalid: usize,
    repeated_pts: usize,
    backwards_pts: usize,
    stages: [Vec<f64>; 6],
}

impl CaptureMetrics {
    pub fn new(node: u64) -> Option<Self> {
        (std::env::var("RUSTDESK_DISPLAY_METRICS").as_deref() == Ok("1"))
            .then(|| Self::create(node))
    }

    fn create(node: u64) -> Self {
        Self {
            node,
            start: Instant::now(),
            last_pts: None,
            last_arrival: None,
            last_size: (0, 0),
            pulled: 0,
            timeouts: 0,
            duplicates: 0,
            accepted: 0,
            invalid: 0,
            repeated_pts: 0,
            backwards_pts: 0,
            stages: Default::default(),
        }
    }

    pub fn begin(metrics: &Option<Self>) -> Option<Instant> {
        metrics.as_ref().map(|_| Instant::now())
    }

    pub fn end(metrics: &mut Option<Self>, stage: usize, start: Option<Instant>) {
        if let (Some(metrics), Some(start)) = (metrics, start) {
            push(&mut metrics.stages[stage], start.elapsed());
        }
    }

    pub fn pulled(&mut self, present: bool) {
        if !present {
            self.timeouts += 1;
            return;
        }
        self.pulled += 1;
        let now = Instant::now();
        if let Some(previous) = self.last_arrival.replace(now) {
            push(&mut self.stages[4], now.duration_since(previous));
        }
    }

    pub fn buffer(&mut self, pts: Option<u64>, size: (usize, usize)) {
        self.last_size = size;
        if let (Some(previous), Some(current)) = (self.last_pts, pts) {
            if current > previous {
                push(
                    &mut self.stages[5],
                    Duration::from_nanos(current - previous),
                );
            } else if current == previous {
                self.repeated_pts += 1;
            } else {
                self.backwards_pts += 1;
            }
        }
        self.last_pts = pts;
    }

    pub fn compared(&mut self, duplicate: bool) {
        self.duplicates += usize::from(duplicate);
    }
    pub fn accepted(&mut self) {
        self.accepted += 1;
    }
    pub fn invalid(&mut self) {
        self.invalid += 1;
    }

    fn snapshot(&mut self, elapsed: Duration) -> serde_json::Value {
        let stages: Vec<_> = self.stages.iter_mut().map(|v| {
            v.sort_unstable_by(f64::total_cmp);
            let n = v.len();
            let value = if n == 0 { json!({"samples": 0}) } else {
                json!({"samples": n, "p50": v[(n-1)/2], "p95": v[(n*95).div_ceil(100)-1], "max": v[n-1]})
            };
            v.clear(); value
        }).collect();
        let result = json!({"node": self.node, "width": self.last_size.0,
            "height": self.last_size.1, "window_ms": elapsed.as_secs_f64()*1000.,
            "samples_pulled": self.pulled, "pull_timeouts": self.timeouts,
            "duplicate_pixels": self.duplicates, "accepted_buffers": self.accepted,
            "invalid_buffers": self.invalid, "repeated_pts": self.repeated_pts,
            "backwards_pts": self.backwards_pts, "pull_wait_ms": stages[0],
            "map_ms": stages[1], "compare_copy_ms": stages[2], "crop_copy_ms": stages[3],
            "arrival_interval_ms": stages[4], "pts_interval_ms": stages[5]});
        self.pulled = 0;
        self.timeouts = 0;
        self.duplicates = 0;
        self.accepted = 0;
        self.invalid = 0;
        self.repeated_pts = 0;
        self.backwards_pts = 0;
        result
    }

    pub fn report(&mut self) {
        let elapsed = self.start.elapsed();
        if elapsed >= Duration::from_secs(1) {
            log::info!("pipewire_capture_metrics {}", self.snapshot(elapsed));
            self.start = Instant::now();
        }
    }
}

fn push(values: &mut Vec<f64>, duration: Duration) {
    if values.len() < 512 {
        values.push(duration.as_secs_f64() * 1000.);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn separates_pts_duplicates_and_timeouts_across_windows() {
        let mut m = CaptureMetrics::create(7);
        m.buffer(Some(1_000_000), (3840, 2160));
        m.buffer(Some(17_666_667), (3840, 2160));
        m.pulled(true);
        m.pulled(false);
        m.compared(true);
        m.accepted();
        let report = m.snapshot(Duration::from_secs(1));
        assert_eq!(report["samples_pulled"], 1);
        assert_eq!(report["pull_timeouts"], 1);
        assert_eq!(report["duplicate_pixels"], 1);
        assert!((report["pts_interval_ms"]["p50"].as_f64().unwrap() - 16.666667).abs() < 0.000001);
        m.buffer(Some(17_666_667), (3840, 2160));
        m.buffer(Some(0), (3840, 2160));
        let next = m.snapshot(Duration::from_secs(1));
        assert_eq!(next["samples_pulled"], 0);
        assert_eq!(next["repeated_pts"], 1);
        assert_eq!(next["backwards_pts"], 1);
        assert_eq!(next["pts_interval_ms"]["samples"], 0);
    }
}

/// Count buffers before videoconvert/appsink so downstream dropping is observable.
pub fn attach_source_probe(source: &gstreamer::Element, node: u64) {
    use gstreamer::{prelude::*, PadProbeData, PadProbeReturn, PadProbeType};
    use std::sync::Mutex;
    let Some(pad) = source.static_pad("src") else {
        log::warn!("PipeWire source metrics unavailable: no source pad");
        return;
    };
    let metrics = Mutex::new(CaptureMetrics::create(node));
    pad.add_probe(PadProbeType::BUFFER, move |_, info| {
        if let Some(PadProbeData::Buffer(buffer)) = &info.data {
            let mut metrics = metrics.lock().unwrap();
            let elapsed = metrics.start.elapsed();
            if elapsed >= Duration::from_secs(1) {
                let data = metrics.snapshot(elapsed);
                log::info!(
                    "pipewire_source_metrics {}",
                    json!({"node": node,
                    "window_ms": data["window_ms"], "buffers": data["samples_pulled"],
                    "pts_interval_ms": data["pts_interval_ms"],
                    "arrival_interval_ms": data["arrival_interval_ms"],
                    "repeated_pts": data["repeated_pts"], "backwards_pts": data["backwards_pts"]})
                );
                metrics.start = Instant::now();
            }
            metrics.pulled(true);
            metrics.buffer(buffer.pts().map(|pts| pts.nseconds()), (0, 0));
        }
        PadProbeReturn::Ok
    });
}
