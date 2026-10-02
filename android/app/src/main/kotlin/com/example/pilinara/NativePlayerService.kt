package com.example.pilinara

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.net.Uri
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

/**
 * Foreground service for audio/background playback.
 * Replaces audio_service Flutter plugin.
 */
class NativePlayerService : Service(), Player.Listener {
    
    companion object {
        const val CHANNEL_ID = "pilinara_player_channel"
        const val NOTIFICATION_ID = 1001
        
        private var instance: NativePlayerService? = null
        
        fun getInstance(): NativePlayerService? = instance
    }
    
    private lateinit var player: ExoPlayer
    private var currentPosition = 0L
    private var isPlaying = false
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        createNotificationChannel()
        
        player = ExoPlayer.Builder(this)
            .setHandleAudioBecomingNoisy(true)
            .build()
        
        player.addListener(this)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "play" -> play()
            "pause" -> pause()
            "seek" -> {
                val position = intent.getLongExtra("position", 0L)
                player.seekTo(position)
            }
            "stop" -> stopSelf()
        }
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        player.removeListener(this)
        player.release()
        instance = null
    }
    
    fun play() {
        player.play()
        updateNotification()
    }
    
    fun pause() {
        player.pause()
        updateNotification()
    }
    
    fun seekTo(position: Long) {
        player.seekTo(position)
    }
    
    fun getDuration(): Long = player.duration
    
    fun getCurrentPosition(): Long = player.currentPosition
    
    fun isPlaying(): Boolean = player.isPlaying
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Audio playback controls"
        }
        
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }
    
    private fun updateNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PiliNara")
            .setContentText(if (isPlaying) "Playing" else "Paused")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        startForeground(NOTIFICATION_ID, notification)
    }
    
    // Player.Listener callbacks
    override fun onIsPlayingChanged(playing: Boolean) {
        isPlaying = playing
        updateNotification()
    }
    
    override fun onPositionDiscontinuity(
        oldPosition: Player.PositionInfo,
        newPosition: Player.PositionInfo,
        reason: Int
    ) {
        currentPosition = newPosition.positionMs
    }
}
