import 'package:flutter/material.dart';

/// Shown immediately after the native Android launch screen (which is just
/// the brand color + icon, since XML drawables can't reliably render text
/// across devices/fonts). This widget carries the actual branding — app
/// name and developer credit — for a short, fixed duration before handing
/// off to onboarding or home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _kSplashDuration = Duration(milliseconds: 1600);

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
    return const Scaffold(
      backgroundColor: Color(0xFF4967F5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Spacer(flex: 3),
              _Logo(),
              SizedBox(height: 28),
              Text(
                'Smart OCR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Spacer(flex: 3),
              Text(
                'Developed & Maintained by Ghulam Shabbir',
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.document_scanner_rounded, size: 58, color: Colors.white),
    );
  }
}
