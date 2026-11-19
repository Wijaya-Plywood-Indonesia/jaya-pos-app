import 'package:flutter/material.dart';

import '../../core/sheet.dart';
import '../../core/theme.dart';

bool isDarkMode(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Pemberitahuan singkat di bawah layar (seperti ".toast" di mockup).
/// Catatan: tidak terlihat jelas bila ada dialog terbuka, jadi untuk kesalahan
/// di dalam dialog pakai teks error di dalam dialog itu sendiri.
void showToast(BuildContext context, String message, {bool warn = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: warn ? const Color(0xFF92400E) : const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

/// Tombol pilihan (".opt" di mockup): putih berborder, terpilih = warna aksen.
class PickButton extends StatelessWidget {
  const PickButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(11),
      side: BorderSide(
        color: selected ? accent : AppColors.line(context),
        width: 1.5,
      ),
    );

    return Material(
      color: selected ? accent : AppColors.card(context),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : null,
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white70 : AppColors.muted(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol − jumlah + (".qty" di mockup).
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 34,
    this.min = 0,
    this.max = 99,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final big = size >= 40;
    final btnColor = isDarkMode(context) ? const Color(0xFF3A404C) : Colors.white;

    Widget btn(IconData icon, bool enabled, VoidCallback onTap, String label) {
      return Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: btnColor,
            elevation: 1,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: enabled ? onTap : null,
              child: SizedBox(width: size, height: size, child: Icon(icon, size: 18)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: chipFill(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          btn(Icons.remove, value > min, () => onChanged(value - 1), 'Kurangi'),
          SizedBox(
            width: big ? 26 : 20,
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(fontSize: big ? 16 : 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          btn(Icons.add, value < max, () => onChanged(value + 1), 'Tambah'),
        ],
      ),
    );
  }
}

/// Tombol ikon persegi 40x40 (".iconbtn" di mockup).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: chipFill(context),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: AppColors.muted(context)),
          ),
        ),
      ),
    );
  }
}

/// Tombol dengan latar merah muda (".btn.soft" di mockup).
class TintButton extends StatelessWidget {
  const TintButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.08),
        foregroundColor: accent,
        elevation: 0,
        side: BorderSide(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(label),
    );
  }
}

enum PillTone { gray, amber, green, red }

/// Label kecil membulat (".badge" di mockup).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = PillTone.gray});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    final (Color bg, Color fg) = switch (tone) {
      PillTone.gray => (
          chipFill(context),
          dark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
        ),
      PillTone.amber => (
          dark ? const Color(0xFF3A2F10) : const Color(0xFFFEF3C7),
          dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
        ),
      PillTone.green => (
          dark ? const Color(0xFF12301F) : const Color(0xFFDCFCE7),
          dark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
        ),
      PillTone.red => (
          dark ? const Color(0xFF3B1414) : const Color(0xFFFEE2E2),
          dark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Kotak informasi berwarna biru atau kuning (".note-box" di mockup).
class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.amber = false});

  final String text;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    final (Color bg, Color border, Color fg) = amber
        ? (
            dark ? const Color(0xFF2A2110) : const Color(0xFFFFFBEB),
            dark ? const Color(0xFF5C4A14) : const Color(0xFFFDE68A),
            dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
          )
        : (
            dark ? const Color(0xFF14203A) : const Color(0xFFEFF6FF),
            dark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
            dark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(amber ? Icons.warning_amber_rounded : Icons.info_outline, size: 18, color: fg),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.45, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Kolom catatan dua baris (".note" di mockup).
class NoteField extends StatelessWidget {
  const NoteField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: color, width: 1.5),
        );

    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: AppColors.muted(context)),
        isDense: true,
        filled: true,
        fillColor: fieldFill(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: border(AppColors.line(context)),
        enabledBorder: border(AppColors.line(context)),
        focusedBorder: border(Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Garis putus-putus pemisah di total dan struk.
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.margin = const EdgeInsets.symmetric(vertical: 10)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final color = isDarkMode(context) ? const Color(0xFF3A404C) : const Color(0xFFD1D5DB);

    return Padding(
      padding: margin,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth.isFinite ? c.maxWidth : 200.0;
          final n = (width / 6).floor();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(width: 3, height: 1, child: ColoredBox(color: color)),
            ],
          );
        },
      ),
    );
  }
}
