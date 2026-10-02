package com.example.pilinara.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.pilinara.ui.components.VideoCard

data class VideoItem(
    val id: String,
    val title: String,
    val author: String,
    val thumbnail: String,
    val views: Long,
    val duration: String
)

@Composable
fun HomeScreen(
    onVideoClick: (String) -> Unit,
    onSearchClick: () -> Unit
) {
    var videos by remember { mutableStateOf<List<VideoItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    
    LaunchedEffect(Unit) {
        videos = generateSampleVideos()
        isLoading = false
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("PiliNara") },
                actions = {
                    IconButton(onClick = onSearchClick) {
                        Icon(Icons.Default.Search, contentDescription = "Search")
                    }
                }
            )
        }
    ) { padding ->
        if (isLoading) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(8.dp)
            ) {
                items(videos) { video ->
                    VideoCard(video = video, onClick = { onVideoClick(video.id) })
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }
        }
    }
}

fun generateSampleVideos(): List<VideoItem> {
    return List(20) { i ->
        VideoItem(
            id = "BV1abc${i}def",
            title = "【Bilibili】示例视频 $i - Kotlin + Rust 原生应用",
            author = "技术UP主 $i",
            thumbnail = "https://example.com/thumb$i.jpg",
            views = (100000..1000000).random().toLong(),
            duration = "${(i % 60) + 1}:${(i % 60).toString().padStart(2, '0')}"
        )
    }
}
