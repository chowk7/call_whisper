package com.callwhisper.call_whisper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methods = "com.callwhisper/transcription"
    private val events = "com.callwhisper/transcription-progress"
    private val engine by lazy { WhisperEngine(this::emitProgress) }
    private var sink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methods).setMethodCallHandler { call, result ->
            when (call.method) {
                "transcribe" -> {
                    val audioPath = call.argument<String>("audioPath")
                    val modelPath = call.argument<String>("modelPath")
                    val diarize = call.argument<Boolean>("diarize") ?: true
                    if (audioPath == null || modelPath == null) {
                        result.error("invalid_arguments", "audioPath와 modelPath가 필요합니다.", null)
                    } else {
                        engine.transcribe(audioPath, modelPath, diarize, result)
                    }
                }
                "cancel" -> { engine.cancel(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, events).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) { sink = eventSink }
            override fun onCancel(arguments: Any?) { sink = null }
        })
    }

    private fun emitProgress(fraction: Double, message: String) {
        runOnUiThread { sink?.success(mapOf("fraction" to fraction, "message" to message)) }
    }
}
