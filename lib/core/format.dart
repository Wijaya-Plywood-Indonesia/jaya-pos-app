import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String rp(num n) => 'Rp ${NumberFormat.decimalPattern('id_ID').format(n)}';

String roleLabel(String? role) {
  switch (role) {
    case 'owner':
      return 'Owner';
    case 'manager':
      return 'Manajer';
    case 'cashier':
      return 'Kasir';
    default:
      return role ?? '-';
  }
}

String initialOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return String.fromCharCode(t.runes.first).toUpperCase();
}

/// 260000 -> "260.000"
String groupDigits(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// "260.000" -> 260000. Karakter selain angka diabaikan.
int parseRupiah(String text) => int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

/// Kolom nominal: hanya angka, otomatis diberi titik ribuan saat mengetik.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();

    if (digits.length > 12) digits = digits.substring(0, 12);
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final text = groupDigits(int.parse(digits));

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Jumlah bahan: 2400 -> "2.400", 12.5 -> "12,5".
String fmtQty(double n) => NumberFormat('#,##0.#', 'id_ID').format(n);
