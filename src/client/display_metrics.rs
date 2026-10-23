//! Opt-in client telemetry. Timings start after transport receipt, not at capture.
use base::message_proto::VideoFrame;
use hbb_common::{
    log,
    serde_json::{self, json},
};
use std::{
    sync::{Arc, Mutex, OnceLock},
    time::{Duration, Instant},
};

pub type Metrics = Option<Arc<Mutex<DisplayMetrics>>>;
const SAMPLE_LIMIT: usize = 512;

pub struct QueuedVideoFrame {
    pub frame: VideoFrame,
    pub received_at: Option<Instant>,
}

impl QueuedVideoFrame {
    pub fn new(frame: VideoFrame, metrics: &Metrics) -> Self {
        let received_at = metrics.as_ref().map(|metrics| {
            metrics.lock().unwrap().received();
            Instant::now()
        });
        Self { frame, received_at }
    }
}

#[derive(Default)]
pub struct DisplayMetrics {
    pending: usize,
    peak: usize,
    received: usize,
    submitted: usize,
    overflow: usize,
    discarded: usize,
    errors: usize,
    dimensions: (usize, usize),
    decoder: String,
    queue_ms: Vec<f64>,
    decode_ms: Vec<f64>,
    submit_ms: Vec<f64>,
}

impl DisplayMetrics {
    pub fn enabled() -> Metrics {
        static ENABLED: OnceLock<bool> = OnceLock::new();
        if *ENABLED.get_or_init(|| std::env::var("RUSTDESK_DISPLAY_METRICS").as_deref() == Ok("1"))
        {
            Some(Arc::new(Mutex::new(Self::default())))
        } else {
            None
        }
    }

    fn received(&mut self) {
        self.received += 1;
        self.pending += 1;
        self.peak = self.peak.max(self.pending);
    }

    pub fn overflow(&mut self) {
        self.pending = self.pending.saturating_sub(1);
        self.overflow += 1;
    }

    pub fn dequeue(&mut self, queued_at: Instant, discarded: bool) {
        self.pending = self.pending.saturating_sub(1);
        sample(&mut self.queue_ms, queued_at.elapsed());
        self.discarded += usize::from(discarded);
    }

    pub fn submitted(
        &mut self,
        decode: Duration,
        submit: Duration,
        dimensions: (usize, usize),
        decoder: String,
    ) {
        self.submitted += 1;
        self.dimensions = dimensions;
        self.decoder = decoder;
        sample(&mut self.decode_ms, decode);
        sample(&mut self.submit_ms, submit);
    }

    pub fn error(&mut self) {
        self.errors += 1;
    }

    fn snapshot(
        &mut self,
        display: usize,
        elapsed: Duration,
        encoded_queue: usize,
    ) -> serde_json::Value {
        let report = json!({
            "display": display, "window_ms": elapsed.as_secs_f64() * 1000.,
            "width": self.dimensions.0, "height": self.dimensions.1, "decoder": self.decoder,
            "received_fps": self.received as f64 / elapsed.as_secs_f64(),
            // A callback is not a compositor presentation acknowledgement.
            "submitted_fps": self.submitted as f64 / elapsed.as_secs_f64(),
            "pending": self.pending, "pending_peak": self.peak, "encoded_queue": encoded_queue,
            "overflow": self.overflow, "discarded": self.discarded, "decode_errors": self.errors,
            "queue_wait_ms": distribution(&self.queue_ms),
            "decode_convert_ms": distribution(&self.decode_ms),
            "flutter_submit_ms": distribution(&self.submit_ms),
        });
        self.received = 0;
        self.submitted = 0;
        self.overflow = 0;
        self.discarded = 0;
        self.errors = 0;
        self.peak = self.pending;
        self.queue_ms.clear();
        self.decode_ms.clear();
        self.submit_ms.clear();
        report
    }

    pub fn report(&mut self, display: usize, elapsed: Duration, encoded_queue: usize) {
        log::info!(
            "display_metrics {}",
            self.snapshot(display, elapsed, encoded_queue)
        );
    }
}

fn sample(samples: &mut Vec<f64>, duration: Duration) {
    // Bound memory and sorting work even if a peer sends far above the requested FPS.
    if samples.len() < SAMPLE_LIMIT {
        samples.push(duration.as_secs_f64() * 1000.);
    }
}

fn distribution(samples: &[f64]) -> serde_json::Value {
    if samples.is_empty() {
        return json!({"samples": 0});
    }
    let mut sorted = samples.to_vec();
    sorted.sort_unstable_by(f64::total_cmp);
    json!({"samples": sorted.len(), "p50": sorted[(sorted.len() - 1) / 2],
        "p95": sorted[(sorted.len() * 95).div_ceil(100) - 1], "max": sorted[sorted.len() - 1]})
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_distinct_stages_and_resets_window_without_losing_backlog() {
        let mut m = DisplayMetrics::default();
        m.received();
        m.received();
        m.dequeue(Instant::now(), false);
        m.submitted(
            Duration::from_millis(5),
            Duration::from_millis(2),
            (3840, 2160),
            "aom/software".into(),
        );
        let s = m.snapshot(1, Duration::from_secs(1), 1);
        assert_eq!(s["submitted_fps"], 1.0);
        assert_eq!(s["received_fps"], 2.0);
        assert_eq!(s["decode_convert_ms"]["p95"], 5.0);
        assert_eq!(s["flutter_submit_ms"]["p95"], 2.0);
        let next = m.snapshot(1, Duration::from_secs(1), 1);
        assert_eq!(next["pending"], 1);
        assert_eq!(next["submitted_fps"], 0.0);
        assert_eq!(next["decode_convert_ms"]["samples"], 0);
    }

    #[test]
    fn bounded_samples_and_overflow_accounting() {
        let mut m = DisplayMetrics::default();
        m.received();
        m.received();
        m.overflow();
        m.dequeue(Instant::now(), true);
        for i in 1..=1000 {
            sample(&mut m.decode_ms, Duration::from_millis(i));
        }
        let s = m.snapshot(0, Duration::from_secs(1), 0);
        assert_eq!(s["pending"], 0);
        assert_eq!(s["overflow"], 1);
        assert_eq!(s["discarded"], 1);
        assert_eq!(s["decode_convert_ms"]["samples"], SAMPLE_LIMIT);
        assert_eq!(s["decode_convert_ms"]["p95"], 487.0);
    }
}
