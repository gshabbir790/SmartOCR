import 'package:flutter/material.dart';

/// Shown immediately after the native Android launch screen (which is just
/// the brand color + icon, since XML drawables can't reliably render text
/// across devices/fonts). This widget carries the actual branding — app
/// name and developer credit.
///
/// Deliberately has NO entrance animation: an earlier version faded the
/// icon+text in together over 700ms, but because the native launch screen
/// already shows the icon at full opacity, the handoff moment made it look
/// like the icon appeared first and the text caught up late. Rendering
/// everything at full opacity from the first frame removes that flicker —
/// icon and text are visually identical the instant Flutter takes over.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _kSplashDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    Future.delayed(_kSplashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.next),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4967F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              const Spacer(flex: 5),
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 58, color: Colors.white),
              ),
              const SizedBox(height: 26),
              const Text(
                'Smart OCR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scan. Extract. Understand.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(flex: 6),
              const Text(
                'Developed & Maintained by Ghulam Shabbir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
