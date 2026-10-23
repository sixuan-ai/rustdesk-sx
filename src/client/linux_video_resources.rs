use base::message_proto::CaptureDisplays;
use std::collections::HashSet;

#[derive(Default)]
pub(super) struct VideoSelection(Option<HashSet<usize>>);

impl VideoSelection {
    pub fn update(&mut self, request: &CaptureDisplays, count: usize) -> bool {
        // Incremental/legacy requests retain their existing behavior. Flutter's
        // full set already includes displays used by its other open windows.
        if !request.add.is_empty() || !request.sub.is_empty() || count == 0 {
            self.0 = None;
            return false;
        }
        let selected: HashSet<_> = request.set.iter().copied()
            .filter(|d| *d >= 0 && (*d as usize) < count)
            .map(|d| d as usize).collect();
        if !request.set.is_empty() && selected.is_empty() {
            return false; // Match the server's rejection of an entirely invalid set.
        }
        self.0 = Some(selected);
        true
    }

    pub fn accepts(&self, display: usize) -> bool {
        self.0.as_ref().is_none_or(|selected| selected.contains(&display))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn full_selection_rejects_late_frames_and_keeps_other_windows() {
        let mut selection = VideoSelection::default();
        assert!(selection.accepts(0));
        let mut request = CaptureDisplays::new();
        request.set = vec![1];
        assert!(selection.update(&request, 2));
        assert!(!selection.accepts(0));
        assert!(selection.accepts(1));
        request.set = vec![0, 1];
        selection.update(&request, 2);
        assert!(selection.accepts(0) && selection.accepts(1));
        request.set.clear();
        selection.update(&request, 2);
        assert!(!selection.accepts(0) && !selection.accepts(1));
    }

    #[test]
    fn invalid_and_incremental_requests_preserve_legacy_behavior() {
        let mut selection = VideoSelection::default();
        let mut request = CaptureDisplays::new();
        request.set = vec![0];
        selection.update(&request, 2);
        request.set = vec![-1, 2];
        assert!(!selection.update(&request, 2));
        assert!(selection.accepts(0) && !selection.accepts(1));
        request.add = vec![1];
        assert!(!selection.update(&request, 2));
        assert!(selection.accepts(0) && selection.accepts(1));
    }
}
