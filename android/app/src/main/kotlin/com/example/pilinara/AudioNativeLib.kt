package com.example.pilinara

/**
 * Native audio normalization backed by Rust implementation.
 * Replaces the Kotlin AudioNormalizationProcessor with a Rust dynaudnorm-style implementation.
 */
internal object AudioNativeLib {
    init {
        System.loadLibrary("pilinara_native")
    }

    private external fun normalize(input: ByteArray, channels: Int): ByteArray

    /**
     * Normalize interleaved 16-bit PCM audio samples.
     * @param samples interleaved PCM samples (2 bytes per sample)
     * @param channels number of audio channels
     * @return normalized samples in the same format
     */
    fun normalizeAudio(samples: ByteArray, channels: Int): ByteArray {
        return normalize(samples, channels)
    }
}
