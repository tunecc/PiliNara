package com.example.pilinara.services

import android.content.Context
import android.util.Log
import org.xml.sax.helpers.XMLReaderFactory
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * Danmaku service - handles loading and parsing Bilibili danmaku.
 * Replaces Flutter's PlDanmakuController.
 */
class DanmakuService private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "DanmakuService"
        private const val BASE_URL = "https://api.bilibili.com/x/v2/dm/v1"
        
        @Volatile
        private var instance: DanmakuService? = null
        
        fun getInstance(context: Context): DanmakuService {
            return instance ?: synchronized(this) {
                instance ?: DanmakuService(context).also { instance = it }
            }
        }
        
        fun clearInstance() {
            instance = null
        }
    }
    
    private val danmakuCache = mutableMapOf<Long, List<DanmakuItem>>()
    
    /**
     * Load danmaku for a video by CID
     */
    suspend fun loadDanmaku(cid: Long, type: Int = 4): List<DanmakuItem> {
        return try {
            if (danmakuCache.containsKey(cid)) {
                danmakuCache[cid]!!
            } else {
                val url = "$BASE_URL?$type/$cid"
                val items = fetchDanmaku(url)
                danmakuCache[cid] = items
                items
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load danmaku: ${e.message}")
            emptyList()
        }
    }
    
    /**
     * Clear danmaku cache
     */
    fun clearCache() {
        danmakuCache.clear()
    }
    
    private suspend fun fetchDanmaku(url: String): List<DanmakuItem> {
        return withContext(kotlinx.coroutines.Dispatchers.IO) {
            val items = mutableListOf<DanmakuItem>()
            
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Referer", "https://www.bilibili.com")
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 BiliDroid/2.0.1")
                
                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    Log.e(TAG, "Failed to fetch danmaku: ${connection.responseCode}")
                    return@withContext emptyList()
                }
                
                val inputStream = connection.inputStream
                val reader = BufferedReader(InputStreamReader(inputStream, "UTF-8"))
                val sb = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    sb.append(line)
                }
                inputStream.close()
                reader.close()
                
                parseDanmakuXml(sb.toString(), items)
            } catch (e: Exception) {
                Log.e(TAG, "Error fetching danmaku: ${e.message}")
            }
            
            items
        }
    }
    
    private fun parseDanmakuXml(xml: String, items: MutableList<DanmakuItem>) {
        try {
            val reader = XMLReaderFactory.createDefaultXMLReader()
            val handler = DanmakuContentHandler(items)
            reader.contentHandler = handler
            
            val inputSource = org.xml.sax.InputSource(java.io.StringReader(xml))
            reader.parse(inputSource)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing danmaku: ${e.message}")
        }
    }
    
    data class DanmakuItem(
        val content: String,
        val time: Long,
        val mode: Int,
        val color: Int,
        val fontSize: Int,
        val pool: Int,
        val hash: Long
    )
    
    private class DanmakuContentHandler(private val items: MutableList<DanmakuItem>) :
        org.xml.sax.helpers.DefaultHandler() {
        
        private var currentElement = ""
        private var currentContent = ""
        
        override fun startElement(uri: String, localName: String, qName: String, attributes: org.xml.sax.Attributes) {
            currentElement = localName
            currentContent = ""
            
            if (localName == "d") {
                val params = attributes.getValue("p")?.split(",") ?: return
                if (params.size < 6) return
                
                val time = params[0].toDouble() * 1000L
                val mode = params[1].toInt()
                val color = params[2].toInt(16)
                val fontSize = params[3].toInt()
                val pool = params[4].toInt()
                val hash = params[5].toLong()
                
                items.add(DanmakuItem("", time, mode, color, fontSize, pool, hash))
            }
        }
        
        override fun endElement(uri: String, localName: String, qName: String) {
            if (localName == "d" && items.isNotEmpty()) {
                items.lastOrNull()?.let { 
                    val last = items.removeAt(items.size - 1)
                    items.add(last.copy(content = currentContent))
                }
            }
            currentElement = ""
        }
        
        override fun characters(ch: CharArray, start: Int, length: Int) {
            currentContent += String(ch, start, length)
        }
    }
}
