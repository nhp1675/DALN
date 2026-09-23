import 'package:flutter/material.dart';

class AppTheme {
  static const _do = Color(0xFFE31C25);

  static ThemeData get toi => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _do,
          brightness: Brightness.dark,
          primary: _do,
          surface: const Color(0xFF14161C),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1015),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF14161C),
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF191C24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF191C24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
