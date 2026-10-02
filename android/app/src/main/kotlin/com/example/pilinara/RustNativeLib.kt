package com.example.pilinara

import android.util.Log

/**
 * Rust Native Library wrapper.
 * Provides access to Rust-implemented WebP encoder and Audio normalizer.
 */
object RustNativeLib {
    private const val TAG = "RustNativeLib"
    
    init {
        try {
            System.loadLibrary("pilinara_native")
            Log.d(TAG, "Rust native library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Rust native library not found: ${e.message}")
        }
    }
    
    // WebP encoding functions
    private external fun rust_webp_create(width: Int, height: Int): Long
    private external fun rust_webp_add_frame(ptr: Long, data: ByteArray, durationMs: Int, x: Int, y: Int): Int
    private external fun rust_webp_finalize(ptr: Long): ByteArray
    private external fun rust_webp_destroy(ptr: Long)
    
    // Audio normalization functions
    private external fun rust_audio_normalize(input: ByteArray, channels: Int): ByteArray
    
    /**
     * Encode animated WebP from frames
     * @param frames List of WebP frames with their timing
     * @param width Canvas width
     * @param height Canvas height
     * @return Encoded WebP bytes or null on error
     */
    fun encodeAnimatedWebp(frames: List<WebpFrame>, width: Int, height: Int): ByteArray? {
        val ptr = rust_webp_create(width, height)
        if (ptr == 0L) {
            Log.e(TAG, "Failed to create WebP encoder")
            return null
        }
        
        return try {
            for (frame in frames) {
                val result = rust_webp_add_frame(ptr, frame.data, frame.durationMs, frame.x, frame.y)
                if (result != 0) {
                    Log.e(TAG, "Failed to add frame: error code $result")
                    return null
                }
            }
            rust_webp_finalize(ptr)
        } catch (e: Exception) {
            Log.e(TAG, "WebP encoding error: ${e.message}")
            null
        } finally {
            rust_webp_destroy(ptr)
        }
    }
    
    /**
     * Normalize audio samples
     * @param samples Interleaved 16-bit PCM samples
     * @param channels Number of audio channels
     * @return Normalized samples
     */
    fun normalizeAudio(samples: ByteArray, channels: Int): ByteArray {
        return try {
            rust_audio_normalize(samples, channels)
        } catch (e: Exception) {
            Log.e(TAG, "Audio normalization error: ${e.message}")
            samples
        }
    }
    
    /**
     * WebP frame data class
     */
    data class WebpFrame(
        val data: ByteArray,
        val durationMs: Int,
        val x: Int = 0,
        val y: Int = 0
    )
}
