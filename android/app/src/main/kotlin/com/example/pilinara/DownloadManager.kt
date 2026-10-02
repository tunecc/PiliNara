package com.example.pilinara

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Native download manager for video/audio files.
 * Replaces dio + flutter_downloader Flutter plugins.
 */
class DownloadManager(private val context: Context) {
    
    companion object {
        private const val TAG = "DownloadManager"
        private const val CHANNEL_ID = "pilinara_download"
        
        @Volatile
        private var instance: DownloadManager? = null
        
        fun getInstance(context: Context): DownloadManager {
            return instance ?: synchronized(this) {
                instance ?: DownloadManager(context).also { instance = it }
            }
        }
        
        fun clearInstance() {
            instance = null
        }
    }
    
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        createNotificationChannel()
    }
    
    data class DownloadTask(
        val id: String,
        val url: String,
        val filename: String,
        val destination: File,
        var progress: Int = 0,
        var status: DownloadStatus = DownloadStatus.PENDING
    )
    
    enum class DownloadStatus {
        PENDING, DOWNLOADING, PAUSED, COMPLETED, FAILED
    }
    
    private val tasks = mutableMapOf<String, DownloadTask>()
    
    fun download(
        url: String,
        filename: String,
        destinationDir: File = getDownloadDir(),
        headers: Map<String, String> = emptyMap()
    ): String {
        val taskId = java.util.UUID.randomUUID().toString()
        val destination = File(destinationDir, filename)
        
        val task = DownloadTask(taskId, url, filename, destination)
        tasks[taskId] = task
        
        scope.launch {
            executeDownload(task, headers)
        }
        
        return taskId
    }
    
    private suspend fun executeDownload(task: DownloadTask, headers: Map<String, String>) {
        task.status = DownloadStatus.DOWNLOADING
        updateNotification(task)
        
        try {
            val url = URL(task.url)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 30000
            connection.readTimeout = 60000
            
            headers.forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            
            connection.connect()
            
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                task.status = DownloadStatus.FAILED
                Log.e(TAG, "Download failed: ${connection.responseCode}")
                return
            }
            
            val inputStream: InputStream = connection.inputStream
            val totalSize = connection.contentLengthLong
            var downloaded = 0L
            val buffer = ByteArray(8192)
            
            task.destination.parentFile?.mkdirs()
            
            inputStream.use { input ->
                task.destination.outputStream().use { output ->
                    var read: Int
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                        downloaded += read
                        
                        if (totalSize > 0) {
                            task.progress = (downloaded * 100 / totalSize).toInt()
                            updateNotification(task)
                        }
                    }
                }
            }
            
            task.status = DownloadStatus.COMPLETED
            task.progress = 100
            updateNotification(task)
            
            // Broadcast completion
            val completeIntent = Intent("com.pilinara.download.complete")
            completeIntent.putExtra("taskId", task.id)
            completeIntent.putExtra("filePath", task.destination.absolutePath)
            context.sendBroadcast(completeIntent)
            
        } catch (e: Exception) {
            Log.e(TAG, "Download error: ${e.message}", e)
            task.status = DownloadStatus.FAILED
            updateNotification(task)
        } finally {
            tasks.remove(task.id)
        }
    }
    
    private fun getDownloadDir(): File {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) 
                ?: File(context.filesDir, "downloads")
        } else {
            File(Environment.getExternalStorageDirectory(), "Download/PiliNara")
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Downloads",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Download progress notifications"
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun updateNotification(task: DownloadTask) {
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, task.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val title = when (task.status) {
            DownloadStatus.COMPLETED -> "Download complete: ${task.filename}"
            DownloadStatus.FAILED -> "Download failed: ${task.filename}"
            else -> "Downloading: ${task.filename}"
        }
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("${task.progress}%")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setProgress(100, task.progress, task.status == DownloadStatus.DOWNLOADING)
            .setContentIntent(pendingIntent)
            .build()
        
        notificationManager.notify(task.id.hashCode(), notification)
    }
    
    fun cancelDownload(taskId: String) {
        tasks.remove(taskId)
        // Cancel notification
        notificationManager.cancel(taskId.hashCode())
    }
    
    fun getDownloadStatus(taskId: String): DownloadTask? = tasks[taskId]
}
