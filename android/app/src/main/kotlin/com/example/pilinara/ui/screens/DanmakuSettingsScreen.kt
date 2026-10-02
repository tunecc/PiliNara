package com.example.pilinara.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun DanmakuSettingsScreen(onBack: () -> Unit) {
    var enabled by remember { mutableStateOf(true) }
    var fontSize by remember { mutableStateOf(25f) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("弹幕设置") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            Switch(
                checked = enabled,
                onCheckedChange = { enabled = it },
                label = { Text("开启弹幕") }
            )
            Spacer(modifier = Modifier.height(16.dp))
            Slider(
                value = fontSize,
                onValueChange = { fontSize = it },
                valueRange = 15f..40f,
                label = { Text("字体大小: ${fontSize.toInt()}") }
            )
        }
    }
}
