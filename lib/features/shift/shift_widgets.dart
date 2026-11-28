import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme_mode.dart';
import '../../core/widgets.dart';
import '../../data/shift_repository.dart';
import '../pos/pos_widgets.dart';
import '../printer/printer_controller.dart';
import '../printer/printer_sheet.dart';
import '../session/logout_flow.dart';
import '../session/session_controller.dart';
import 'shift_controller.dart';
import '../pos/sync_controller.dart';

const _methodLabels = {'cash': 'Tunai', 'qris': 'QRIS', 'card': 'Debit'};

// ---------------------------------------------------------------------------
// Kartu "Buka shift": menutupi layar sampai kas awal diisi
// ---------------------------------------------------------------------------
class ShiftOpenCard extends ConsumerStatefulWidget {
  const ShiftOpenCard({super.key, this.onOpened, this.onCancel});

  /// Dipanggil setelah shift berhasil dibuka (dipakai saat kartu tampil sebagai sheet).
  final VoidCallback? onOpened;

  /// Bila diisi, tombol kiri menjadi "Batal" (menggantikan "Ganti akun").
  final VoidCallback? onCancel;

  @override
  ConsumerState<ShiftOpenCard> createState() => _ShiftOpenCardState();
}

class _ShiftOpenCardState extends ConsumerState<ShiftOpenCard> {
  final _cash = TextEditingController();
  String? _error;
  bool _busy = false;

  int get _value => parseRupiah(_cash.text);

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_value <= 0) {
      setState(() => _error = 'Isi kas awal dulu');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(shiftProvider.notifier).open(_value);
      widget.onOpened?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _quick(int v) {
    setState(() {
      _cash.text = groupDigits(v);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value?.user;

    return AppSheet(
      title: 'Buka shift',
      body: Column(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubText(
            user == null
                ? 'Hitung uang di laci, lalu masukkan nominalnya.'
                : 'Akun: ${user.name} (${roleLabel(user.role)}). Hitung uang di laci, lalu masukkan nominalnya.',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Kas awal di laci'),
              AppField(
                controller: _cash,
                hint: 'Masukkan nominal',
                digitsOnly: true,
                errorText: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final v in const [200000, 300000, 500000])
                    QuickChip(label: rp(v), onTap: () => _quick(v)),
                ],
              ),
            ],
          ),
        ],
      ),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: SoftButton(
              label: widget.onCancel != null ? 'Batal' : 'Ganti akun',
              onPressed: _busy
                  ? null
                  : (widget.onCancel ?? () => confirmLogout(context, ref)),
            ),
          ),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : _start,
              child: const Text('Mulai shift'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info akun dan shift (dibuka dari avatar di header)
// ---------------------------------------------------------------------------
enum AccountAction { closeShift, switchUser }

Future<void> showAccountDialog(BuildContext context, WidgetRef ref) async {
  final action = await showAppSheet<AccountAction>(
    context,
    (_) => const _AccountSheet(),
  );

  if (!context.mounted) return;

  if (action == AccountAction.closeShift) {
    await showCloseShiftDialog(context, ref);
  } else if (action == AccountAction.switchUser) {
    await confirmLogout(context, ref);
  }
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;
    final shift = ref.watch(shiftProvider).value;

    if (user == null) return const SizedBox.shrink();

    return AppSheet(
      body: Column(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(name: user.name, owner: user.role == 'owner', size: 46),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  SubText(roleLabel(user.role)),
                ],
              ),
            ],
          ),
          _ShiftInfoCard(shift: shift),
          const _ThemePicker(),
          const _PrinterRow(),
          DarkButton(
            label: 'Tutup shift',
            onPressed: shift == null
                ? null
                : () => Navigator.pop(context, AccountAction.closeShift),
          ),
          SoftButton(
            label: 'Ganti pengguna',
            onPressed: () => Navigator.pop(context, AccountAction.switchUser),
          ),
          SoftButton(label: 'Tutup', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

/// Jalan pintas ke pengaturan printer struk.
class _PrinterRow extends ConsumerWidget {
  const _PrinterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pr = ref.watch(printerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Printer struk'),
        SizedBox(
          width: double.infinity,
          child: PickButton(
            label: pr.hasPrinter
                ? '${pr.name ?? pr.mac} · ${pr.paperMm} mm'
                : 'Belum dipilih · ketuk untuk mengatur',
            selected: false,
            onTap: () => showPrinterSheet(context),
          ),
        ),
      ],
    );
  }
}

/// Pilihan tema: otomatis (mengikuti HP), terang, atau gelap.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    Widget option(String label, ThemeMode mode) {
      return Expanded(
        child: PickButton(
          label: label,
          selected: current == mode,
          onTap: () => ref.read(themeModeProvider.notifier).set(mode),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Tema'),
        Row(
          spacing: 7,
          children: [
            option('Otomatis', ThemeMode.system),
            option('Terang', ThemeMode.light),
            option('Gelap', ThemeMode.dark),
          ],
        ),
      ],
    );
  }
}

