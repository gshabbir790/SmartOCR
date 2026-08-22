import 'dart:async';
import 'package:flutter/services.dart';

class ShareIntentService {
  static const _channel = MethodChannel('smart_ocr/share');
  final _controller = StreamController<List<String>>.broadcast();
  Stream<List<String>> get images => _controller.stream;

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedImages') {
        final paths = List<String>.from(call.arguments as List);
        // یہاں بریکٹس { } شامل کیے گئے ہیں
        if (paths.isNotEmpty) {
          _controller.add(paths);
        }
      }
    });
    try {
      final paths = await _channel.invokeMethod<List<dynamic>>('getInitialImages');
      // یہاں بھی بریکٹس { } شامل کیے گئے ہیں
      if (paths != null && paths.isNotEmpty) {
        _controller.add(List<String>.from(paths));
      }
    } catch (_) {}
  }
}
