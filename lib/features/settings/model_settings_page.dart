import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/model_catalog.dart';
import '../../services/model_manager.dart';

class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key, required this.manager});
  final WhisperModelManager manager;
  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  StreamSubscription<void>? _subscription;
  @override
  void initState() {
    super.initState();
    widget.manager.load();
    _subscription = widget.manager.changes.listen((_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _subscription?.cancel(); widget.manager.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Whisper 모델 설정')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('모델은 기기에만 저장되며, 설치 후 인터넷 없이 전사할 수 있습니다.'),
        const SizedBox(height: 12),
        ...whisperModels.map((model) => _modelTile(context, model)),
      ],
    ),
  );

  Widget _modelTile(BuildContext context, WhisperModel model) {
    final status = widget.manager.statusOf(model);
    final installed = status.state == ModelInstallState.installed;
    final selected = widget.manager.selectedId == model.id;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${model.name} · ${model.sizeLabel}', style: Theme.of(context).textTheme.titleMedium)),
          if (selected) const Chip(label: Text('사용 중')),
        ]),
        Text(model.description),
        if (status.state == ModelInstallState.downloading) ...[
          const SizedBox(height: 10), LinearProgressIndicator(value: status.progress),
          Text('다운로드 ${(status.progress * 100).toStringAsFixed(0)}%'),
        ],
        if (status.state == ModelInstallState.failed) Text(status.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        Row(children: [
          if (!installed) FilledButton.icon(
            onPressed: status.state == ModelInstallState.downloading ? null : () => widget.manager.install(model),
            icon: const Icon(Icons.download), label: Text(status.state == ModelInstallState.failed ? '다시 다운로드' : '다운로드 및 설치'),
          ) else ...[
            OutlinedButton(onPressed: selected ? null : () => widget.manager.select(model), child: const Text('이 모델 사용')),
            const SizedBox(width: 8),
            TextButton(onPressed: () => widget.manager.remove(model), child: const Text('삭제')),
          ],
        ]),
      ]),
    ));
  }
}
