package com.example.pilinara.ui.screens

import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.example.pilinara.BiliApiService
import com.example.pilinara.DanmakuManager

/**
 * Video player screen with native Media3 ExoPlayer.
 * Replaces Flutter's video player page.
 */
@Composable
fun VideoPlayerScreen(
    videoId: String,
    onBack: () -> Unit,
    onDanmakuSettings: () -> Unit
) {
    val context = LocalContext.current
    var player by remember { mutableStateOf<ExoPlayer?>(null) }
    var playerView by remember { mutableStateOf<PlayerView?>(null) }
    var danmakuManager by remember { mutableStateOf<DanmakuManager?>(null) }
    
    LaunchedEffect(videoId) {
        // Initialize player
        player = ExoPlayer.Builder(context).build().also {
            it.setPlayWhenReady(false)
        }
        playerView?.player = player
        
        // Initialize danmaku manager
        danmakuManager = DanmakuManager.getInstance(context)
        
        // Load video info and play
        loadVideo(videoId, context)
    }
    
    DisposableEffect(Unit) {
        onDispose {
            player?.release()
            danmakuManager?.release()
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("播放视频") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onDanmakuSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Danmaku Settings")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            playerView?.let {
                Surface(modifier = Modifier.weight(1f)) {
                    it.player = player
                }
            }
        }
    }
}

private suspend fun loadVideo(videoId: String, context: android.content.Context) {
    try {
        val apiService = BiliApiService.getInstance()
        val detail = apiService.getVideoDetail(videoId)
        // Play video with acquired URL
    } catch (e: Exception) {
        e.printStackTrace()
    }
}
