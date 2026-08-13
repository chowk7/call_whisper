class TranscriptSegment {
  const TranscriptSegment({
    required this.startMs,
    required this.endMs,
    required this.speakerId,
    required this.text,
  });

  final int startMs;
  final int endMs;
  final String speakerId;
  final String text;

  TranscriptSegment copyWith({String? speakerId, String? text}) => TranscriptSegment(
        startMs: startMs,
        endMs: endMs,
        speakerId: speakerId ?? this.speakerId,
        text: text ?? this.text,
      );

  String get timestamp {
    final seconds = startMs ~/ 1000;
    String unit(int value) => value.toString().padLeft(2, '0');
    return '${unit(seconds ~/ 3600)}:${unit((seconds % 3600) ~/ 60)}:${unit(seconds % 60)}';
  }

  String toPlainText({Map<String, String> speakerNames = const {}}) =>
      '($timestamp, ${speakerNames[speakerId] ?? speakerId}) $text';

  factory TranscriptSegment.fromMap(Map<Object?, Object?> value) => TranscriptSegment(
        startMs: value['startMs']! as int,
        endMs: value['endMs']! as int,
        speakerId: value['speakerId']! as String,
        text: value['text']! as String,
      );
}
