package com.example.pilinara.media3

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class Media3MethodHandler(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, "PiliNara/media3")
    private val eventChannel = EventChannel(messenger, "PiliNara/media3/events")
    private val bridge = Media3PlayerBridge(context)
    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createPlayer" -> { bridge.init(eventSink); result.success(bridge.createPlayer()) }
            "setDataSource" -> {
                val url = call.argument<String>("url") ?: ""
                @Suppress("UNCHECKED_CAST")
                val headers = call.argument<Map<String, String>>("headers")
                result.success(bridge.setDataSource(url, headers))
            }
            "play" -> result.success(bridge.play())
            "pause" -> result.success(bridge.pause())
            "seekTo" -> result.success(bridge.seekTo(call.argument<Long>("positionMs") ?: 0L))
            "getPosition" -> result.success(bridge.getPosition())
            "getDuration" -> result.success(bridge.getDuration())
            "getBufferedPosition" -> result.success(bridge.getBufferedPosition())
            "setSpeed" -> result.success(bridge.setSpeed((call.argument<Double>("speed") ?: 1.0).toFloat()))
            "setVolume" -> result.success(bridge.setVolume((call.argument<Double>("volume") ?: 1.0).toFloat()))
            "isPlaying" -> result.success(bridge.isPlaying())
            "setAudioGain" -> { bridge.setAudioGain((call.argument<Double>("db") ?: 0.0).toFloat()); result.success(true) }
            "setAudioDynamic" -> {
                bridge.setAudioDynamic(call.argument<Boolean>("enabled") ?: false, (call.argument<Double>("targetRmsDb") ?: -16.0).toFloat())
                result.success(true)
            }
            "setAudioEq" -> {
                bridge.setAudioEq(
                    call.argument<Boolean>("enabled") ?: false,
                    (call.argument<Double>("freqHz") ?: 1000.0).toFloat(),
                    (call.argument<Double>("gainDb") ?: 0.0).toFloat(),
                    (call.argument<Double>("q") ?: 1.0).toFloat()
                )
                result.success(true)
            }
            "setSuperResolution" -> { bridge.setSuperResolution(call.argument<String>("mode") ?: "disable"); result.success(true) }
            "captureFrame" -> bridge.captureFrame(result)
            "release" -> { bridge.release(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events; bridge.init(events) }
    override fun onCancel(arguments: Any?) { eventSink = null }
    fun dispose() { methodChannel.setMethodCallHandler(null); eventChannel.setStreamHandler(null); bridge.release() }
}
