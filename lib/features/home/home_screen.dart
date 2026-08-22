import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ocr_models.dart';
import '../../services/ocr/ocr_service.dart';
import '../../services/share/share_intent_service.dart';
import '../../services/storage/history_repository.dart';
import '../ocr/ocr_result_screen.dart';
import '../scanner/camera_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

const _kOcrLanguagePrefKey = 'ocr_language';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.history, required this.ocr, required this.share, required this.onThemeChanged});
  final HistoryRepository history;
  final OcrService ocr;
  final ShareIntentService share;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String _language = 'eng';

  @override
  void initState() {
    super.initState();
    widget.share.images.listen(_handleSharedImages);
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kOcrLanguagePrefKey);
    if (saved != null && kSupportedOcrLanguages.containsKey(saved) && mounted) {
      setState(() => _language = saved);
    }
  }

  Future<void> _setLanguage(String lang) async {
    setState(() => _language = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOcrLanguagePrefKey, lang);
  }

  Future<void> _handleSharedImages(List<String> paths) async {
    if (!mounted || _busy) return;
    await _process(paths, shared: true);
  }

  Future<void> _gallery() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 95);
    if (files.isEmpty) return;
    await _process(files.map((e) => e.path).toList());
  }

  Future<void> _process(List<String> paths, {bool shared = false}) async {
    setState(() => _busy = true);
    final texts = <String>[];
    String? firstPath;
    try {
      for (final path in paths) {
        firstPath ??= path;
        final result = await widget.ocr.recognize(path, language: _language);
        texts.add(result.text);
      }
      final combined = texts.asMap().entries.map((e) => paths.length > 1 ? '--- Image ${e.key + 1} ---\n${e.value}' : e.value).join('\n\n');
      final item = HistoryItem(id: const Uuid().v4(), path: firstPath!, text: combined, createdAt: DateTime.now(), title: paths.length > 1 ? '${paths.length} images' : 'Scan');
      await widget.history.save(item);
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => OcrResultScreen(item: item, imagePaths: paths, history: widget.history)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is FormatException ? e.message : 'Could not process this image.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Smart OCR', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(icon: const Icon(Icons.history_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(history: widget.history)))), IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onThemeChanged: widget.onThemeChanged))))]),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 12),
      Text('Scan anything', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.2)),
      const SizedBox(height: 8),
      Text('Extract, understand and use text from images.', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.translate_rounded, size: 20),
        const SizedBox(width: 8),
        const Text('OCR language', style: TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        DropdownButton<String>(
          value: _language,
          items: kSupportedOcrLanguages.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) { if (v != null) _setLanguage(v); },
        ),
      ]),
      const SizedBox(height: 22),
      Row(children: [Expanded(child: _ActionCard(icon: Icons.camera_alt_rounded, title: 'Scan with Camera', subtitle: 'Capture a document', onTap: () async { final path = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => const CameraScreen())); if (path != null) await _process([path]); })), const SizedBox(width: 14), Expanded(child: _ActionCard(icon: Icons.photo_library_rounded, title: 'Gallery', subtitle: 'Choose one or more', onTap: _gallery))]),
      const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(26)), child: Row(children: [Icon(Icons.ios_share_rounded, size: 30, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Share directly to Smart OCR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 5), Text('From Gallery or Photos, tap Share → Smart OCR. OCR starts automatically.', style: TextStyle(height: 1.35))]))]),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Recent scans', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(history: widget.history))), child: const Text('View all'))]),
      const SizedBox(height: 12),
      ...widget.history.all().take(5).map(
        (item) => _HistoryTile(
          item: item,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OcrResultScreen(
                item: item,
                imagePaths: [item.path],
                history: widget.history,
              ),
            ),
          ),
        ),
      ),
      if (widget.history.all().isEmpty) const _EmptyState(),
      if (_busy) const Padding(padding: EdgeInsets.only(top: 20), child: LinearProgressIndicator()),
    ])),
  );
}

class _ActionCard extends StatelessWidget { const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap}); final IconData icon; final String title, subtitle; final VoidCallback onTap; @override Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 22), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 6), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])))); }
class _HistoryTile extends StatelessWidget { const _HistoryTile({required this.item, required this.onTap}); final HistoryItem item; final VoidCallback onTap; @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: onTap, leading: ClipRRect(borderRadius: BorderRadius.circular(12), child: File(item.path).existsSync() ? Image.file(File(item.path), width: 54, height: 54, fit: BoxFit.cover) : const SizedBox(width: 54, height: 54, child: Icon(Icons.description_outlined))), title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis))); }
class _EmptyState extends StatelessWidget { const _EmptyState(); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24)), child: const Column(children: [Icon(Icons.document_scanner_outlined, size: 42), SizedBox(height: 10), Text('Your scans will appear here.'), SizedBox(height: 4), Text('Start with a camera scan or gallery image.') ])); }
