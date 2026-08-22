class OcrBlock {
  const OcrBlock({required this.text, this.confidence = 0});
  final String text;
  final double confidence;
}

class OcrResult {
  const OcrResult({required this.text, required this.language, required this.confidence, this.blocks = const []});
  final String text;
  final String language;
  final double confidence;
  final List<OcrBlock> blocks;
}

class HistoryItem {
  const HistoryItem({required this.id, required this.path, required this.text, required this.createdAt, this.title = 'Scan'});
  final String id;
  final String path;
  final String text;
  final DateTime createdAt;
  final String title;
}
