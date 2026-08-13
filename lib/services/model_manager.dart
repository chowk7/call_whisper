import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_catalog.dart';

enum ModelInstallState { notInstalled, downloading, installed, failed }

class ModelStatus {
  const ModelStatus(this.state, {this.progress = 0, this.error});
  final ModelInstallState state;
  final double progress;
  final String? error;
}

/// Stores models in the app's private documents directory. A partial download
/// never replaces an installed model: it is written as `.part` then renamed.
class WhisperModelManager {
  WhisperModelManager({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final _changes = StreamController<void>.broadcast();
  final Map<String, ModelStatus> _statuses = {};
  bool _loaded = false;
  String? _selectedId;

  Stream<void> get changes => _changes.stream;
  String? get selectedId => _selectedId;
  ModelStatus statusOf(WhisperModel model) =>
      _statuses[model.id] ?? const ModelStatus(ModelInstallState.notInstalled);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedId = prefs.getString('selected_whisper_model');
    for (final model in whisperModels) {
      if (await _modelFile(model).then((file) => file.exists())) {
        _statuses[model.id] = const ModelStatus(ModelInstallState.installed);
      }
    }
    _loaded = true;
    _changes.add(null);
  }

  Future<File?> installedFile(WhisperModel model) async {
    final file = await _modelFile(model);
    return await file.exists() ? file : null;
  }

  Future<void> install(WhisperModel model) async {
    if (statusOf(model).state == ModelInstallState.downloading) return;
    final target = await _modelFile(model);
    final partial = File('${target.path}.part');
    await target.parent.create(recursive: true);
    if (await partial.exists()) await partial.delete();
    _set(model.id, const ModelStatus(ModelInstallState.downloading));
    try {
      final request = http.Request('GET', model.downloadUrl);
      final response = await _client.send(request);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('모델 서버 응답: ${response.statusCode}');
      }
      final expected = response.contentLength ?? model.sizeBytes;
      var received = 0;
      final sink = partial.openWrite();
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        _set(model.id, ModelStatus(ModelInstallState.downloading,
            progress: (received / expected).clamp(0.0, 1.0).toDouble()));
      }
      await sink.close();
      if (received < model.sizeBytes * 0.9) throw HttpException('모델 파일이 불완전합니다.');
      await partial.rename(target.path);
      _set(model.id, const ModelStatus(ModelInstallState.installed));
      await select(model);
    } catch (error) {
      if (await partial.exists()) await partial.delete();
      _set(model.id, ModelStatus(ModelInstallState.failed, error: '$error'));
    }
  }

  Future<void> select(WhisperModel model) async {
    if (await installedFile(model) == null) return;
    _selectedId = model.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_whisper_model', model.id);
    _changes.add(null);
  }

  Future<void> remove(WhisperModel model) async {
    final file = await _modelFile(model);
    if (await file.exists()) await file.delete();
    if (_selectedId == model.id) {
      _selectedId = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_whisper_model');
    }
    _set(model.id, const ModelStatus(ModelInstallState.notInstalled));
  }

  Future<File> _modelFile(WhisperModel model) async {
    final directory = await getApplicationDocumentsDirectory();
    return File(path.join(directory.path, 'models', model.fileName));
  }

  void _set(String id, ModelStatus status) {
    _statuses[id] = status;
    _changes.add(null);
  }

  void dispose() { _changes.close(); _client.close(); }
}
