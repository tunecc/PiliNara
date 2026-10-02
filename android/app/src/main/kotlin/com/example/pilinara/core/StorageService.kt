package com.example.pilinara.core

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * Storage service - replaces Flutter's Hive storage.
 * Uses Android SharedPreferences for persistence.
 */
class StorageService private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "StorageService"
        private const val PREFS_NAME = "pilinara_settings"
        
        @Volatile
        private var instance: StorageService? = null
        
        fun getInstance(context: Context): StorageService {
            return instance ?: synchronized(this) {
                instance ?: StorageService(context).also { instance = it }
            }
        }
        
        fun clearInstance() {
            instance = null
        }
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()
    
    fun getBoolean(key: String, default: Boolean = false): Boolean {
        return prefs.getBoolean(key, default)
    }
    
    fun setBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }
    
    fun getString(key: String, default: String = ""): String {
        return prefs.getString(key, default) ?: default
    }
    
    fun setString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }
    
    fun getInt(key: String, default: Int = 0): Int {
        return prefs.getInt(key, default)
    }
    
    fun setInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }
    
    fun getLong(key: String, default: Long = 0L): Long {
        return prefs.getLong(key, default)
    }
    
    fun setLong(key: String, value: Long) {
        prefs.edit().putLong(key, value).apply()
    }
    
    fun <T> getObject(key: String, clazz: Class<T>, default: T? = null): T? {
        val json = prefs.getString(key, null) ?: return default
        return try {
            gson.fromJson(json, clazz)
        } catch (e: Exception) {
            null
        }
    }
    
    fun <T> setObject(key: String, value: T) {
        prefs.edit().putString(key, gson.toJson(value)).apply()
    }
    
    fun <T> getList(key: String, clazz: Class<T>): List<T> {
        val json = prefs.getString(key, null) ?: return emptyList()
        return try {
            val type = object : TypeToken<List<T>>() {}.type
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    fun <T> setList(key: String, list: List<T>) {
        prefs.edit().putString(key, gson.toJson(list)).apply()
    }
    
    fun delete(key: String) {
        prefs.edit().remove(key).apply()
    }
    
    fun clearAll() {
        prefs.edit().clear().apply()
    }
    
    fun contains(key: String): Boolean {
        return prefs.contains(key)
    }
}

// Settings keys (replaces SettingBoxKey in Flutter)
object SettingsKeys {
    const val USE_EXOPLAYER = "useExoPlayer"
    const val ENABLE_HA = "enableHA"
    const val P1080 = "p1080"
    const val CDN_SPEED_TEST = "cdnSpeedTest"
    const val DISABLE_AUDIO_CDN = "disableAudioCDN"
    const val AUTO_PLAY = "autoPlayEnable"
    const val FULL_SCREEN_MODE = "fullScreenMode"
    const val VIDEO_SYNC = "videoSync"
    const val MIX_WITH_OTHERS = "mixWithOthers"
    const val ENABLE_DANMAKU = "enableShowDanmaku"
    const val DANMAKU_OPACITY = "danmakuOpacity"
    const val DANMAKU_FONT_SCALE = "danmakuFontScale"
    const val DANMAKU_SPEED = "danmakuSpeed"
    const val AUDIO_NORMALIZATION = "audioNormalization"
    const val SUPER_RESOLUTION = "superResolutionType"
    const val DOWNLOAD_PATH = "downloadPath"
    const val IMAGE_SAVE_PATH = "imageSavePath"
}
