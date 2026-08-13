package com.callwhisper.call_whisper

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import kotlin.math.roundToInt

/** Device codec decoder for m4a/AAC. Produces signed mono 16 kHz PCM for Whisper. */
object AndroidAudioDecoder {
    fun durationMs(source: String): Long {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(source)
            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw IllegalArgumentException("오디오 트랙을 찾을 수 없습니다.")
            return extractor.getTrackFormat(track).getLong(MediaFormat.KEY_DURATION) / 1000
        } finally { extractor.release() }
    }

    fun decodeToMono16k(source: String, startUs: Long, endUs: Long, report: (Double) -> Unit): ShortArray {
        val extractor = MediaExtractor()
        extractor.setDataSource(source)
        val track = (0 until extractor.trackCount).firstOrNull { index ->
            extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
        } ?: throw IllegalArgumentException("오디오 트랙을 찾을 수 없습니다.")
        extractor.selectTrack(track)
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        val format = extractor.getTrackFormat(track)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: throw IllegalArgumentException("오디오 형식을 읽을 수 없습니다.")
        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()
        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val chunkDuration = (endUs - startUs).coerceAtLeast(1L)
        val pcm = ShortAccumulator()
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        var outputDone = false
        try {
            while (!outputDone) {
                if (!inputDone) {
                    val index = codec.dequeueInputBuffer(10_000)
                    if (index >= 0) {
                        val buffer = codec.getInputBuffer(index)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0 || extractor.sampleTime >= endUs) { codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputDone = true }
                        else { codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0); extractor.advance() }
                    }
                }
                when (val index = codec.dequeueOutputBuffer(info, 10_000)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                    in 0..Int.MAX_VALUE -> {
                        val buffer = codec.getOutputBuffer(index)!!
                        buffer.position(info.offset); buffer.limit(info.offset + info.size)
                        while (buffer.remaining() >= channels * 2) {
                            var mixed = 0
                            repeat(channels) { mixed += buffer.short.toInt() }
                            pcm.add((mixed / channels).toShort())
                        }
                        codec.releaseOutputBuffer(index, false)
                        report(((info.presentationTimeUs - startUs).toDouble() / chunkDuration).coerceIn(0.0, 1.0))
                        outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    }
                }
            }
        } finally { codec.stop(); codec.release(); extractor.release() }
        return resample(pcm.toArray(), sampleRate, 16_000)
    }

    private fun resample(input: ShortArray, from: Int, to: Int): ShortArray {
        if (from == to) return input
        val output = ShortArray((input.size.toLong() * to / from).toInt())
        output.indices.forEach { index ->
            val position = index * from.toDouble() / to
            val left = position.toInt().coerceAtMost(input.lastIndex)
            val right = (left + 1).coerceAtMost(input.lastIndex)
            output[index] = (input[left] + (input[right] - input[left]) * (position - left)).roundToInt().toShort()
        }
        return output
    }
}

/** Avoid ArrayList<Short> boxing, which causes long recordings to exhaust heap. */
private class ShortAccumulator {
    private var data = ShortArray(32_768)
    private var size = 0
    fun add(value: Short) {
        if (size == data.size) data = data.copyOf(data.size * 2)
        data[size++] = value
    }
    fun toArray(): ShortArray = data.copyOf(size)
}
