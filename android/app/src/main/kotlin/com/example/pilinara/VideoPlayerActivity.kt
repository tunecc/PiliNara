package com.example.pilinara

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

/**
 * Pure native Android video player activity using Media3 ExoPlayer.
 * This replaces the Flutter-based video player.
 */
class VideoPlayerActivity : AppCompatActivity() {
    
    companion object {
        fun newInstance(context: Context, videoUrl: String, headers: Map<String, String> = emptyMap()): Intent {
            return Intent(context, VideoPlayerActivity::class.java).apply {
                putExtra("video_url", videoUrl)
                putExtra("headers", headers.toTypedArray())
                putExtra("autoplay", true)
            }
        }
    }
    
    private lateinit var player: ExoPlayer
    private lateinit var playerView: PlayerView
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Keep screen on during playback
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        playerView = PlayerView(this).apply {
            useController = true
            resizeMode = androidx.media3.ui.AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
        
        player = ExoPlayer.Builder(this)
            .setHandleAudioBecomingNoisy(true)
            .build()
        
        playerView.player = player
        setContentView(playerView)
        
        // Prepare video
        val videoUrl = intent.getStringExtra("video_url") ?: ""
        val headers = parseHeaders(intent)
        
        if (videoUrl.isNotEmpty()) {
            val mediaItem = MediaItem.Builder()
                .setUri(Uri.parse(videoUrl))
                .setHttpUserAgent("Mozilla/5.0 BiliDroid/2.0.1")
                .setHttpHeaders(headers)
                .build()
            
            player.setMediaItem(mediaItem)
            player.prepare()
            
            if (intent.getBooleanExtra("autoplay", true)) {
                player.play()
            }
        }
        
        // Setup player listeners
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_ENDED -> finish()
                    Player.STATE_BUFFERING -> {
                        // Show buffering indicator
                    }
                    Player.STATE_READY -> {
                        // Player ready
                    }
                }
            }
            
            override fun onIsPlayingChanged(playing: Boolean) {
                // Update UI based on playback state
            }
        })
    }
    
    override fun onResume() {
        super.onResume()
        if (!player.isPlaying) {
            player.prepare()
            player.play()
        }
    }
    
    override fun onPause() {
        super.onPause()
        if (player.isPlaying) {
            player.pause()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        player.release()
    }
    
    private fun parseHeaders(intent: Intent): Map<String, String> {
        val headers = mutableMapOf<String, String>()
        val headerArray = intent.getStringArrayExtra("headers") ?: return headers
        for (i in headerArray.indices step 2) {
            if (i + 1 < headerArray.size) {
                headers[headerArray[i]] = headerArray[i + 1]
            }
        }
        return headers
    }
}
