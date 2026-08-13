class WhisperModel {
  const WhisperModel({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.description,
    required this.downloadUrl,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final String description;
  final Uri downloadUrl;

  String get fileName => 'ggml-$id.bin';
  String get sizeLabel => '${(sizeBytes / 1024 / 1024).round()} MB';
}

/// Official whisper.cpp GGML files. The app downloads only after a user tap.
final whisperModels = <WhisperModel>[
  WhisperModel(
    id: 'base',
    name: 'Base',
    sizeBytes: 141 * 1024 * 1024,
    description: '가볍고 빠름. 짧은 녹음 또는 저사양 기기용',
    downloadUrl: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin'),
  ),
  WhisperModel(
    id: 'small',
    name: 'Small',
    sizeBytes: 466 * 1024 * 1024,
    description: '권장. 한국어 정확도와 처리 속도의 균형',
    downloadUrl: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin'),
  ),
  WhisperModel(
    id: 'medium',
    name: 'Medium',
    sizeBytes: 1500 * 1024 * 1024,
    description: '높은 정확도. 충분한 저장공간과 최신 기기 권장',
    downloadUrl: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin'),
  ),
];
