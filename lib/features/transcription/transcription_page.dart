import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/transcript.dart';
import '../../services/model_catalog.dart';
import '../../services/model_manager.dart';
import '../../services/transcription_service.dart';
import '../../services/transcript_export_service.dart';

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});
  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  final _models = WhisperModelManager();
  final _transcriber = LocalTranscriptionService();
  final _exporter = TranscriptExportService();
  StreamSubscription<TranscriptionProgress>? _progressSubscription;
  File? _audio;
  double _progress = 0;
  String _status = '녹음 파일을 선택해 주세요.';
  bool _running = false;
  bool _cancelRequested = false;
  List<TranscriptSegment> _segments = [];
  final Map<String, String> _speakerNames = {};
  final List<String> _logs = [];

  @override
  void initState() { super.initState(); _models.load().then((_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _progressSubscription?.cancel(); _models.dispose(); super.dispose(); }

  Future<void> _chooseFile() async {
    final selected = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac']);
    final filePath = selected?.files.single.path;
    if (filePath != null) setState(() { _audio = File(filePath); _segments = []; _speakerNames.clear(); _logs.clear(); _status = '파일 선택 완료'; });
  }

  Future<void> _run() async {
    final model = whisperModels.where((model) => model.id == _models.selectedId).firstOrNull;
    if (_audio == null) return _notice('먼저 녹음 파일을 선택해 주세요.');
    if (model == null) return _notice('모델 설정에서 Whisper 모델을 설치하고 선택해 주세요.');
    final modelFile = await _models.installedFile(model);
    if (modelFile == null) return _notice('선택한 모델을 다시 설치해 주세요.');
    setState(() { _running = true; _cancelRequested = false; _progress = 0; _logs.clear(); _status = '전체 녹음 중 0% 처리'; });
    _progressSubscription?.cancel();
    _progressSubscription = _transcriber.progress.listen((update) {
      if (mounted) setState(() {
        _progress = update.fraction;
        _status = update.message;
        if (_logs.isEmpty || _logs.last != update.message) {
          _logs.add('${DateTime.now().toIso8601String().substring(11, 19)}  ${update.message}');
          if (_logs.length > 80) _logs.removeAt(0);
        }
      });
    });
    try {
      final result = await _transcriber.transcribe(audioFile: _audio!, modelFile: modelFile, diarize: true);
      if (mounted) setState(() {
        _segments = result;
        for (final speaker in result.map((item) => item.speakerId).toSet()) { _speakerNames.putIfAbsent(speaker, () => speaker); }
        _status = _cancelRequested
            ? '중지됨 — ${result.length}개 발화 구간 결과 저장'
            : '${result.length}개 발화 구간 완료';
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _logs.add('오류: ${error.code} ${error.message ?? ''}'));
      _notice(error.message ?? '전사 엔진 오류');
    } catch (error) { if (mounted) setState(() => _logs.add('오류: $error')); _notice('$error'); }
    finally { if (mounted) setState(() => _running = false); }
  }

  Future<void> _cancel() async {
    setState(() { _cancelRequested = true; _status = '중지 요청 중 — 완료 구간을 저장합니다.'; });
    await _transcriber.cancel();
  }
  void _notice(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Future<void> _editSegment(int index) async {
    final original = _segments[index];
    final controller = TextEditingController(text: original.text);
    String speaker = original.speakerId;
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, updateDialog) => AlertDialog(
      title: const Text('발화 편집'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: speaker, items: _speakerNames.keys.map((id) => DropdownMenuItem(value: id, child: Text(_speakerNames[id] ?? id))).toList(), onChanged: (value) { if (value != null) updateDialog(() => speaker = value); }),
        TextField(controller: controller, minLines: 2, maxLines: 5, autofocus: true),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () { setState(() => _segments[index] = original.copyWith(speakerId: speaker, text: controller.text.trim())); Navigator.pop(context); }, child: const Text('저장'))],
    )));
    controller.dispose();
  }

  Future<void> _renameSpeaker(String id) async {
    final controller = TextEditingController(text: _speakerNames[id]);
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text('$id 이름 변경'), content: TextField(controller: controller, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () { final name = controller.text.trim(); if (name.isNotEmpty) setState(() => _speakerNames[id] = name); Navigator.pop(context); }, child: const Text('저장'))]));
    controller.dispose();
  }

  Future<void> _export(TranscriptExportFormat format) async {
    if (_audio == null || _segments.isEmpty) return;
    final file = await _exporter.create(sourceName: _audio!.path.split('/').last, segments: _segments, speakerNames: _speakerNames, format: format);
    await _exporter.share(file);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('오프라인 전사'), actions: [
      if (_segments.isNotEmpty) PopupMenuButton<TranscriptExportFormat>(icon: const Icon(Icons.ios_share), tooltip: '내보내기', onSelected: _export, itemBuilder: (context) => const [PopupMenuItem(value: TranscriptExportFormat.txt, child: Text('TXT로 내보내기')), PopupMenuItem(value: TranscriptExportFormat.srt, child: Text('SRT 자막으로 내보내기'))]),
    ]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const Icon(Icons.audio_file), title: Text(_audio?.path.split('/').last ?? '선택된 파일 없음'), subtitle: const Text('m4a · mp3 · wav · aac'), trailing: TextButton(onPressed: _running ? null : _chooseFile, child: const Text('선택')))),
      const SizedBox(height: 12),
      if (_running) ...[
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 6),
        Text('전체 녹음 중 ${(_progress * 100).toStringAsFixed(0)}% 처리', style: Theme.of(context).textTheme.labelLarge),
      ],
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_status)),
      FilledButton.icon(onPressed: _running ? _cancel : _run, icon: Icon(_running ? Icons.stop : Icons.play_arrow), label: Text(_running ? '전사 취소' : '전사 시작')),
      const SizedBox(height: 16),
      if (_logs.isNotEmpty) ExpansionTile(
        leading: const Icon(Icons.article_outlined),
        title: const Text('처리 로그'),
        children: [Padding(padding: const EdgeInsets.all(12), child: SelectableText(_logs.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))],
      ),
      if (_segments.isNotEmpty) ...[
        const Text('화자 이름', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: _speakerNames.keys.map((id) => ActionChip(label: Text('$id: ${_speakerNames[id]}'), onPressed: () => _renameSpeaker(id))).toList()),
        const SizedBox(height: 8),
      ],
      ..._segments.indexed.map((entry) { final index = entry.$1; final segment = entry.$2; return Card(child: ListTile(title: Text(segment.toPlainText(speakerNames: _speakerNames)), trailing: IconButton(icon: const Icon(Icons.edit_outlined), tooltip: '발화 편집', onPressed: () => _editSegment(index)), dense: true)); }),
    ]),
  );
}
