import 'dart:convert';

/// Penyusun perintah ESC/POS, bahasa cetak standar hampir semua printer struk termal
/// (58 mm dan 80 mm, Bluetooth maupun kabel).
class EscPos {
  final List<int> _bytes = [];

  List<int> get bytes => List.unmodifiable(_bytes);

  /// Reset printer ke pengaturan awal. Selalu dipanggil di awal struk.
  EscPos init() {
    _bytes.addAll([0x1B, 0x40]);
    return this;
  }

  /// 0 = kiri, 1 = tengah, 2 = kanan
  EscPos align(int a) {
    _bytes.addAll([0x1B, 0x61, a]);
    return this;
  }

  EscPos bold(bool on) {
    _bytes.addAll([0x1B, 0x45, on ? 1 : 0]);
    return this;
  }

  /// Pembesar huruf: [w] lebar dan [h] tinggi, masing-masing 1 sampai 2.
  /// Huruf lebih tinggi tidak mengubah jumlah karakter per baris.
  EscPos size({int w = 1, int h = 1}) {
    _bytes.add(0x1D);
    _bytes.add(0x21);
    _bytes.add(((w - 1) << 4) | (h - 1));
    return this;
  }

  /// Satu baris teks. Karakter di luar ASCII disederhanakan lewat [toAscii].
  EscPos text(String s) {
    _bytes.addAll(ascii.encode(toAscii(s)));
    _bytes.add(0x0A);
    return this;
  }

  EscPos feed(int lines) {
    _bytes.addAll([0x1B, 0x64, lines]);
    return this;
  }

  /// Potong kertas (diabaikan printer yang tidak punya pemotong).
  EscPos cut() {
    _bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    return this;
  }

  /// Printer struk umumnya hanya mengerti ASCII. Tanda baca khusus diganti padanannya,
  /// huruf beraksen jadi huruf biasa, dan simbol lain (misalnya emoji) dibuang.
  static String toAscii(String s) {
    const map = {
      '×': 'x',
      '−': '-',
      '–': '-',
      '—': '-',
      '·': '-',
      '•': '*',
      '“': '"',
      '”': '"',
      '‘': "'",
      '’': "'",
      '…': '...',
      '\u00A0': ' ',
    };
    const accents = {
      'àáâãäå': 'a',
      'èéêë': 'e',
      'ìíîï': 'i',
      'òóôõö': 'o',
      'ùúûü': 'u',
      'ç': 'c',
      'ñ': 'n',
      'ÀÁÂÃÄÅ': 'A',
      'ÈÉÊË': 'E',
      'ÌÍÎÏ': 'I',
      'ÒÓÔÕÖ': 'O',
      'ÙÚÛÜ': 'U',
      'Ç': 'C',
      'Ñ': 'N',
    };

    final out = StringBuffer();

    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);

      if (rune >= 32 && rune < 127) {
        out.write(ch);
      } else if (map.containsKey(ch)) {
        out.write(map[ch]);
      } else {
        final hit = accents.entries.where((e) => e.key.contains(ch)).firstOrNull;
        if (hit != null) out.write(hit.value);
      }
    }

    return out.toString();
  }
}
