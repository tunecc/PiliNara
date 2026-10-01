package com.example.pilinara.media3

import android.content.Context
import android.graphics.Bitmap
import android.view.PixelCopy
import android.view.SurfaceView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class Media3PlayerBridge(private val context: Context) {
    private var player: ExoPlayer? = null
    private var surfaceView: SurfaceView? = null
    private var eventSink: EventChannel.EventSink? = null

    private var audioGainDb: Float = 0f
    private var audioDynamicEnabled: Boolean = false
    private var audioTargetRmsDb: Float = -16f
    private var audioEqEnabled: Boolean = false
    private var audioEqFreqHz: Float = 1000f
    private var audioEqGainDb: Float = 0f
    private var audioEqQ: Float = 1f
    private var superResolutionMode: String = "disable"

    fun init(eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
    }

    fun createPlayer(): Boolean {
        if (player != null) return true
        val renderersFactory = DefaultRenderersFactory(context).apply {
            setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
        }
        player = ExoPlayer.Builder(context, renderersFactory)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(context)
                    .setDataSourceFactory(createDataSourceFactory())
            )
            .build()
            .apply {
            addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    eventSink?.success(mapOf("event" to "stateChanged", "state" to playbackState))
                }
                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    eventSink?.success(mapOf("event" to "playingChanged", "isPlaying" to isPlaying))
                }
                override fun onPositionDiscontinuity(
                    oldPosition: Player.PositionInfo,
                    newPosition: Player.PositionInfo,
                    reason: Int
                ) {
                    eventSink?.success(mapOf("event" to "positionDiscontinuity", "position" to newPosition.positionMs))
                }
            })
        }
        return true
    }

    fun release() {
        player?.release()
        player = null
        surfaceView = null
        eventSink = null
    }

    private var currentHeaders: Map<String, String> = emptyMap()

    private fun createHttpDataSource(): DataSource.Factory {
        return DefaultHttpDataSource.Factory()
            .setUserAgent(currentHeaders["User-Agent"] ?: currentHeaders["user-agent"])
            .setDefaultRequestProperties(currentHeaders)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(15_000)
    }

    private fun createDataSourceFactory(): DataSource.Factory {
        return DefaultDataSource.Factory(context, createHttpDataSource())
    }

    fun setDataSource(url: String, headers: Map<String, String>?): Boolean {
        var p = player
        currentHeaders = headers?.filterValues { it.isNotEmpty() } ?: emptyMap()
        // Headers are baked into the media source factory, so the player is
        // rebuilt whenever they change.
        if (p != null) {
            p.release()
            p = null
            player = null
            surfaceView = null
        }
        if (!createPlayer()) return false
        p = player ?: return false
        val mediaItem = MediaItem.Builder()
            .setUri(url)
            .build()
        p.setMediaItem(mediaItem)
        p.prepare()
        return true
    }

    fun play(): Boolean { player?.playWhenReady = true; return player != null }
    fun pause(): Boolean { player?.playWhenReady = false; return player != null }
    fun seekTo(positionMs: Long): Boolean { player?.seekTo(positionMs); return player != null }
    fun getPosition(): Long = player?.currentPosition ?: 0L
    fun getDuration(): Long = player?.duration ?: 0L
    fun getBufferedPosition(): Long = player?.bufferedPosition ?: 0L
    fun setSpeed(speed: Float): Boolean { player?.setPlaybackParameters(PlaybackParameters(speed)); return player != null }
    fun setVolume(volume: Float): Boolean { player?.volume = volume.coerceIn(0f, 1f); return player != null }
    fun isPlaying(): Boolean = player?.isPlaying ?: false

    fun setAudioGain(db: Float) { audioGainDb = db }
    fun setAudioDynamic(enabled: Boolean, targetRmsDb: Float) { audioDynamicEnabled = enabled; audioTargetRmsDb = targetRmsDb }
    fun setAudioEq(enabled: Boolean, freqHz: Float, gainDb: Float, q: Float) { audioEqEnabled = enabled; audioEqFreqHz = freqHz; audioEqGainDb = gainDb; audioEqQ = q }
    fun setSuperResolution(mode: String) { superResolutionMode = mode }

    fun captureFrame(result: MethodChannel.Result) {
        val sv = surfaceView
        val p = player
        if (sv == null || p == null) {
            result.error("NO_SURFACE", "No active surface for capture", null)
            return
        }
        val bitmap = Bitmap.createBitmap(sv.width, sv.height, Bitmap.Config.ARGB_8888)
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        PixelCopy.request(
            sv,
            bitmap,
            PixelCopy.OnPixelCopyFinishedListener { copyResult ->
                if (copyResult == PixelCopy.SUCCESS) {
                    val stream = java.io.ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    result.success(stream.toByteArray())
                } else {
                    result.error("CAPTURE_FAILED", "PixelCopy failed: $copyResult", null)
                }
                bitmap.recycle()
            },
            handler,
        )
    }

    fun attachSurface(surfaceView: SurfaceView) {
        this.surfaceView = surfaceView
        // SurfaceView needs a valid holder before ExoPlayer can render into it.
        surfaceView.holder.addCallback(object : android.view.SurfaceHolder.Callback {
            override fun surfaceCreated(holder: android.view.SurfaceHolder) {
                player?.setVideoSurface(holder.surface)
            }

            override fun surfaceChanged(
                holder: android.view.SurfaceHolder,
                format: Int,
                width: Int,
                height: Int
            ) {
                player?.setVideoSurface(holder.surface)
            }

            override fun surfaceDestroyed(holder: android.view.SurfaceHolder) {
                player?.clearVideoSurface()
            }
        })
        surfaceView.holder.surface?.let { player?.setVideoSurface(it) }
    }
}
