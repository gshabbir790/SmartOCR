import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, required this.home});

  /// Persists that onboarding has been seen (e.g. writes a SharedPreferences flag).
  final Future<void> Function() onDone;

  /// The screen to navigate to once onboarding finishes. Onboarding owns its
  /// own navigation via this screen's live BuildContext — relying on the
  /// app's root `MaterialApp.home` to change was the bug: once the Navigator
  /// has already pushed past the initial route, rebuilding `home` higher up
  /// the tree has no effect on the route stack, so Skip/Get started looked
  /// like it did nothing until the app was restarted.
  final Widget home;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final pages = const [
    ('Scan any image', Icons.document_scanner_rounded, 'Capture or share a document in seconds.'),
    ('Extract text instantly', Icons.text_fields_rounded, 'Edit, copy, save and share clean OCR text.'),
    ('Ask AI about your images', Icons.auto_awesome_rounded, 'Keep the image and OCR context together for smarter questions.'),
  ];
  int index = 0;
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await widget.onDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.home));
  }

  @override
  Widget build(BuildContext context) {
    final p = pages[index];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(color: Color(0xFFE9EDFF), shape: BoxShape.circle),
                child: Icon(p.$2, size: 68, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 44),
              Text(p.$1, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(p.$3, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index ? Theme.of(context).colorScheme.primary : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _finishing
                      ? null
                      : () {
                          if (index == pages.length - 1) {
                            _finish();
                          } else {
                            setState(() => index++);
                          }
                        },
                  child: _finishing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(index == pages.length - 1 ? 'Get started' : 'Continue'),
                ),
              ),
              TextButton(onPressed: _finishing ? null : _finish, child: const Text('Skip')),
            ],
          ),
        ),
      ),
    );
  }
}
