import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'theme.dart';

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Garis pemisah lembut di dalam lembar (header dan footer).
Color softLine(BuildContext c) =>
    _isDark(c) ? const Color(0xFF2F343F) : const Color(0xFFF1F5F9);

/// Latar kolom isian dan kotak info.
Color fieldFill(BuildContext c) =>
    _isDark(c) ? const Color(0xFF0F1115) : const Color(0xFFF9FAFB);

/// Latar chip dan tombol abu-abu.
Color chipFill(BuildContext c) =>
    _isDark(c) ? const Color(0xFF2A2F3A) : const Color(0xFFF3F4F6);

/// Menampilkan lembar di tengah layar dengan latar gelap, seperti modal di mockup.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(14),
      child: builder(ctx),
    ),
  );
}

/// Kerangka lembar: header (judul dan tombol tutup), isi, dan footer.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.body,
    this.title,
    this.footer,
    this.onClose,
    this.maxWidth = 350,
  });

  final String? title;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final line = softLine(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (onClose != null)
                      InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: chipFill(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close, size: 18, color: AppColors.muted(context)),
                        ),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: body,
              ),
            ),
            if (footer != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: line)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Teks kecil abu-abu (deskripsi) seperti ".sub" di mockup.
class SubText extends StatelessWidget {
  const SubText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted(context)),
    );
  }
}

/// Label kolom isian seperti ".lbl" di mockup.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.muted(context),
        ),
      ),
    );
  }
}

/// Kolom isian abu muda dengan sudut membulat, seperti ".fld" di mockup.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.errorText,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: color, width: 1.5),
        );

    return TextField(
      controller: controller,
      keyboardType: digitsOnly ? TextInputType.number : null,
      inputFormatters: digitsOnly ? [RupiahInputFormatter()] : null,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: AppColors.muted(context)),
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        isDense: true,
        filled: true,
        fillColor: fieldFill(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border(AppColors.line(context)),
        enabledBorder: border(AppColors.line(context)),
        focusedBorder: border(AppColors.accentText(context)),
        errorBorder: border(const Color(0xFFDC2626)),
        focusedErrorBorder: border(const Color(0xFFDC2626)),
      ),
    );
  }
}

/// Chip pintas nominal, abu-abu tanpa garis tepi, seperti ".quick button" di mockup.
class QuickChip extends StatelessWidget {
  const QuickChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chipFill(context),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        // Tanpa `alignment` di Container: alignment membuat Container melebar
        // penuh di dalam Wrap. Row dengan mainAxisSize.min membuat lebar chip
        // mengikuti teks, sehingga tiga chip bisa berjajar dalam satu baris.
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol abu-abu (".btn.ghost" di mockup).
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: chipFill(context),
        foregroundColor:
            _isDark(context) ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
        elevation: 0,
      ),
      child: Text(label),
    );
  }
}

/// Tombol hitam (".btn.dark" di mockup).
class DarkButton extends StatelessWidget {
  const DarkButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xFFF3F4F6) : const Color(0xFF111111),
        foregroundColor: dark ? const Color(0xFF111111) : Colors.white,
        elevation: 0,
      ),
      child: Text(label),
    );
  }
}

/// Kotak abu muda berisi baris-baris info (".card" di mockup).
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fieldFill(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: child,
    );
  }
}

/// Satu baris label dan nilai (".lrow" di mockup).
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? null : AppColors.muted(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}