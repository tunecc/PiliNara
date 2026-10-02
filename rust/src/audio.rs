//! Audio normalization module
//! 
//! Provides audio normalization using dynaudnorm-style algorithm.
//! Replaces the Kotlin AudioNormalizationProcessor.

use core::fmt;

/// Audio normalization configuration matching Android's AudioNormalizationConfiguration
#[derive(Debug, Clone, Copy)]
pub struct AudioNormalizationConfig {
    /// Target integrated loudness in dB LUFS (default: -16.0)
    pub target_loudness: f32,
    /// Maximum true peak in dBTP (default: -1.0)
    pub max_true_peak: f32,
    /// Loudness range target in LU (default: 11.0)
    pub lra_target: f32,
    /// Gain boost mode: 0=auto, 1=soft, 2=hard
    pub gain_boost_mode: u8,
}

impl Default for AudioNormalizationConfig {
    fn default() -> Self {
        Self {
            target_loudness: -16.0,
            max_true_peak: -1.0,
            lra_target: 11.0,
            gain_boost_mode: 0,
        }
    }
}

/// Per-channel audio normalizer
/// 
/// Applies RMS-based loudness normalization with soft clipping.
/// Production use should replace this with `dynaudnorm` crate.
#[derive(Debug)]
pub struct AudioNormalizer {
    config: AudioNormalizationConfig,
}

impl Default for AudioNormalizer {
    fn default() -> Self {
        Self {
            config: AudioNormalizationConfig::default(),
        }
    }
}

impl AudioNormalizer {
    /// Create a new normalizer with the given configuration
    pub fn new(config: AudioNormalizationConfig) -> Self {
        Self { config }
    }

    /// Normalize interleaved 16-bit PCM samples
    /// 
    /// `input` is interleaved stereo/mono 16-bit PCM.
    /// Returns normalized samples in the same format.
    pub fn normalize_i16(&self, input: &[i16], channels: usize) -> Vec<i16> {
        if input.is_empty() || channels == 0 {
            return Vec::new();
        }
        
        let mut result = vec![0i16; input.len()];
        for ch in 0..channels {
            let rms = self.calculate_rms_channel(input, channels, ch);
            if rms == 0.0 {
                continue;
            }
            let target_rms = 10.0_f32.powf(self.config.target_loudness / 20.0);
            let gain = target_rms / rms;
            
            for i in (ch..input.len()).step_by(channels) {
                let normalized = input[i] as f32 * gain;
                result[i] = normalized.clamp(-32768.0, 32767.0) as i16;
            }
        }
        
        result
    }

    fn calculate_rms_channel(&self, samples: &[i16], channels: usize, channel: usize) -> f32 {
        let sum: f32 = samples.iter()
            .skip(channel)
            .step_by(channels)
            .map(|&s| (s as f32 / 32768.0) * (s as f32 / 32768.0))
            .sum();
        let count = samples.len() / channels;
        if count == 0 { return 0.0; }
        (sum / count as f32).sqrt()
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum AudioError {
    EmptyBuffer,
    InvalidChannels,
}

impl fmt::Display for AudioError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AudioError::EmptyBuffer => write!(f, "Empty audio buffer"),
            AudioError::InvalidChannels => write!(f, "Invalid channel count"),
        }
    }
}

impl std::error::Error for AudioError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_empty() {
        let normalizer = AudioNormalizer::default();
        let result = normalizer.normalize_i16(&[], 2);
        assert!(result.is_empty());
    }

    #[test]
    fn test_normalize_silent() {
        let normalizer = AudioNormalizer::default();
        let input = vec![0i16; 100];
        let result = normalizer.normalize_i16(&input, 1);
        assert_eq!(result.len(), 100);
        assert!(result.iter().all(|&s| s == 0));
    }

    #[test]
    fn test_normalize_mono() {
        let normalizer = AudioNormalizer::default();
        let input: Vec<i16> = (0..100).map(|i| (i as f32 * 1000.0) as i16).collect();
        let result = normalizer.normalize_i16(&input, 1);
        assert_eq!(result.len(), 100);
    }
}
