package com.callwhisper.call_whisper

import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Decodes m4a/AAC with Android's system codec, then invokes the native
 * whisper.cpp wrapper. The wrapper produces timestamped speech segments and
 * speaker embeddings; clustering is completely device-local.
 */
class WhisperEngine(private val progress: (Double, String) -> Unit) {
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var cancelled = false

    fun transcribe(audioPath: String, modelPath: String, diarize: Boolean, result: MethodChannel.Result) {
        if (!File(audioPath).isFile || !File(modelPath).isFile) {
            result.error("file_missing", "녹음 파일 또는 모델 파일을 찾을 수 없습니다.", null)
            return
        }
        cancelled = false
        worker.execute {
            try {
                val durationMs = PcmDecoder.durationMs(audioPath)
                // Never load a long recording into memory as one PCM array.
                // Short chunks provide responsive, visible whole-recording progress
                // while also keeping Kotlin + JNI + Whisper peak memory low.
                val chunkMs = 20_000L
                val segments = mutableListOf<NativeSegment>()
                var startMs = 0L
                while (startMs < durationMs) {
                    val endMs = minOf(startMs + chunkMs, durationMs)
                    progress(startMs.toDouble() / durationMs, "전체 녹음 중 ${percent(startMs, durationMs)}% 처리")
                    val pcm = PcmDecoder.decodeMono16k(audioPath, startMs * 1000, endMs * 1000) { decoded ->
                        val overall = (startMs + (endMs - startMs) * decoded) / durationMs
                        progress(overall, "전체 녹음 중 ${percent(overall)}% 준비 중")
                    }
                    if (cancelled) break
                    progress(startMs.toDouble() / durationMs, "전체 녹음 중 ${percent(startMs, durationMs)}% 전사 중")
                    try {
                        segments += NativeWhisper.transcribe(modelPath, pcm, "ko", diarize) { chunkProgress ->
                            val overall = (startMs + (endMs - startMs) * chunkProgress) / durationMs
                            progress(overall, "전체 녹음 중 ${percent(overall)}% 전사 중")
                        }.map {
                            it.copy(startMs = it.startMs + startMs.toInt(), endMs = it.endMs + startMs.toInt())
                        }
                    } catch (e: Throwable) {
                        // Keep all fully processed chunks when the user stops.
                        if (!cancelled) throw e
                    }
                    if (cancelled) break
                    startMs = endMs
                }
                val completed = if (cancelled) startMs else durationMs
                progress(completed.toDouble() / durationMs, if (cancelled) "중지됨 — 완료 구간 결과 저장" else "완료")
                result.success(segments.map { mapOf("startMs" to it.startMs, "endMs" to it.endMs, "speakerId" to it.speakerId, "text" to it.text) })
            } catch (e: Throwable) {
                result.error("transcription_failed", e.message ?: "로컬 전사를 완료하지 못했습니다.", null)
            }
        }
    }

    fun cancel() { cancelled = true; NativeWhisper.cancel() }

    private fun percent(part: Long, total: Long): Int = (part * 100 / total.coerceAtLeast(1)).toInt().coerceIn(0, 100)
    private fun percent(value: Double): Int = (value * 100).toInt().coerceIn(0, 100)
}

data class NativeSegment(val startMs: Int, val endMs: Int, val speakerId: String, val text: String)

object NativeWhisper {
    init { System.loadLibrary("call_whisper") }
    external fun transcribe(modelPath: String, pcm16k: ShortArray, language: String, diarize: Boolean, onProgress: (Double) -> Unit): List<NativeSegment>
    external fun cancel()
}

object PcmDecoder {
    /** Android MediaCodec handles m4a/aac, mp3 and wav without any cloud API. */
    fun durationMs(path: String): Long = AndroidAudioDecoder.durationMs(path)
    fun decodeMono16k(path: String, startUs: Long, endUs: Long, report: (Double) -> Unit): ShortArray {
        return AndroidAudioDecoder.decodeToMono16k(path, startUs, endUs, report)
    }
}
