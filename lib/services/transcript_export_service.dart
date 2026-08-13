import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/transcript.dart';

enum TranscriptExportFormat { txt, srt }

class TranscriptExportService {
  Future<File> create({
    required String sourceName,
    required List<TranscriptSegment> segments,
    required Map<String, String> speakerNames,
    required TranscriptExportFormat format,
  }) async {
    final directory = await getTemporaryDirectory();
    final name = path.basenameWithoutExtension(sourceName).replaceAll(RegExp(r'[^a-zA-Z0-9가-힣 _-]'), '_');
    final extension = format.name;
    final file = File(path.join(directory.path, '${name}_전사.$extension'));
    final content = switch (format) {
      TranscriptExportFormat.txt => segments.map((segment) => segment.toPlainText(speakerNames: speakerNames)).join('\n'),
      TranscriptExportFormat.srt => _toSrt(segments, speakerNames),
    };
    // UTF-8 BOM ensures Korean text displays correctly in common spreadsheet/text apps.
    await file.writeAsString('\uFEFF$content', encoding: utf8, flush: true);
    return file;
  }

  Future<void> share(File file) => Share.shareXFiles([XFile(file.path)]);

  String _toSrt(List<TranscriptSegment> segments, Map<String, String> speakers) => segments.indexed.map((entry) {
        final index = entry.$1 + 1;
        final segment = entry.$2;
        final name = speakers[segment.speakerId] ?? segment.speakerId;
        return '$index\n${_srtTime(segment.startMs)} --> ${_srtTime(segment.endMs)}\n[$name] ${segment.text}';
      }).join('\n\n');

  String _srtTime(int milliseconds) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    final seconds = milliseconds ~/ 1000;
    return '${two(seconds ~/ 3600)}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)},${three(milliseconds % 1000)}';
  }
}
