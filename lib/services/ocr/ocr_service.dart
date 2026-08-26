import 'dart:io';

import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

abstract interface class OcrProvider {
  Future<OcrResult> recognize(String path, {String language = 'eng'});
}

class LocalTesseractProvider implements OcrProvider {
  @override
  Future<OcrResult> recognize(String path, {String language = 'eng'}) async {
    if (!await File(path).exists()) {
      throw const FileSystemException('Image not found');
    }

    // Urdu/Nastaliq is particularly sensitive to page segmentation. A single
    // block works better for normal documents, while sparse mode is safer for
    // mixed layouts. Keep Urdu isolated instead of combining it with Arabic.
    final pageMode = language == 'urd' ? '6' : '3';
    final config = OCRConfig(
      language: language,
      engine: OCREngine.tesseract,
      options: {
        TesseractConfig.preserveInterwordSpaces: '1',
        'tessedit_pageseg_mode': pageMode,
      },
    );

    final text = await TesseractOcr.extractText(path, config: config);
    final cleaned = _cleanText(text);
    final confidence = cleaned.isEmpty ? 0.0 : 0.82;

    return OcrResult(
      text: cleaned,
      language: language,
      confidence: confidence,
      blocks: cleaned.isEmpty
          ? []
          : [OcrBlock(text: cleaned, confidence: confidence)],
    );
  }

  String _cleanText(String value) {
    // Remove invisible bidi/control characters that can make otherwise valid
    // Urdu appear scrambled when copied between apps.
    return value
        .replaceAll('\u0000', '')
        .replaceAll('\u000B', '')
        .replaceAll('\u000C', '')
        .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
  }
}

const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',
  'urd': 'اردو (Urdu)',
  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

typedef OcrProgressCallback = void Function(String stage);

const _kAutoDetectLanguages = <String, String>{
  'urd': 'Reading Urdu text…',
  'eng': 'Reading English text…',
  'ara': 'Reading Arabic text…',
  'hin': 'Reading Hindi text…',
};

class OcrService {
  final OcrProvider local = LocalTesseractProvider();
  final ImagePreprocessor _preprocessor = ImagePreprocessor();

  Future<void> init() async {}

  Future<OcrResult> recognize(
    String path, {
    OcrProgressCallback? onProgress,
  }) async {
    onProgress?.call('Preparing image…');
    String preparedPath = path;

    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      preparedPath = path;
    }

    OcrResult? best;
    int bestScore = -1;

    for (final entry in _kAutoDetectLanguages.entries) {
      onProgress?.call(entry.value);
      final result = await local.recognize(preparedPath, language: entry.key);
      final score = _score(result.text, entry.key);
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }
    }

    onProgress?.call('Finalizing…');
    if (best == null || best.text.isEmpty) {
      throw const FormatException('No readable text found.');
    }
    return best;
  }

  int _score(String text, String language) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return -1;

    final total = cleaned.replaceAll(RegExp(r'\s'), '').length;
    if (total == 0) return -1;

    final script = switch (language) {
      'urd' || 'ara' => RegExp(r'[\u0600-\u06FF\u0750-\u077F]'),
      'hin' => RegExp(r'[\u0900-\u097F]'),
      _ => RegExp(r'[A-Za-z]'),
    };

    final scriptCount = script.allMatches(cleaned).length;
    final ratio = scriptCount / total;
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    // A language gets a strong bonus when its own script dominates. This
    // prevents Arabic/Urdu or Latin garbage from winning only because it has
    // a high generic "letter" ratio.
    final scriptBonus = ratio >= 0.55 ? 500 : ratio >= 0.30 ? 150 : 0;
    return (ratio * 1000).round() + scriptCount + (words * 2) + scriptBonus;
  }
}
