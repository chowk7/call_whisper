import 'package:flutter/material.dart';

import 'features/settings/model_settings_page.dart';
import 'features/transcription/transcription_page.dart';
import 'services/model_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallWhisperApp());
}

class CallWhisperApp extends StatelessWidget {
  const CallWhisperApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Call Whisper',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315cdb)),
          useMaterial3: true,
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Call Whisper')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 40),
          const Icon(Icons.graphic_eq, size: 72),
          const SizedBox(height: 20),
          const Text('녹음 파일을 선택하면\n기기 안에서 전사합니다.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TranscriptionPage(),
            )),
            icon: const Icon(Icons.audio_file), label: const Text('녹음 파일 선택'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ModelSettingsPage(manager: WhisperModelManager()),
            )),
            icon: const Icon(Icons.settings), label: const Text('모델 설정'),
          ),
        ]),
      );
}
