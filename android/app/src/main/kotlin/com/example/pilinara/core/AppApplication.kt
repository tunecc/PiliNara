package com.example.pilinara.core

import android.app.Application
import android.util.Log
import com.example.pilinara.BiliApiService
import com.example.pilinara.DownloadManager
import com.example.pilinara.RustNativeLib
import com.example.pilinara.services.DanmakuService

/**
 * Main Application class - initializes all core services.
 * Replaces Flutter's main.dart initialization.
 */
class AppApplication : Application() {
    
    companion object {
        private const val TAG = "AppApplication"
        
        @JvmStatic
        fun getInstance(): AppApplication {
            return instance ?: throw IllegalStateException("Application not initialized")
        }
        
        @JvmStatic
        fun getBiliApiService(): BiliApiService {
            return BiliApiService.getInstance(applicationContext)
        }
        
        @JvmStatic
        fun getDownloadManager(): DownloadManager {
            return DownloadManager.getInstance(applicationContext)
        }
        
        @JvmStatic
        fun getDanmakuService(): DanmakuService {
            return DanmakuService.getInstance(applicationContext)
        }
    }
    
    private lateinit var instance: AppApplication
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        // Load Rust native library
        try {
            System.loadLibrary("pilinara_native")
            Log.d(TAG, "Rust native library loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Rust library not found: ${e.message}")
        }
        
        // Initialize services
        BiliApiService.getInstance(this)
        DownloadManager.getInstance(this)
        DanmakuService.getInstance(this)
        
        Log.d(TAG, "PiliNara Native Application initialized")
    }
}
