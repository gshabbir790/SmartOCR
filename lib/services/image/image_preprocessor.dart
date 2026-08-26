import 'dart:io';

import 'package:image/image.dart' as img;

class ImagePreprocessor {
  Future<String> prepare(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return inputPath;

    var image = img.bakeOrientation(decoded);

    // Preserve enough horizontal detail for Nastaliq joins and diacritics.
    // Very large images are still reduced to keep on-device OCR responsive.
    if (image.width > 2600) {
      image = img.copyResize(image, width: 2600);
    }

    image = img.grayscale(image);
    image = img.normalize(image, min: 0, max: 255);
    image = img.adjustColor(image, contrast: 1.08);

    final dir = File(inputPath).parent.path;
    final output = '$dir/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(output).writeAsBytes(img.encodeJpg(image, quality: 95));
    return output;
  }
}
