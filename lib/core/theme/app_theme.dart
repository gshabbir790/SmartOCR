import 'package:flutter/material.dart';

class AppTheme {
  static const Color brand = Color(0xFF2563EB);
  static const Color brandDeep = Color(0xFF173B8F);

  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: b,
      primary: brand,
      surface: b == Brightness.dark ? const Color(0xFF101828) : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          b == Brightness.dark ? const Color(0xFF0B1220) : const Color(0xFFF6F8FC),
      appBarTheme: AppBarTheme(
        backgroundColor: b == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: b == Brightness.dark ? Colors.white : const Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: b == Brightness.dark ? Colors.white : const Color(0xFF111827),
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: b == Brightness.dark ? const Color(0xFF111827) : Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: b == Brightness.dark ? const Color(0xFF111827) : Colors.white,
      ),
      dividerTheme: DividerThemeData(
        color: b == Brightness.dark ? Colors.white12 : const Color(0xFFE5E7EB),
      ),
    );
  }

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);
}
