use hbb_common::{anyhow::anyhow, ResultType};

// Split on an even row: each NV12 chroma row belongs to exactly two RGB rows.
pub(super) fn convert(
    src: &[u8], src_stride: usize, width: usize, height: usize, rgba: bool,
    dst: &mut [u8], y_stride: usize, uv_stride: usize, uv_offset: usize,
) -> ResultType<bool> {
    if height < 4 || height % 2 != 0 || width % 2 != 0
        || src_stride < width * 4 || src.len() < src_stride * height
        || y_stride < width || uv_stride < width || uv_offset < y_stride * height
        || dst.len() < uv_offset + uv_stride * (height / 2)
    {
        return Ok(false);
    }
    let split = (height / 2) & !1;
    let (src_top, src_bottom) = src.split_at(src_stride * split);
    let (y, uv) = dst.split_at_mut(uv_offset);
    let (y_top, y_bottom) = y.split_at_mut(y_stride * split);
    let (uv_top, uv_bottom) = uv.split_at_mut(uv_stride * (split / 2));
    let function = if rgba { super::ABGRToNV12 } else { super::ARGBToNV12 };
    let codes = std::thread::scope(|scope| {
        let worker = std::thread::Builder::new().spawn_scoped(scope, move || unsafe {
            function(src_top.as_ptr(), src_stride as _, y_top.as_mut_ptr(), y_stride as _,
                uv_top.as_mut_ptr(), uv_stride as _, width as _, split as _)
        }).map_err(|e| anyhow!("Cannot start NV12 conversion worker: {e}"))?;
        let bottom = unsafe {
            function(src_bottom.as_ptr(), src_stride as _, y_bottom.as_mut_ptr(), y_stride as _,
                uv_bottom.as_mut_ptr(), uv_stride as _, width as _, (height - split) as _)
        };
        worker.join().map(|top| (top, bottom)).map_err(|_| anyhow!("NV12 conversion worker panicked"))
    })?;
    if codes != (0, 0) {
        return Err(anyhow!("NV12 conversion failed: {codes:?}"));
    }
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_serial_conversion_with_padding_and_chroma_split() {
        let (w, h, src_stride, stride) = (18, 6, 84, 32);
        let src: Vec<u8> = (0..src_stride * h).map(|n| ((n * 17) % 251) as u8).collect();
        for rgba in [false, true] {
            let mut parallel = vec![177; stride * h * 2];
            let mut serial = parallel.clone();
            assert!(convert(&src, src_stride, w, h, rgba, &mut parallel, stride, stride, stride*h).unwrap());
            let f = if rgba { super::super::ABGRToNV12 } else { super::super::ARGBToNV12 };
            assert_eq!(unsafe { f(src.as_ptr(), src_stride as _, serial.as_mut_ptr(), stride as _,
                serial.as_mut_ptr().add(stride*h), stride as _, w as _, h as _) }, 0);
            assert_eq!(parallel, serial);
        }
    }
}
