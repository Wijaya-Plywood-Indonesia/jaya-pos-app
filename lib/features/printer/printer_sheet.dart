import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../pos/pos_widgets.dart';
import 'printer_controller.dart';

/// Pengaturan printer struk: pilih printer, lebar kertas, cetak otomatis, dan cetak tes.
Future<void> showPrinterSheet(BuildContext context) {
  return showAppSheet<void>(context, (_) => const PrinterSheet());
}

class PrinterSheet extends ConsumerStatefulWidget {
  const PrinterSheet({super.key});

  @override
  ConsumerState<PrinterSheet> createState() => _PrinterSheetState();
}

class _PrinterSheetState extends ConsumerState<PrinterSheet> {
  List<PrinterDevice>? _devices;
  bool _loading = false;
  String? _error;
  PrintResult? _result;

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ref.read(printerProvider.notifier).pairedDevices();

      if (!mounted) return;
      setState(() {
        _devices = list;
        _loading = false;
      });
    } on PrinterException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Daftar printer gagal dimuat. Periksa Bluetooth, lalu coba lagi.';
      });
    }
  }

  Future<void> _test() async {
    setState(() => _result = null);

    final res = await ref.read(printerProvider.notifier).printTest();

    if (!mounted) return;
    setState(() => _result = res);
  }

  @override
  Widget build(BuildContext context) {
    final pr = ref.watch(printerProvider);
    final notifier = ref.read(printerProvider.notifier);

    return AppSheet(
      title: 'Printer struk',
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          InfoBox(
            child: InfoRow(
              'Printer',
              pr.hasPrinter ? (pr.name ?? pr.mac!) : 'Belum dipilih',
              bold: true,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Lebar kertas'),
              Row(
                spacing: 7,
                children: [
                  Expanded(
                    child: PickButton(
                      label: '58 mm',
                      sub: '32 karakter',
                      selected: pr.paperMm == 58,
                      onTap: () => notifier.setPaper(58),
                    ),
                  ),
                  Expanded(
                    child: PickButton(
                      label: '80 mm',
                      sub: '48 karakter',
                      selected: pr.paperMm == 80,
                      onTap: () => notifier.setPaper(80),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            spacing: 10,
            children: [
              const Expanded(
                child: Text(
                  'Cetak otomatis setelah bayar',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(value: pr.auto, onChanged: notifier.setAuto),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              const FieldLabel('Pilih printer'),
              TintButton(
                label: _loading ? 'Mencari...' : 'Cari printer yang sudah dipasangkan',
                onPressed: _loading ? null : _scan,
              ),
              if (_error != null) NoteBox(_error!, amber: true),
              if (_devices != null && _devices!.isEmpty)
                const NoteBox(
                  'Belum ada printer yang dipasangkan. Nyalakan printer, buka Pengaturan Bluetooth di perangkat ini, pasangkan printer (PIN biasanya 0000 atau 1234), lalu kembali ke sini dan cari lagi.',
                ),
              if (_devices != null)
                for (final d in _devices!)
                  PickButton(
                    label: d.name,
                    sub: d.mac,
                    selected: pr.mac == d.mac,
                    onTap: () async {
                      await notifier.select(d);
                      if (mounted) setState(() => _result = null);
                    },
                  ),
            ],
          ),
          if (_result != null) NoteBox(_result!.message, amber: !_result!.ok),
          if (pr.hasPrinter)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await notifier.forget();
                  if (mounted) setState(() => _result = null);
                },
                child: Text(
                  'Lupakan printer ini',
                  style: TextStyle(color: AppColors.muted(context)),
                ),
              ),
            ),
        ],
      ),
      footer: DarkButton(
        label: pr.busy ? 'Mencetak...' : 'Cetak tes',
        onPressed: (!pr.hasPrinter || pr.busy) ? null : _test,
      ),
    );
  }
}
