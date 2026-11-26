import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import '../printer/printer_controller.dart';
import '../printer/printer_sheet.dart';
import '../session/session_controller.dart';
import 'pos_widgets.dart';

/// Struk. [isNew] = tampil sesaat setelah pembayaran (ada tanda centang hijau),
/// selain itu dipakai untuk melihat detail dari riwayat.
Future<void> showReceiptSheet(
  BuildContext context,
  PaidOrder order, {
  bool isNew = false,
}) {
  return showAppSheet<void>(context, (_) => ReceiptSheet(order: order, isNew: isNew));
}

String formatDateTime(DateTime t) => DateFormat('dd/MM/yyyy HH:mm').format(t);

class ReceiptSheet extends ConsumerStatefulWidget {
  const ReceiptSheet({super.key, required this.order, required this.isNew});

  final PaidOrder order;
  final bool isNew;

  @override
  ConsumerState<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<ReceiptSheet> {
  bool _printing = false;
  PrintResult? _printResult;

  @override
  void initState() {
    super.initState();

    // Struk baru: cetak otomatis bila printer sudah dipilih dan fitur ini dinyalakan
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pr = ref.read(printerProvider);
        if (mounted && pr.auto && pr.hasPrinter) _print();
      });
    }
  }

  Future<void> _print() async {
    setState(() {
      _printing = true;
      _printResult = null;
    });

    final cafe = ref.read(sessionProvider).value?.cafe;
    final res = await ref.read(printerProvider.notifier).printReceipt(widget.order, cafe);

    if (!mounted) return;
    setState(() {
      _printing = false;
      _printResult = res;
    });
  }

  Future<void> _openSettings() async {
    await showPrinterSheet(context);
  }

  Future<void> _onPrintTap() async {
    // Belum ada printer: buka pengaturan dulu, lalu cetak bila sudah dipilih
    if (!ref.read(printerProvider).hasPrinter) {
      await _openSettings();
      if (!mounted || !ref.read(printerProvider).hasPrinter) return;
    }

    await _print();
  }

  @override
  Widget build(BuildContext context) {
    final cafe = ref.watch(sessionProvider.select((s) => s.value?.cafe));
    final res = _printResult;

    return AppSheet(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReceiptBody(order: widget.order, cafe: cafe, isNew: widget.isNew),
          if (_printing) ...[
            const SizedBox(height: 12),
            const NoteBox('Mencetak struk...'),
          ] else if (res != null) ...[
            const SizedBox(height: 12),
            NoteBox(res.message, amber: !res.ok),
            if (!res.ok)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _openSettings, child: const Text('Atur printer')),
              ),
          ],
        ],
      ),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: TintButton(
              label: _printing ? 'Mencetak...' : (widget.isNew ? 'Cetak struk' : 'Cetak ulang'),
              onPressed: _printing ? null : _onPrintTap,
            ),
          ),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isNew ? 'Selesai' : 'Tutup'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Isi struk. Dipakai di layar pembayaran berhasil dan detail riwayat.
class ReceiptBody extends StatelessWidget {
  const ReceiptBody({
    super.key,
    required this.order,
    required this.cafe,
    required this.isNew,
  });

  final PaidOrder order;
  final Cafe? cafe;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final t = order.totals;
    final isVoid = order.status == 'void';
    final footer = cafe?.receiptFooter?.trim() ?? '';
    const green = Color(0xFF15803D);

    final title = isNew
        ? 'Pembayaran berhasil'
        : (isVoid ? 'Transaksi dibatalkan' : 'Struk transaksi');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            if (isNew)
              Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCFCE7),
                ),
                child: const Icon(Icons.check, size: 24, color: green),
              ),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (cafe != null) ...[
              const SizedBox(height: 2),
              SubText(cafe!.name),
            ],
            const SizedBox(height: 2),
            SubText('${order.number} · ${formatDateTime(order.orderedAt)}'),
            SubText(order.where),
            SubText('Kasir: ${order.cashierName}'),
          ],
        ),
        const DashedDivider(),
        for (final l in order.items) _ItemRow(line: l),
        const DashedDivider(),
        _Rw('Subtotal', rp(t.subtotal)),
        if (t.discount > 0) _Rw(order.discountName ?? 'Diskon', '− ${rp(t.discount)}', color: green),
        if (t.service > 0) _Rw('Layanan ${fmtPercent(order.servicePercent)}%', rp(t.service)),
        if (t.tax > 0) _Rw('Pajak ${fmtPercent(order.taxPercent)}%', rp(t.tax)),
        if (t.rounding != 0)
          _Rw('Pembulatan', '${t.rounding > 0 ? '+' : '−'} ${rp(t.rounding.abs())}'),
        const SizedBox(height: 2),
        _Rw('Total', rp(t.total), bold: true, size: 14.5),
        _Rw('Metode', order.methodLabel),
        if (order.method == 'cash') ...[
          _Rw('Diterima', rp(order.cashReceived)),
          _Rw('Kembalian', rp(order.change)),
        ],
        if (footer.isNotEmpty) ...[
          const DashedDivider(),
          Center(child: SubText(footer)),
        ],
        if (isNew) ...[
          const DashedDivider(),
          const Center(child: SubText('Transaksi tersimpan di tablet')),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final opts = line.optionsLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${line.qty}× ${line.name}', style: const TextStyle(fontSize: 12.5)),
                if (opts.isNotEmpty) SubText(opts),
              ],
            ),
          ),
          Text(rp(line.lineTotal), style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Rw extends StatelessWidget {
  const _Rw(this.label, this.value, {this.bold = false, this.color, this.size = 12.5});

  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 10,
        children: [
          Flexible(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
