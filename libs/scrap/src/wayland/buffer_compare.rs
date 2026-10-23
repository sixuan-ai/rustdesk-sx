use gstreamer::{buffer::Readable, MappedBuffer};

pub fn same_pixels(previous: Option<&MappedBuffer<Readable>>, current: &[u8]) -> bool {
    previous.is_some_and(|previous| previous.as_slice() == current)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_changes_including_last_pixel_and_size() {
        gstreamer::init().unwrap();
        let frame = vec![9; 3840 * 2160 * 4];
        let previous = gstreamer::Buffer::from_slice(frame.clone())
            .into_mapped_buffer_readable().unwrap();
        assert!(!same_pixels(None, &frame));
        assert!(same_pixels(Some(&previous), &frame));
        let mut changed = frame;
        *changed.last_mut().unwrap() = 8;
        assert!(!same_pixels(Some(&previous), &changed));
        assert!(!same_pixels(Some(&previous), &changed[..changed.len() - 4]));
    }

    #[test]
    fn retained_mapping_survives_upstream_buffer_reuse() {
        gstreamer::init().unwrap();
        let mut upstream = gstreamer::Buffer::from_slice(vec![1, 2, 3, 4]);
        let previous = upstream.clone().into_mapped_buffer_readable().unwrap();
        upstream.make_mut().copy_from_slice(0, &[4, 3, 2, 1]).unwrap();
        assert!(same_pixels(Some(&previous), &[1, 2, 3, 4]));
        assert!(!same_pixels(Some(&previous), &[4, 3, 2, 1]));
    }
}