class _ShiftInfoCard extends ConsumerStatefulWidget {
  const _ShiftInfoCard({required this.shift});

  final ShiftRecord? shift;

  @override
  ConsumerState<_ShiftInfoCard> createState() => _ShiftInfoCardState();
}

class _ShiftInfoCardState extends ConsumerState<_ShiftInfoCard> {
  Future<ShiftSummary>? _summary;

  @override
  void initState() {
    super.initState();
    final shift = widget.shift;
    if (shift != null) _summary = ref.read(shiftRepoProvider).summary(shift.id);
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shift;

    if (shift == null) {
      return const InfoBox(child: SubText('Belum ada shift berjalan'));
    }

    return InfoBox(
      child: FutureBuilder<ShiftSummary>(
        future: _summary,
        builder: (context, snap) {
          final sum = snap.data;

          return Column(
            children: [
              InfoRow(
                'Shift dibuka',
                '${DateFormat('HH:mm').format(shift.openedAt)} · ${shift.userName}',
              ),
              InfoRow('Kas awal', rp(shift.openingCash)),
              InfoRow('Penjualan tunai', rp(sum?.cashSales ?? 0)),
              InfoRow('Transaksi', '${sum?.count ?? 0}'),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tutup shift: hitung kas, tampilkan selisih, lalu keluar
// ---------------------------------------------------------------------------
Future<void> showCloseShiftDialog(BuildContext context, WidgetRef ref) async {
  final shift = ref.read(shiftProvider).value;
  if (shift == null) return;

  final summary = await ref.read(shiftRepoProvider).summary(shift.id);
  if (!context.mounted) return;

  final counted = await showAppSheet<int>(
    context,
    (_) => _CloseShiftSheet(shift: shift, summary: summary),
  );

  if (counted == null || !context.mounted) return;

  // Setelah ini akun keluar: beri peringatan bila offline dan tidak bisa masuk lagi
  if (!await confirmLeave(context, ref)) return;

  final diff = counted - (shift.openingCash + summary.cashSales);
  final notice = diff == 0
      ? 'Shift ditutup. Kas pas.'
      : 'Shift ditutup. Selisih kas ${diff > 0 ? 'lebih' : 'kurang'} ${rp(diff.abs())}.';

    await ref.read(shiftProvider.notifier).close(counted);

  // Kirim data tutup shift dan transaksi selagi token masih berlaku
  await ref
      .read(syncProvider.notifier)
      .run()
      .timeout(const Duration(seconds: 8), onTimeout: () {});

  await ref.read(sessionProvider.notifier).logout(notice: notice);
}

class _CloseShiftSheet extends StatefulWidget {
  const _CloseShiftSheet({required this.shift, required this.summary});

  final ShiftRecord shift;
  final ShiftSummary summary;

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  final _counted = TextEditingController();
  String? _error;

  int get _value => parseRupiah(_counted.text);
  int get _expected => widget.shift.openingCash + widget.summary.cashSales;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  void _submit() {
    if (_value <= 0) {
      setState(() => _error = 'Isi uang di laci dulu');
      return;
    }

    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    final diff = _value - _expected;
    final diffText = _value == 0
        ? 'Rp 0'
        : diff == 0
            ? 'Pas'
            : '${diff > 0 ? 'Lebih' : 'Kurang'} ${rp(diff.abs())}';
    final diffColor = _value == 0
        ? null
        : diff == 0
            ? const Color(0xFF15803D)
            : const Color(0xFFDC2626);

    return AppSheet(
      title: 'Tutup shift',
      onClose: () => Navigator.pop(context),
      body: Column(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(
            child: Column(
              children: [
                InfoRow('Kas awal', rp(widget.shift.openingCash)),
                InfoRow('Penjualan tunai', rp(widget.summary.cashSales)),
                const Divider(height: 14),
                InfoRow('Kas seharusnya di laci', rp(_expected), bold: true),
              ],
            ),
          ),
          InfoBox(
            child: Column(
              children: [
                InfoRow('Transaksi', '${widget.summary.count}'),
                for (final e in _methodLabels.entries)
                  InfoRow(e.value, rp(widget.summary.byMethod[e.key] ?? 0)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Uang yang dihitung di laci'),
              AppField(
                controller: _counted,
                hint: 'Masukkan nominal',
                digitsOnly: true,
                errorText: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 10),
              InfoBox(
                child: InfoRow('Selisih', diffText, bold: true, color: diffColor),
              ),
            ],
          ),
        ],
      ),
      footer: DarkButton(
        label: 'Tutup shift dan keluar',
        onPressed: _submit,
      ),
    );
  }
}