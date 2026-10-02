package com.example.pilinara

import java.io.RandomAccessFile

/**
 * Native WebP encoder backed by Rust implementation.
 * Replaces the Kotlin AnimatedWebpMuxer with a cross-platform Rust implementation.
 */
internal object WebpNativeLib {
    init {
        System.loadLibrary("pilinara_native")
    }

    private external fun create(width: Int, height: Int): Long
    private external fun addFrame(ptr: Long, data: ByteArray, durationMs: Int, x: Int, y: Int): Int
    private external fun finalize(ptr: Long): ByteArray

    fun encode(frames: List<WebpFrame>, width: Int, height: Int): ByteArray? {
        val ptr = create(width, height)
        if (ptr == -1L) return null

        return try {
            for (frame in frames) {
                val result = addFrame(ptr, frame.data, frame.durationMs, frame.x, frame.y)
                if (result != 0) return null
            }
            finalize(ptr)
        } finally {
            // Note: In production, add a destroy/cleanup native function
        }
    }

    data class WebpFrame(
        val data: ByteArray,
        val durationMs: Int,
        val x: Int = 0,
        val y: Int = 0,
    )
}
