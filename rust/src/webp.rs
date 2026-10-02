//! WebP encoding module for animated WebP generation
//! Replaces Kotlin AnimatedWebpMuxer with a cross-platform Rust implementation

use core::fmt;

/// Maximum WebP dimension (matches Android's MAX_WEBP_DIMENSION)
pub const MAX_WEBP_DIMENSION: u32 = 0x1000000;

/// WebP chunk type identifiers
const CHUNK_RIFF: &[u8] = b"RIFF";
const CHUNK_WEBP: &[u8] = b"WEBP";
const CHUNK_VP8X: &[u8] = b"VP8X";
const CHUNK_ANIM: &[u8] = b"ANIM";
const CHUNK_ANMF: &[u8] = b"ANMF";

/// Error type for WebP encoding operations
#[derive(Debug, Clone, PartialEq)]
pub enum WebpError {
    InvalidDimensions,
    DimensionsTooLarge,
    EmptyFrame,
    InvalidDuration,
    FrameOutOfBounds,
    FileTooSmall,
    FileTooLarge,
}

impl fmt::Display for WebpError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            WebpError::InvalidDimensions => write!(f, "Invalid canvas dimensions"),
            WebpError::DimensionsTooLarge => write!(f, "Dimensions exceed maximum ({:?})", MAX_WEBP_DIMENSION),
            WebpError::EmptyFrame => write!(f, "Frame data is empty"),
            WebpError::InvalidDuration => write!(f, "Frame duration must be > 0"),
            WebpError::FrameOutOfBounds => write!(f, "Frame position out of bounds"),
            WebpError::FileTooSmall => write!(f, "Output file too small"),
            WebpError::FileTooLarge => write!(f, "Output file exceeds valid size"),
        }
    }
}

/// Animated WebP encoder
/// 
/// Encodes a sequence of VP8/VP8L frames into an animated WebP file.
/// This replaces the Kotlin AnimatedWebpMuxer with a pure Rust implementation.
#[derive(Debug)]
pub struct AnimatedWebpEncoder {
    width: u32,
    height: u32,
    output: Vec<u8>,
    frame_count: u32,
}

impl AnimatedWebpEncoder {
    /// Create a new encoder with the given canvas dimensions
    pub fn new(width: u32, height: u32) -> Result<Self, WebpError> {
        if width == 0 || height == 0 {
            return Err(WebpError::InvalidDimensions);
        }
        if width > MAX_WEBP_DIMENSION || height > MAX_WEBP_DIMENSION {
            return Err(WebpError::DimensionsTooLarge);
        }

        let mut output = Vec::new();
        
        // Write RIFF header (placeholder size)
        output.extend_from_slice(CHUNK_RIFF);
        output.extend_from_slice(&0u32.to_le_bytes()); // placeholder for file size
        output.extend_from_slice(CHUNK_WEBP);
        
        // Write VP8X chunk (lossless/alpha/animation support)
        output.extend_from_slice(CHUNK_VP8X);
        output.extend_from_slice(&10u32.to_le_bytes()); // chunk size
        // reserved=0, has_alpha=0, has_animation=1, has_xmp=0, has_exif=0
        output.push(0x02);
        // Width - 1 (LE24)
        output.extend_from_slice(&((width - 1) as u32).to_le_bytes()[..3]);
        // Height - 1 (LE24)
        output.extend_from_slice(&((height - 1) as u32).to_le_bytes()[..3]);
        
        // Write ANIM chunk
        output.extend_from_slice(CHUNK_ANIM);
        output.extend_from_slice(&6u32.to_le_bytes()); // chunk size
        output.extend_from_slice(&0u32.to_le_bytes()); // background color (unused)
        output.extend_from_slice(&1u32.to_le_bytes()); // loop count
        
        Ok(AnimatedWebpEncoder {
            width,
            height,
            output,
            frame_count: 0,
        })
    }

    /// Add a frame to the animation
    /// 
    /// `data` should be a VP8 or VP8L bitstream (without WebP container headers).
    /// `duration_ms` is the display duration in milliseconds.
    /// `x` and `y` are the top-left position on the canvas.
    pub fn add_frame(&mut self, data: &[u8], duration_ms: u32, x: u32, y: u32) -> Result<(), WebpError> {
        if data.is_empty() {
            return Err(WebpError::EmptyFrame);
        }
        if duration_ms == 0 {
            return Err(WebpError::InvalidDuration);
        }
        if x + self.width > MAX_WEBP_DIMENSION || y + self.height > MAX_WEBP_DIMENSION {
            return Err(WebpError::FrameOutOfBounds);
        }

        let duration = duration_ms.min(0xFFFFFF);
        let mut header = Vec::with_capacity(16);
        // Left position - 1 (LE24)
        header.extend_from_slice(&((x).to_le_bytes()[..3]));
        // Top position - 1 (LE24)
        header.extend_from_slice(&((y).to_le_bytes()[..3]));
        // Duration (LE24)
        header.extend_from_slice(&duration.to_le_bytes()[..3]);
        header.push(0x02); // disposal method: none
        
        self.output.extend_from_slice(CHUNK_ANMF);
        let chunk_size = (header.len() + data.len()) as u32;
        self.output.extend_from_slice(&chunk_size.to_le_bytes());
        self.output.extend_from_slice(&header);
        self.output.extend_from_slice(data);
        // Pad to even boundary
        if chunk_size & 1 != 0 {
            self.output.push(0);
        }

        self.frame_count += 1;
        Ok(())
    }

    /// Finalize the WebP file and fix the RIFF header size
    pub fn finalize(mut self) -> Result<Vec<u8>, WebpError> {
        let file_size = (self.output.len() - 8) as u32;
        if file_size < 12 {
            return Err(WebpError::FileTooSmall);
        }

        // Update RIFF header size (at offset 4)
        self.output[4..8].copy_from_slice(&file_size.to_le_bytes());

        Ok(self.output)
    }

    /// Returns the number of frames added so far
    pub fn frame_count(&self) -> u32 {
        self.frame_count
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encoder_creation() {
        let encoder = AnimatedWebpEncoder::new(100, 100);
        assert!(encoder.is_ok());
        
        let encoder = AnimatedWebpEncoder::new(0, 100);
        assert_eq!(encoder.unwrap_err(), WebpError::InvalidDimensions);
        
        let encoder = AnimatedWebpEncoder::new(MAX_WEBP_DIMENSION + 1, 100);
        assert_eq!(encoder.unwrap_err(), WebpError::DimensionsTooLarge);
    }

    #[test]
    fn test_add_frame() {
        let mut encoder = AnimatedWebpEncoder::new(10, 10).unwrap();
        // Minimal valid VP8 keyframe header
        let frame_data = vec![0x9d, 0x01, 0x2a];
        
        let result = encoder.add_frame(&frame_data, 100, 0, 0);
        assert!(result.is_ok());
        assert_eq!(encoder.frame_count(), 1);
    }
}
