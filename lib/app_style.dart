import 'package:flutter/material.dart';

abstract final class AppStyle {
  static const ink = Color(0xFF392F37);
  static const muted = Color(0xFF665963);
  static const rose = Color(0xFF98435A);
  static const roseSoft = Color(0xFFF9E4E7);
  static const cream = Color(0xFFFFFAF5);
  static const peach = Color(0xFFF9E4D2);
  static const green = Color(0xFF345F50);
  static const greenSoft = Color(0xFFE4F1E8);

  static Color resolve(BuildContext context, Color color) {
    if (Theme.of(context).brightness != Brightness.dark) return color;
    if (color == ink) return const Color(0xFFF5E9EF);
    if (color == muted) return const Color(0xFFDDCBD3);
    if (color == rose) return const Color(0xFFFFB2C5);
    if (color == roseSoft) return const Color(0xFF51313C);
    if (color == cream) return const Color(0xFF1D171B);
    if (color == peach) return const Color(0xFF57382D);
    if (color == green) return const Color(0xFFAFDCC7);
    if (color == greenSoft) return const Color(0xFF29483B);
    if (color == Colors.white) return const Color(0xFF30262C);
    return color;
  }

  static ThemeData get darkTheme {
    const surface = Color(0xFF1D171B);
    final scheme = ColorScheme.fromSeed(
      seedColor: rose,
      brightness: Brightness.dark,
      surface: surface,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF30262C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(seedColor: rose, surface: cream);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rose,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppStyle.resolve(context, color),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppStyle.ink.withValues(alpha: .04),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}
