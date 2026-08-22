import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4967F5), brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FC),
      cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), filled: true, fillColor: b == Brightness.dark ? const Color(0xFF161B22) : Colors.white),
    );
  }
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);
}
