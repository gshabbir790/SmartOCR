import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ocr/data/models/ocr_models.dart';
void main(){test('OCR result preserves RTL text as unicode',(){const r=OcrResult(text:'یہ ایک نوٹس ہے',language:'urd',confidence:.9);expect(r.text,'یہ ایک نوٹس ہے');expect(r.language,'urd');});}
