package com.example.pilinara

import android.content.Context
import android.util.Log
import com.android.purebilibili.danmaku.engine.DanmakuEngine
import com.android.purebilibili.danmaku.engine.DanmakuRenderView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.xml.sax.helpers.XMLReaderFactory
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * Native danmaku manager using ByteDance Danmaku Engine.
 * Replaces the Flutter canvas_danmaku plugin.
 */
class DanmakuManager private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "DanmakuManager"
        private const val BASE_URL = "https://api.bilibili.com/x/v2/dm/v1"
        
        @Volatile
        private var instance: DanmakuManager? = null
        
        fun getInstance(context: Context): DanmakuManager {
            return instance ?: synchronized(this) {
                instance ?: DanmakuManager(context).also { instance = it }
            }
        }
        
        fun clearInstance() {
            instance = null
        }
    }
    
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private var renderView: DanmakuRenderView? = null
    private var engine: DanmakuEngine? = null
    private var currentCid: Long = 0
    
    /**
     * Initialize the danmaku renderer
     */
    fun initView(renderView: DanmakuRenderView) {
        this.renderView = renderView
        this.engine = renderView.engine
        Log.d(TAG, "Danmaku renderer initialized")
    }
    
    /**
     * Load danmaku from Bilibili API
     */
    suspend fun loadDanmaku(cid: Long, type: Int = 4) {
        return withContext(Dispatchers.IO) {
            this@DanmakuManager.currentCid = cid
            
            val url = "$BASE_URL?$type/$cid"
            
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Referer", "https://www.bilibili.com")
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 BiliDroid/2.0.1")
                
                val responseCode = connection.responseCode
                if (responseCode != HttpURLConnection.HTTP_OK) {
                    Log.e(TAG, "Failed to load danmaku: $responseCode")
                    return@withContext
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
                
                val xmlContent = sb.toString()
                parseAndSendDanmaku(xmlContent)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error loading danmaku: ${e.message}", e)
            }
        }
    }
    
    /**
     * Parse XML danmaku and send to renderer
     */
    private fun parseAndSendDanmaku(xml: String) {
        try {
            val items = parseDanmakuXml(xml)
            if (items.isNotEmpty()) {
                scope.launch {
                    engine?.append(items)
                    engine?.start(0L)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing danmaku: ${e.message}", e)
        }
    }
    
    private fun parseDanmakuXml(xml: String): List<com.android.purebilibili.danmaku.engine.DanmakuItem> {
        val items = mutableListOf<com.android.purebilibili.danmaku.engine.DanmakuItem>()
        
        val reader = XMLReaderFactory.createDefaultXMLReader()
        val handler = DanmakuContentHandler(items)
        reader.contentHandler = handler
        
        val inputSource = org.xml.sax.InputSource(java.io.StringReader(xml))
        reader.parse(inputSource)
        
        return items
    }
    
    /**
     * Control playback
     */
    fun play(positionMs: Long = 0L) {
        scope.launch {
            engine?.start(positionMs)
        }
    }
    
    fun pause() {
        engine?.pause()
    }
    
    fun seekTo(positionMs: Long) {
        engine?.seekTo(positionMs)
    }
    
    fun stop() {
        engine?.stop()
    }
    
    fun clear() {
        engine?.clear()
    }
    
    /**
     * Release resources
     */
    fun release() {
        scope.cancel()
        engine?.close()
        renderView = null
        engine = null
        clearInstance()
    }
    
    /**
     * SAX handler for danmaku XML
     */
    private class DanmakuContentHandler(private val items: MutableList<com.android.purebilibili.danmaku.engine.DanmakuItem>) :
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
                
                val danmakuMode = when (mode) {
                    1 -> com.android.purebilibili.danmaku.engine.DanmakuItem.MODE_SCROLL
                    2 -> com.android.purebilibili.danmaku.engine.DanmakuItem.MODE_TOP
                    3 -> com.android.purebilibili.danmaku.engine.DanmakuItem.MODE_BOTTOM
                    else -> com.android.purebilibili.danmaku.engine.DanmakuItem.MODE_SCROLL
                }
                
                items.add(
                    com.android.purebilibili.danmaku.engine.DanmakuItem(
                        content = "", // Will be set in characters()
                        time = time,
                        mode = danmakuMode,
                        fontSize = fontSize.toFloat(),
                        color = color,
                        alpha = 255,
                        strokeWidth = 0f
                    )
                )
            }
        }
        
        override fun endElement(uri: String, localName: String, qName: String) {
            if (localName == "d" && items.isNotEmpty()) {
                items.last().content = currentContent
            }
            currentElement = ""
        }
        
        override fun characters(ch: CharArray, start: Int, length: Int) {
            currentContent += String(ch, start, length)
        }
    }
}
