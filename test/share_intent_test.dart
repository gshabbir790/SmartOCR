import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ocr/services/share/share_intent_service.dart';

void main() {
  test('share service exposes an image stream', () {
    final service = ShareIntentService();
    expect(service.images, isA<Stream<List<String>>>());
  });
}
