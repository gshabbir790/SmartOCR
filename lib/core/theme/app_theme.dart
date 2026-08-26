import 'package:flutter/material.dart';

class AppTheme {
  static const Color brand = Color(0xFF4967F5);

  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: brand.withValues(alpha: 0.12),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: brand, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), filled: true, fillColor: b == Brightness.dark ? const Color(0xFF161B22) : Colors.white),
    );
  }
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);
}
