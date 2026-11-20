import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppColors {
  // Merah aksen yang dipakai di mockup kasir
  static const red = Color(0xFFDC2626);
  static const owner = Color(0xFFB45309);

  static const _bgLight = Color(0xFFF3F4F6);
  static const _bgDark = Color(0xFF0F1115);
  static const _cardDark = Color(0xFF1B1E25);
  static const _lineDark = Color(0xFF2F343F);
  static const _lineLight = Color(0xFFE5E7EB);
  static const _mutedLight = Color(0xFF6B7280);
  static const _mutedDark = Color(0xFF9CA3AF);

  static bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  static Color card(BuildContext c) => _dark(c) ? _cardDark : Colors.white;
  static Color line(BuildContext c) => _dark(c) ? _lineDark : _lineLight;
  static Color muted(BuildContext c) => _dark(c) ? _mutedDark : _mutedLight;

  /// Warna aksen untuk TEKS, ikon, dan garis (bukan latar tombol).
  /// Di mode terang sama dengan aksen cafe. Di mode gelap dicerahkan seperlunya,
  /// supaya aksen yang gelap (misalnya biru tua) tetap terbaca di atas kartu gelap.
  static Color accentText(BuildContext c) {
    final accent = Theme.of(c).colorScheme.primary;

    return _dark(c) ? readableOn(accent, _cardDark) : accent;
  }

  /// Mencerahkan [color] sampai kontrasnya terhadap [background] minimal 4.5:1.
  static Color readableOn(Color color, Color background) {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();

      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    var hsl = HSLColor.fromColor(color);
    var result = color;

    while (contrast(result, background) < 4.5 && hsl.lightness < 0.9) {
      hsl = hsl.withLightness(math.min(0.9, hsl.lightness + 0.04));
      result = hsl.toColor();
    }

    return result;
  }

  /// Mengubah teks warna seperti "#d7263d" menjadi Color, dengan cadangan bila tidak valid.
  static Color parse(String? hex, {Color fallback = red}) {
    if (hex == null) return fallback;
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }

  static ThemeData theme(Brightness b, Color accent) {
    final dark = b == Brightness.dark;

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const label = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700);
    const padding = EdgeInsets.symmetric(horizontal: 16);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: b)
          .copyWith(primary: accent, onPrimary: Colors.white),
      scaffoldBackgroundColor: dark ? _bgDark : _bgLight,
      // Tombol seperti mockup: tinggi 46, sudut 12, huruf tebal
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: padding,
          shape: shape,
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: padding,
          shape: shape,
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: shape,
          textStyle: label,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(fontSize: 14),
      ),
    );
  }
}