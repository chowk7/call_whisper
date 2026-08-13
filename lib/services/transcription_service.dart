import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../domain/transcript.dart';

class TranscriptionProgress {
  const TranscriptionProgress(this.fraction, this.message);
  final double fraction;
  final String message;
}

/// Boundary to the native whisper.cpp + diarization implementation.
/// Audio and transcript data stay on the device; no audio is uploaded.
class LocalTranscriptionService {
  static const _methods = MethodChannel('com.callwhisper/transcription');
  static const _events = EventChannel('com.callwhisper/transcription-progress');

  Stream<TranscriptionProgress> get progress => _events.receiveBroadcastStream().map((event) {
        final value = Map<Object?, Object?>.from(event as Map);
        return TranscriptionProgress((value['fraction']! as num).toDouble(), value['message']! as String);
      });

  Future<List<TranscriptSegment>> transcribe({
    required File audioFile,
    required File modelFile,
    required bool diarize,
  }) async {
    const supported = {'m4a', 'mp3', 'wav', 'aac'};
    final extension = path.extension(audioFile.path).replaceFirst('.', '').toLowerCase();
    if (!supported.contains(extension)) {
      throw ArgumentError('지원하지 않는 파일 형식입니다: .$extension');
    }
    final result = await _methods.invokeListMethod<dynamic>('transcribe', {
      'audioPath': audioFile.path,
      'modelPath': modelFile.path,
      'diarize': diarize,
      'language': 'ko',
    });
    if (result == null) throw StateError('전사 결과가 비어 있습니다.');
    return result.map((item) => TranscriptSegment.fromMap(Map<Object?, Object?>.from(item as Map))).toList();
  }

  Future<void> cancel() => _methods.invokeMethod<void>('cancel');
}
