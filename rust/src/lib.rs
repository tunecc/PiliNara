//! PiliNara native library
//! 
//! Provides Rust implementations for:
//! - Animated WebP encoding (replacing Android Bitmap.compress)
//! - Audio normalization (dynaudnorm-style)
//!
//! ## Architecture
//! 
//! Android builds use cargo-ndk or manual NDK toolchain configuration.
//! The JNI interface is in `android_entry.rs` (only compiled for Android targets).

extern crate std;

// WebP encoding module
pub mod webp;
// Audio normalization module
pub mod audio;

#[cfg(target_os = "android")]
mod android_entry;

#[cfg(not(target_os = "android"))]
pub use webp::{AnimatedWebpEncoder, WebpError};
#[cfg(not(target_os = "android"))]
pub use audio::{AudioNormalizer, AudioNormalizationConfig};
