import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/ocr_models.dart';
import '../../services/storage/history_repository.dart';
import '../conversation/conversation_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.item.text);
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
            ],
          ),
        ],
      ),
    );
  }
}
