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