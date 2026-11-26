import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import 'escpos.dart';

/// Menyusun struk menjadi perintah ESC/POS untuk kertas 58 mm atau 80 mm.
class ReceiptPrinter {
  /// Jumlah karakter per baris: 32 untuk kertas 58 mm, 48 untuk 80 mm.
  static int charsPerLine(int paperMm) => paperMm >= 80 ? 48 : 32;

  static List<int> build(PaidOrder o, Cafe? cafe, {int paperMm = 58}) {
    final w = charsPerLine(paperMm);
    final t = o.totals;
    final rule = '-' * w;
    final p = EscPos()..init();

    // Nama cafe: huruf besar bila muat, kalau panjang cukup ditebalkan
    final name = (cafe?.name ?? 'Struk').trim();
    p.align(1).bold(true);
    if (name.length <= w ~/ 2) p.size(w: 2, h: 2);
    for (final line in _wrap(name, name.length <= w ~/ 2 ? w ~/ 2 : w)) {
      p.text(line);
    }
    p.size().bold(false);

    if (o.status == 'void') {
      p.bold(true).text('*** DIBATALKAN ***').bold(false);
    }

    p.align(0).text(rule);
    p.text(_lr('No', o.number, w));
    p.text(_lr('Waktu', DateFormat('dd/MM/yyyy HH:mm').format(o.orderedAt), w));
    p.text(_lr('Kasir', o.cashierName, w));
    for (final line in _wrap(o.where, w)) {
      p.text(line);
    }
    p.text(rule);

    for (final l in o.items) {
      final price = groupDigits(l.lineTotal);
      final head = _wrap('${l.qty}x ${l.name}', w);

      for (var i = 0; i < head.length; i++) {
        final last = i == head.length - 1;

        if (last && head[i].length + 1 + price.length <= w) {
          p.text(_lr(head[i], price, w));
        } else {
          p.text(head[i]);
          if (last) p.text(_lr('', price, w));
        }
      }

      if (l.optionsLabel.isNotEmpty) {
        for (final line in _wrap(l.optionsLabel, w - 3)) {
          p.text('   $line');
        }
      }
    }

    p.text(rule);
    p.text(_lr('Subtotal', groupDigits(t.subtotal), w));
    if (t.discount > 0) {
      p.text(_lr(o.discountName ?? 'Diskon', '-${groupDigits(t.discount)}', w));
    }
    if (t.service > 0) {
      p.text(_lr('Layanan ${fmtPercent(o.servicePercent)}%', groupDigits(t.service), w));
    }
    if (t.tax > 0) {
      p.text(_lr('Pajak ${fmtPercent(o.taxPercent)}%', groupDigits(t.tax), w));
    }
    if (t.rounding != 0) {
      p.text(_lr('Pembulatan', '${t.rounding > 0 ? '+' : '-'}${groupDigits(t.rounding.abs())}', w));
    }

    p.bold(true).size(h: 2);
    p.text(_lr('TOTAL', 'Rp ${groupDigits(t.total)}', w));
    p.size().bold(false);

    p.text(rule);
    p.text(_lr('Bayar', o.methodLabel, w));
    if (o.method == 'cash') {
      p.text(_lr('Tunai', groupDigits(o.cashReceived), w));
      p.text(_lr('Kembali', groupDigits(o.change), w));
    }

    p.text(rule).align(1);
    final footer = cafe?.receiptFooter?.trim() ?? '';
    for (final line in _wrap(footer.isEmpty ? 'Terima kasih' : footer, w)) {
      p.text(line);
    }

    p.align(0).feed(4).cut();

    return p.bytes;
  }

  /// Struk contoh untuk mengecek printer dan lebar kertas.
  static List<int> test({int paperMm = 58, String? printerName}) {
    final w = charsPerLine(paperMm);
    final p = EscPos()..init();

    p.align(1).bold(true).size(w: 2, h: 2).text('TES PRINTER').size().bold(false);
    p.align(0).text('-' * w);
    p.text(_lr('Kertas', '$paperMm mm', w));
    p.text(_lr('Karakter per baris', '$w', w));
    if (printerName != null) p.text(_lr('Printer', printerName, w));
    p.text('-' * w);
    p.text(('1234567890' * 5).substring(0, w));
    p.text(_lr('Kiri', 'Kanan', w));
    p.align(1).text('Jika tulisan ini rapi dan tidak');
    p.text('terpotong, printer siap dipakai.');
    p.align(0).feed(4).cut();

    return p.bytes;
  }

  /// Kiri dan kanan dalam satu baris selebar [w], dipisah spasi.
  static String _lr(String left, String right, int w) {
    if (left.length + right.length + 1 > w) {
      final room = w - right.length - 1;
      left = room > 0 ? left.substring(0, room) : '';
    }

    return left + ' ' * (w - left.length - right.length) + right;
  }

  /// Memecah teks panjang jadi beberapa baris tanpa memotong kata, kecuali
  /// kata yang memang lebih panjang dari satu baris.
  static List<String> _wrap(String text, int width) {
    final lines = <String>[];
    var current = '';

    for (final raw in text.split(' ')) {
      var word = raw;
      if (word.isEmpty) continue;

      while (word.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        lines.add(word.substring(0, width));
        word = word.substring(width);
      }

      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) lines.add(current);

    return lines.isEmpty ? [''] : lines;
  }
}
