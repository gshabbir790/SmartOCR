import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/ocr_models.dart';
import '../../services/ocr/ocr_service.dart';
import '../../services/share/share_intent_service.dart';
import '../../services/storage/history_repository.dart';
import '../ocr/ocr_result_screen.dart';
import '../scanner/camera_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';

const kDeveloperCredit = 'Developed & Maintained by Ghulam Shabbir';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.history,
    required this.ocr,
    required this.share,
    required this.onThemeChanged,
  });

  final HistoryRepository history;
  final OcrService ocr;
  final ShareIntentService share;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String _stage = '';

  @override
  void initState() {
    super.initState();
    widget.share.images.listen(_handleSharedImages);
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
    setState(() {
      _busy = true;
      _stage = 'Preparing image…';
    });
    final texts = <String>[];
    String? firstPath;
    try {
      for (final path in paths) {
        firstPath ??= path;
        final result = await widget.ocr.recognize(
          path,
          onProgress: (stage) {
            if (mounted) setState(() => _stage = stage);
          },
        );
        texts.add(result.text);
      }
      final combined = texts
          .asMap()
          .entries
          .map((e) => paths.length > 1 ? '--- Image ${e.key + 1} ---\n${e.value}' : e.value)
          .join('\n\n');

      final item = HistoryItem(
        id: const Uuid().v4(),
        path: firstPath!,
        text: combined,
        createdAt: DateTime.now(),
        title: paths.length > 1 ? '${paths.length} images' : 'Scan',
      );

      await widget.history.save(item);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OcrResultScreen(
              item: item,
              imagePaths: paths,
              history: widget.history,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is FormatException ? e.message : 'Could not process this image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.history.all();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart OCR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistoryScreen(history: widget.history)),
              );
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(onThemeChanged: widget.onThemeChanged)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Extract, understand and use text from images.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      _ActionButton(
                        icon: Icons.camera_alt_rounded,
                        title: 'Scan with Camera',
                        subtitle: 'Capture a document',
                        onTap: () async {
                          final path = await Navigator.push<String?>(
                            context,
                            MaterialPageRoute(builder: (_) => const CameraScreen()),
                          );
                          if (path != null) await _process([path]);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.photo_library_rounded,
                        title: 'Select from Gallery',
                        subtitle: 'Choose one or more',
                        onTap: _gallery,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent scans', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => HistoryScreen(history: widget.history)),
                              );
                              if (mounted) setState(() {});
                            },
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: history.isEmpty
                      ? const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _EmptyState())
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          itemCount: history.length,
                          itemBuilder: (context, i) {
                            final item = history[i];
                            return _HistoryTile(
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
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_busy) _ProcessingOverlay(stage: _stage),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4))),
        ),
        child: Text(
          kDeveloperCredit,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Scanning your document',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    stage.isEmpty ? 'Working…' : stage,
                    key: ValueKey(stage),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: File(item.path).existsSync()
              ? Image.file(File(item.path), width: 54, height: 54, fit: BoxFit.cover)
              : const SizedBox(width: 54, height: 54, child: Icon(Icons.description_outlined)),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          item.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Icon(Icons.document_scanner_outlined, size: 42),
          SizedBox(height: 10),
          Text('Your scans will appear here.'),
          SizedBox(height: 4),
          Text('Start with a camera scan or gallery image.'),
        ],
      ),
    );
  }
}
