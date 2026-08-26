import 'dart:io';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  Future<String> prepare(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return inputPath;

    var image = img.bakeOrientation(decoded);

    // Nastaliq has very thin dots and diacritics. Upscaling before contrast
    // work gives the recognizer more pixels to distinguish these marks.
    if (image.width < 1800) {
      image = img.copyResize(image, width: 1800, interpolation: img.Interpolation.cubic);
    } else if (image.width > 2600) {
      image = img.copyResize(image, width: 2600, interpolation: img.Interpolation.cubic);
    }

    image = img.grayscale(image);
    image = img.normalize(image, min: 8, max: 248);
    image = img.adjustColor(image, contrast: 1.08);

    // Keep a high-quality JPEG; aggressive thresholding is intentionally
    // avoided because it can erase Nastaliq dots/diacritics.
    final dir = File(inputPath).parent.path;
    final output = '$dir/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(output).writeAsBytes(img.encodeJpg(image, quality: 96));
    return output;
  }
}
