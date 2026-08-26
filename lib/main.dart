import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/home/onboarding_screen.dart';
import 'features/home/splash_screen.dart';
import 'services/ocr/ocr_service.dart';
import 'services/share/share_intent_service.dart';
import 'services/storage/history_repository.dart';

const _kOnboardingSeenKey = 'onboarding_seen';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final history = HistoryRepository();
  await history.init();
  final ocr = OcrService();
  await ocr.init();
  final share = ShareIntentService();
  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool(_kOnboardingSeenKey) ?? false);
  runApp(SmartOcrApp(history: history, ocr: ocr, share: share, showOnboarding: showOnboarding));
}

class SmartOcrApp extends StatefulWidget {
  const SmartOcrApp({super.key, required this.history, required this.ocr, required this.share, required this.showOnboarding});
  final HistoryRepository history;
  final OcrService ocr;
  final ShareIntentService share;
  final bool showOnboarding;

  @override
  State<SmartOcrApp> createState() => _SmartOcrAppState();
}

class _SmartOcrAppState extends State<SmartOcrApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    widget.share.initialize();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final home = HomeScreen(
      history: widget.history,
      ocr: widget.ocr,
      share: widget.share,
      onThemeChanged: (m) => setState(() => _mode = m),
    );
    return MaterialApp(
      title: 'Smart OCR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(
        next: widget.showOnboarding
            ? OnboardingScreen(onDone: _completeOnboarding, home: home)
            : home,
      ),
    );
  }
}
