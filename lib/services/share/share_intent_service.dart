import 'dart:async';
import 'package:flutter/services.dart';

class ShareIntentService {
  static const _channel = MethodChannel('smart_ocr/share');
  final _controller = StreamController<List<String>>.broadcast();
  List<String>? _pending;

  /// Returns the stream and also delivers an image that arrived before the
  /// first Flutter screen subscribed (the common case when Android launches
  /// the app directly from Gallery's Share sheet).
  Stream<List<String>> get images async* {
    final pending = _pending;
    _pending = null;
    if (pending != null && pending.isNotEmpty) {
      yield pending;
    }
    yield* _controller.stream;
  }

  void _emit(List<String> paths) {
    if (paths.isEmpty) return;
    if (_controller.hasListener) {
      _controller.add(paths);
    } else {
      _pending = paths;
    }
  }

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedImages') {
        final paths = List<String>.from(call.arguments as List);
        _emit(paths);
      }
    });

    try {
      final paths = await _channel.invokeMethod<List<dynamic>>('getInitialImages');
      if (paths != null && paths.isNotEmpty) {
        _emit(List<String>.from(paths));
      }
    } catch (_) {
      // Android share integration is optional; normal camera/gallery OCR still
      // works if the platform channel is unavailable.
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
