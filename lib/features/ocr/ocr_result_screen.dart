import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/ocr_models.dart';
import '../../services/ai/ai_service.dart';
import '../../services/storage/history_repository.dart';
import '../conversation/conversation_screen.dart';
import '../settings/settings_screen.dart'
    show kAiBackendUrlPrefKey, kCloudFallbackPrefKey;

class OcrResultScreen extends StatefulWidget {
  const OcrResultScreen({
    super.key,
    required this.item,
    required this.imagePaths,
    required this.history,
  });

  final HistoryItem item;
  final List<String> imagePaths;
  final HistoryRepository history;

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  late final TextEditingController _text;
  String? _aiBackendUrl;
  bool _cloudFallbackEnabled = false;
  bool _aiOcrBusy = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.item.text);
    _loadAiSettings();
  }

  Future<void> _loadAiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _aiBackendUrl = prefs.getString(kAiBackendUrlPrefKey);
      _cloudFallbackEnabled = prefs.getBool(kCloudFallbackPrefKey) ?? false;
    });
  }

  Future<void> _tryAiOcr() async {
    final url = _aiBackendUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an AI backend URL in Settings first.')),
      );
      return;
    }
    if (!File(widget.item.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original image is no longer available.')),
      );
      return;
    }

    setState(() => _aiOcrBusy = true);
    try {
      final result = await CloudOcrProvider(url).extractText(widget.item.path);
      if (result.trim().isEmpty) {
        throw Exception('empty');
      }
      if (mounted) {
        setState(() => _text.text = result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated with AI OCR result. Review and Save if it looks right.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI OCR failed. Check your internet connection and backend URL.')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiOcrBusy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.history.save(
      HistoryItem(
        id: widget.item.id,
        path: widget.item.path,
        text: _text.text,
        createdAt: widget.item.createdAt,
        title: widget.item.title,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: _text.text));
  }

  Future<void> _search() async {
    final uri = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent(_text.text)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final imageExists = File(widget.item.path).existsSync();
    final isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F]').hasMatch(_text.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Result'),
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.bookmark_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: imageExists
                ? Image.file(
                    File(widget.item.path),
                    height: 220,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 220,
                    color: Colors.black12,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _text,
            maxLines: null,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            decoration: const InputDecoration(
              hintText: 'Extracted text',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Copy'),
                avatar: const Icon(Icons.copy, size: 18),
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: _text.text),
                ),
              ),
              ActionChip(
                label: const Text('Save'),
                avatar: const Icon(Icons.save_outlined),
                onPressed: _save,
              ),
              ActionChip(
                label: const Text('Search'),
                avatar: const Icon(Icons.search),
                onPressed: _search,
              ),
              ActionChip(
                label: const Text('Ask AI'),
                avatar: const Icon(Icons.auto_awesome),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      ocrText: _text.text,
                      imagePaths: widget.imagePaths,
                    ),
                  ),
                ),
              ),
              if (_cloudFallbackEnabled)
                ActionChip(
                  label: Text(_aiOcrBusy ? 'Reading with AI…' : 'Try AI OCR'),
                  avatar: _aiOcrBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  onPressed: _aiOcrBusy ? null : _tryAiOcr,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
