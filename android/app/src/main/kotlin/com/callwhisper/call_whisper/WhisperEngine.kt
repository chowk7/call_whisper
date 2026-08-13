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
                progress(0.02, "m4a 오디오 디코딩 중")
                val pcm = PcmDecoder.decodeMono16k(audioPath) { decoded -> progress(0.05 + decoded * 0.15, "오디오 준비 중") }
                if (cancelled) return@execute result.error("cancelled", "사용자가 전사를 취소했습니다.", null)
                progress(0.22, "Whisper 전사 중")
                val segments = NativeWhisper.transcribe(modelPath, pcm, "ko", diarize)
                if (cancelled) return@execute result.error("cancelled", "사용자가 전사를 취소했습니다.", null)
                progress(0.90, if (diarize) "발화자 구분 완료" else "전사 결과 정리 중")
                progress(1.0, "완료")
                result.success(segments.map { mapOf("startMs" to it.startMs, "endMs" to it.endMs, "speakerId" to it.speakerId, "text" to it.text) })
            } catch (e: Throwable) {
                result.error("transcription_failed", e.message ?: "로컬 전사를 완료하지 못했습니다.", null)
            }
        }
    }

    fun cancel() { cancelled = true; NativeWhisper.cancel() }
}

data class NativeSegment(val startMs: Int, val endMs: Int, val speakerId: String, val text: String)

object NativeWhisper {
    init { System.loadLibrary("call_whisper") }
    external fun transcribe(modelPath: String, pcm16k: ShortArray, language: String, diarize: Boolean): List<NativeSegment>
    external fun cancel()
}

object PcmDecoder {
    /** Android MediaCodec handles m4a/aac, mp3 and wav without any cloud API. */
    fun decodeMono16k(path: String, report: (Double) -> Unit): ShortArray {
        return AndroidAudioDecoder.decodeToMono16k(path, report)
    }
}
