package com.example.pilinara

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Native Bilibili API service.
 * Replaces dio HTTP client in Flutter.
 */
class BiliApiService private constructor() {
    
    companion object {
        private const val TAG = "BiliApiService"
        private const val BASE_URL = "https://api.bilibili.com"
        private const val X_REQKEY = "dfca71928277209b"
        
        @Volatile
        private var instance: BiliApiService? = null
        
        fun getInstance(): BiliApiService {
            return instance ?: synchronized(this) {
                instance ?: BiliApiService().also { instance = it }
            }
        }
        
        fun clearInstance() {
            instance = null
        }
    }
    
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .addInterceptor { chain ->
            val request = chain.request().newBuilder()
                .addHeader("User-Agent", "Mozilla/5.0 BiliDroid/2.0.1")
                .addHeader("Referer", "https://www.bilibili.com")
                .addHeader("x-bili-aurora-zone", "sh001")
                .build()
            chain.proceed(request)
        }
        .build()
    
    /**
     * Get video play URL (bilibili play interface)
     */
    suspend fun getPlayUrl(bvid: String, cid: Long, qn: Int = 80): PlayUrlResponse {
        return withContext(Dispatchers.IO) {
            val url = "$BASE_URL/x/player/playurl"
            val params = buildMap {
                put("bvid", bvid)
                put("cid", cid.toString())
                put("qn", qn.toString())
                put("fnval", "16")  // DASH format
                put("fnver", "0")
                put("fourk", "1")
                put("platform", "android")
                put("high_quality", "1")
            }
            
            val response = get(url, params)
            val json = JSONObject(response)
            
            if (json.optInt("code") != 0) {
                throw ApiException(json.optString("message", "Unknown error"))
            }
            
            val dash = json.getJSONObject("data").getJSONObject("dash")
            
            PlayUrlResponse(
                duration = json.getJSONObject("data").optLong("duration"),
                durl = parseDUrl(dash.getJSONArray("duration")),
                backupUrl = parseBackupUrl(dash)
            )
        }
    }
    
    /**
     * Get video detail information
     */
    suspend fun getVideoDetail(bvid: String): VideoDetail {
        return withContext(Dispatchers.IO) {
            val url = "$BASE_URL/x/web-interface/view"
            val params = mapOf("bvid" to bvid)
            
            val response = get(url, params)
            val json = JSONObject(response)
            
            if (json.optInt("code") != 0) {
                throw ApiException(json.optString("message", "Failed to get video detail"))
            }
            
            val data = json.getJSONObject("data")
            
            VideoDetail(
                bvid = data.getString("bvid"),
                aid = data.optLong("aid"),
                title = data.getString("title"),
                desc = data.getString("desc"),
                pic = data.getString("pic"),
                pubdate = data.optLong("pubdate"),
                length = data.getString("length"),
                owner = Owner(
                    mid = data.getJSONObject("owner").optLong("mid"),
                    name = data.getJSONObject("owner").getString("name"),
                    face = data.getJSONObject("owner").getString("face")
                ),
                stat = Stat(
                    view = data.getJSONObject("stat").optLong("view"),
                    danmaku = data.getJSONObject("stat").optLong("danmaku"),
                    reply = data.getJSONObject("stat").optLong("reply"),
                    like = data.getJSONObject("stat").optLong("like"),
                    coin = data.getJSONObject("stat").optLong("coin"),
                    favorite = data.getJSONObject("stat").optLong("favorite"),
                    share = data.getJSONObject("stat").optLong("share")
                )
            )
        }
    }
    
    /**
     * Search videos
     */
    suspend fun searchVideos(keyword: String, page: Int = 1, pagesize: Int = 20): SearchResponse {
        return withContext(Dispatchers.IO) {
            val url = "$BASE_URL/x/web-interface/search/type"
            val params = mapOf(
                "search_type" to "video",
                "keyword" to keyword,
                "page" to page.toString(),
                "pagesize" to pagesize.toString()
            )
            
            val response = get(url, params)
            val json = JSONObject(response)
            
            if (json.optInt("code") != 0) {
                throw ApiException(json.optString("message", "Search failed"))
            }
            
            val data = json.getJSONObject("data")
            val numResults = data.optInt("numResults", 0)
            
            val videos = mutableListOf<VideoItem>()
            val list = data.getJSONArray("result")
            
            for (i in 0 until list.length()) {
                val item = list.getJSONObject(i)
                videos.add(
                    VideoItem(
                        bvid = item.optString("bvid"),
                        title = item.optString("title"),
                        author = item.optString("author"),
                        pic = item.optString("pic"),
                        duration = item.optString("duration"),
                        play = item.optLong("play"),
                        danmaku = item.optLong("danmaku")
                    )
                )
            }
            
            SearchResponse(
                numResults = numResults,
                videos = videos,
                pages = data.optInt("pages", 1)
            )
        }
    }
    
    private suspend fun get(path: String, params: Map<String, String>): String {
        val urlBuilder = StringBuilder("$BASE_URL$path?")
        params.forEach { (key, value) ->
            urlBuilder.append("$key=$value&")
        }
        
        val request = Request.Builder()
            .url(urlBuilder.toString())
            .get()
            .build()
        
        return try {
            client.newCall(request).execute().use { response ->
                response.body?.string() ?: throw IOException("Empty response")
            }
        } catch (e: IOException) {
            Log.e(TAG, "API request failed: ${e.message}")
            throw e
        }
    }
    
    private suspend fun post(path: String, body: String): String {
        val contentType = "application/json; charset=utf-8".toMediaType()
        val request = Request.Builder()
            .url("$BASE_URL$path")
            .post(body.toRequestBody(contentType))
            .build()
        
        return try {
            client.newCall(request).execute().use { response ->
                response.body?.string() ?: throw IOException("Empty response")
            }
        } catch (e: IOException) {
            Log.e(TAG, "API request failed: ${e.message}")
            throw e
        }
    }
    
    // Data classes
    data class PlayUrlResponse(
        val duration: Long,
        val durl: List<DUrl>,
        val backupUrl: List<String>
    )
    
    data class DUrl(
        val url: String,
        val length: Long,
        val size: Long,
        val video_codecid: Int
    )
    
    data class VideoDetail(
        val bvid: String,
        val aid: Long,
        val title: String,
        val desc: String,
        val pic: String,
        val pubdate: Long,
        val length: String,
        val owner: Owner,
        val stat: Stat
    )
    
    data class Owner(
        val mid: Long,
        val name: String,
        val face: String
    )
    
    data class Stat(
        val view: Long,
        val danmaku: Long,
        val reply: Long,
        val like: Long,
        val coin: Long,
        val favorite: Long,
        val share: Long
    )
    
    data class SearchResponse(
        val numResults: Int,
        val videos: List<VideoItem>,
        val pages: Int
    )
    
    data class VideoItem(
        val bvid: String,
        val title: String,
        val author: String,
        val pic: String,
        val duration: String,
        val play: Long,
        val danmaku: Long
    )
    
    class ApiException(val message: String) : Exception(message)
}
