import 'package:flutter/material.dart';

/// Replaceable light and dark Material 3 themes for the starter showcase.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF465667);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      surface:
          brightness == Brightness.light
              ? const Color(0xFFF7F8FA)
              : const Color(0xFF111418),
    );
    final textTheme = Typography.material2021().black.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            brightness == Brightness.light
                ? Colors.white
                : scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color:
            brightness == Brightness.light
                ? Colors.white
                : scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
