import 'dart:io';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

abstract interface class OcrProvider {
  Future<OcrResult> recognize(String path, {String language = 'eng'});
}

/// Local/offline Tesseract provider.
///
/// `urd_naw` is a community-contributed Urdu model specifically trained for
/// Urdu Nastaliq. The normal `urd` model is kept as a fallback. Tesseract's
/// official `tessdata_best` models are more accurate than `tessdata_fast`, but
/// `urd_naw` is the better fit for Pakistani/Urdu Nastaliq text.
class LocalTesseractProvider implements OcrProvider {
  @override
  Future<OcrResult> recognize(String path, {String language = 'eng'}) async {
    if (!await File(path).exists()) {
      throw const FileSystemException('Image not found');
    }

    final isUrdu = language == 'urd_naw' || language == 'urd';
    final config = OCRConfig(
      language: language,
      engine: OCREngine.tesseract,
      options: {
        TesseractConfig.preserveInterwordSpaces: '1',
        // Do not use OSD for Urdu Nastaliq. OSD can misclassify the script and
        // is unnecessary when the language model is explicitly selected.
        TesseractConfig.pageSegMode:
            isUrdu ? PageSegmentationMode.auto : PageSegmentationMode.auto,
        if (isUrdu) 'load_system_dawg': '1',
        if (isUrdu) 'load_freq_dawg': '1',
      },
    );

    final text = await TesseractOcr.extractText(path, config: config);
    final cleaned = _cleanOcrText(text);
    final confidence = _estimateConfidence(cleaned, language);

    return OcrResult(
      text: cleaned,
      language: language,
      confidence: confidence,
      blocks: cleaned.isEmpty
          ? []
          : [OcrBlock(text: cleaned, confidence: confidence)],
    );
  }

  String _cleanOcrText(String input) {
    // Keep logical character order intact. Flutter's RTL text engine should
    // handle visual ordering; reversing an Urdu string here would corrupt it.
    var text = input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // Tesseract can leave a space immediately before punctuation. This is
    // especially noticeable in Urdu Nastaliq output.
    text = text.replaceAll(RegExp(r'\s+([،۔,:;!?])'), r'\1');
    return text;
  }

  double _estimateConfidence(String text, String language) {
    if (text.isEmpty) return 0;
    final compact = text.replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty) return 0;

    final script = language == 'urd_naw' || language == 'urd'
        ? RegExp(r'[\u0600-\u06FF\u0750-\u077F]')
        : language == 'hin'
            ? RegExp(r'[\u0900-\u097F]')
            : RegExp(r'[A-Za-z]');
    final ratio = script.allMatches(compact).length / compact.length;
    return (0.72 + (ratio * 0.23)).clamp(0.0, 0.95);
  }
}

/// Language packs expected in assets/tessdata/.
const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',
  'urd_naw': 'اردو — Nastaliq',
  'urd': 'اردو — fallback',
  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

typedef OcrProgressCallback = void Function(String stage);

/// Auto-detection intentionally gives Urdu Nastaliq a dedicated pass instead
/// of merging it with Arabic. The old `urd+ara` approach can confuse the
/// different orthography/dictionaries, while the dedicated `urd_naw` model is
/// designed for Urdu Nastaliq.
const _kAutoDetectLanguages = <String, String>{
  'eng': 'Reading English text…',
  'urd_naw': 'Reading Urdu Nastaliq…',
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

    // For Nastaliq, preserving the original grayscale information is often
    // safer than aggressive thresholding. The preprocessor creates a clean,
    // enlarged copy while retaining thin dots/diacritics.
    String preparedPath = path;
    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      preparedPath = path;
    }

    OcrResult? best;
    double bestScore = double.negativeInfinity;

    for (final entry in _kAutoDetectLanguages.entries) {
      onProgress?.call(entry.value);
      final result = await local.recognize(preparedPath, language: entry.key);
      final score = _score(result.text, entry.key);
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }
    }

    // If the specialised Nastaliq pass produced a plausible result, prefer it
    // over a generic Arabic result. This protects Urdu posters/newspaper-style
    // text from being incorrectly labelled Arabic.
    onProgress?.call('Verifying Urdu text…');
    final urdu = await local.recognize(preparedPath, language: 'urd_naw');
    final urduScore = _score(urdu.text, 'urd_naw');
    if (urdu.text.isNotEmpty && urduScore >= 360) {
      if (best == null || urduScore >= bestScore - 45) {
        best = urdu;
      }
    }

    // The generic Urdu model is a safety net for images that are Urdu but not
    // strongly Nastaliq (for example some Naskh/typed Urdu documents).
    if (best == null || best.text.isEmpty) {
      onProgress?.call('Retrying Urdu OCR…');
      final fallback = await local.recognize(preparedPath, language: 'urd');
      if (fallback.text.isNotEmpty) best = fallback;
    }

    onProgress?.call('Finalizing…');
    if (best == null || best.text.isEmpty) {
      throw const FormatException('No readable text found.');
    }
    return best;
  }

  double _score(String text, String language) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return -1000;

    final compact = cleaned.replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty) return -1000;

    final letters = language == 'hin'
        ? RegExp(r'[\u0900-\u097F]')
        : language == 'eng'
            ? RegExp(r'[A-Za-z]')
            : RegExp(r'[\u0600-\u06FF\u0750-\u077F]');

    final letterCount = letters.allMatches(compact).length;
    final ratio = letterCount / compact.length;
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    var score = (ratio * 700) + (words * 22) + (letterCount * 1.5);

    if (language == 'urd_naw') {
      // Characters strongly associated with Urdu are a useful discriminator
      // against Arabic when both scripts are visually similar.
      final urduSpecific = RegExp(r'[ٹڈڑںھےژگپچڤک]')
          .allMatches(cleaned)
          .length;
      score += urduSpecific * 38;
      if (words >= 4) score += 80;
    }
    if (language == 'ara') {
      final urduSpecific = RegExp(r'[ٹڈڑںھےژگپچڤ]')
          .allMatches(cleaned)
          .length;
      score -= urduSpecific * 32;
    }

    return score;
  }
}
