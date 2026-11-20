import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import '../session/online_controller.dart';
import '../session/session_controller.dart';
import '../shift/shift_controller.dart';
import 'cart_controller.dart';
import 'order_controller.dart';
import 'pos_widgets.dart';
import 'sync_controller.dart';

/// Lembar pembayaran. Mengembalikan [PaidOrder] bila transaksi tersimpan,
/// atau null bila kasir menutupnya.
class PaySheet extends ConsumerStatefulWidget {
  const PaySheet({super.key, required this.table});

  final DiningTableInfo? table;

  @override
  ConsumerState<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<PaySheet> {
  final _cash = TextEditingController();
  String _method = 'cash';
  String? _cashError;
  String? _saveError;
  bool _busy = false;

  int get _received => parseRupiah(_cash.text);

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  /// QRIS butuh internet: kalau koneksi putus, kembali ke tunai.
  String _effective(bool online) => (!online && _method == 'qris') ? 'cash' : _method;

  void _setCash(int v) {
    setState(() {
      _cash.text = groupDigits(v);
      _cashError = null;
    });
  }

  Future<void> _confirm() async {
    final online = ref.read(onlineProvider);
    final method = _effective(online);
    final cart = ref.read(cartProvider);
    final totals = ref.read(cartTotalsProvider);

    if (cart.isEmpty) return;

    if (method == 'cash' && _received < totals.total) {
      setState(() => _cashError = 'Uang tunai kurang');
      return;
    }

    final session = ref.read(sessionProvider).value;
    final shift = ref.read(shiftProvider).value;
    final cafe = session?.cafe;
    final user = session?.user;

    if (cafe == null || user == null || shift == null) {
      setState(() => _saveError = 'Shift belum dibuka.');
      return;
    }

    setState(() {
      _busy = true;
      _saveError = null;
    });

    try {
      final order = await ref.read(orderRepoProvider).savePaid(
            cafe: cafe,
            user: user,
            shift: shift,
            lines: cart.lines,
            type: cart.type,
            table: widget.table,
            customerName: cart.customerName,
            method: method,
            cashReceived: _received,
          );

      ref.read(ordersRevisionProvider.notifier).bump();
      ref.read(ordersRevisionProvider.notifier).bump();
      ref.read(syncProvider.notifier).run();

      if (!mounted) return;
      Navigator.pop(context, order);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveError = 'Transaksi gagal disimpan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final online = ref.watch(onlineProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final method = _effective(online);

    final where = orderWhere(
      cart.type,
      tableName: widget.table?.name,
      customerName: cart.customerName,
    );

    final breakdown = [
      'Subtotal ${rp(totals.subtotal)}',
      if (totals.service > 0) 'Layanan ${rp(totals.service)}',
      if (totals.tax > 0) 'Pajak ${rp(totals.tax)}',
      if (totals.rounding != 0)
        'Pembulatan ${totals.rounding > 0 ? '+' : '−'}${rp(totals.rounding.abs())}',
    ].join(' · ');

    return AppSheet(
      title: 'Pembayaran',
      onClose: _busy ? null : () => Navigator.pop(context),
      body: Column(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SubText('Total tagihan'),
              const SizedBox(height: 2),
              Text(
                rp(totals.total),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentText(context),
                ),
              ),
              const SizedBox(height: 4),
              SubText('$where · ${cart.count} item'),
              SubText(breakdown),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: _MethodButton(
                  icon: Icons.payments_outlined,
                  label: 'Tunai',
                  selected: method == 'cash',
                  onTap: () => setState(() => _method = 'cash'),
                ),
              ),
              Expanded(
                child: _MethodButton(
                  icon: Icons.qr_code_2,
                  label: 'QRIS',
                  sub: online ? null : 'butuh internet',
                  selected: method == 'qris',
                  onTap: online ? () => setState(() => _method = 'qris') : null,
                ),
              ),
              Expanded(
                child: _MethodButton(
                  icon: Icons.credit_card,
                  label: 'Debit',
                  selected: method == 'card',
                  onTap: () => setState(() => _method = 'card'),
                ),
              ),
            ],
          ),
          if (method == 'cash') _cashPanel(totals.total),
          if (method == 'qris')
            const _Hint(
              icon: Icons.qr_code_2,
              text: 'Tunjukkan kode QRIS cafe ke pelanggan, lalu ketuk selesaikan setelah pembayaran masuk.',
            ),
          if (method == 'card')
            const _Hint(
              icon: Icons.credit_card,
              text: 'Tempelkan atau gesek kartu di mesin EDC, lalu ketuk selesaikan setelah disetujui.',
            ),
          if (_saveError != null)
            Text(
              _saveError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
        ],
      ),
      footer: DarkButton(
        label: _busy ? 'Menyimpan...' : 'Selesaikan pembayaran',
        onPressed: _busy ? null : _confirm,
      ),
    );
  }

  Widget _cashPanel(int total) {
    final suggestions = ({
      total,
      for (final step in const [5000, 10000, 20000, 50000, 100000])
        (total / step).ceil() * step,
    }.toList()
          ..sort())
        .take(4);

    final diff = _received - total;
    final String changeText;
    Color? changeColor;

    if (_received == 0) {
      changeText = 'Rp 0';
    } else if (diff >= 0) {
      changeText = rp(diff);
      changeColor = const Color(0xFF15803D);
    } else {
      changeText = 'Uang kurang ${rp(-diff)}';
      changeColor = const Color(0xFFDC2626);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Uang diterima'),
        AppField(
          controller: _cash,
          hint: 'Masukkan nominal',
          digitsOnly: true,
          errorText: _cashError,
          onChanged: (_) => setState(() => _cashError = null),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final v in suggestions)
              QuickChip(label: v == total ? 'Uang pas' : rp(v), onTap: () => _setCash(v)),
          ],
        ),
        const SizedBox(height: 10),
        InfoBox(child: InfoRow('Kembalian', changeText, bold: true, color: changeColor)),
      ],
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final text = AppColors.accentText(context);
    final fg = selected ? text : AppColors.muted(context);

    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? text : AppColors.line(context), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Icon(icon, size: 20, color: fg),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        spacing: 8,
        children: [
          Icon(icon, size: 56, color: AppColors.muted(context)),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }
}
