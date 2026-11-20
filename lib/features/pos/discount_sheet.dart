import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import '../session/session_controller.dart';
import 'approver_sheet.dart';
import 'cart_controller.dart';
import 'pos_widgets.dart';

/// Pilih diskon untuk pesanan aktif. Mengembalikan true bila sebuah diskon dipasang.
Future<bool?> showDiscountSheet(
  BuildContext context, {
  required List<DiscountInfo> discounts,
}) {
  return showAppSheet<bool>(context, (_) => DiscountSheet(discounts: discounts));
}

class DiscountSheet extends ConsumerStatefulWidget {
  const DiscountSheet({super.key, required this.discounts});

  final List<DiscountInfo> discounts;

  @override
  ConsumerState<DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends ConsumerState<DiscountSheet> {
  final _voucher = TextEditingController();
  final _manual = TextEditingController();
  String _manualType = 'percent';
  String? _voucherError;
  String? _manualError;

  @override
  void dispose() {
    _voucher.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _apply(AppliedDiscount? d) {
    ref.read(cartProvider.notifier).setDiscount(d);
    Navigator.pop(context, d != null);
  }

  void _applyVoucher() {
    final code = _voucher.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _voucherError = 'Ketik kode voucher');
      return;
    }

    final found = widget.discounts
        .where((d) => d.isVoucher && d.code!.toUpperCase() == code)
        .firstOrNull;

    if (found == null) {
      setState(() => _voucherError = 'Kode voucher tidak dikenal');
      return;
    }

    if (!found.activeAt(DateTime.now())) {
      setState(() => _voucherError = 'Voucher ini sudah tidak berlaku');
      return;
    }

    _apply(AppliedDiscount.fromInfo(found));
  }

  Future<void> _applyManual() async {
    final value = parseRupiah(_manual.text);
    final subtotal = ref.read(cartProvider).lines.fold<int>(0, (s, l) => s + l.lineTotal);

    if (value <= 0) {
      setState(() => _manualError = 'Isi nilai diskon');
      return;
    }

    if (_manualType == 'percent' && value > 50) {
      setState(() => _manualError = 'Maksimal 50%');
      return;
    }

    if (_manualType == 'amount' && value > subtotal) {
      setState(() => _manualError = 'Melebihi total belanja');
      return;
    }

    final user = ref.read(sessionProvider).value?.user;
    if (user == null) return;

    // Owner dan manajer boleh langsung. Kasir butuh PIN owner.
    int approverId;
    if (user.role == 'owner' || user.role == 'manager') {
      approverId = user.id;
    } else {
      final approver = await showApproverSheet(context, reason: 'Diskon manual');
      if (approver == null) return;
      approverId = approver.id;
    }

    if (!mounted) return;

    _apply(AppliedDiscount.manual(type: _manualType, value: value, approvedBy: approverId));
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(cartProvider.select((c) => c.discount));
    final role = ref.watch(sessionProvider.select((s) => s.value?.user?.role));
    final canApproveDirect = role == 'owner' || role == 'manager';
    final now = DateTime.now();

    final promos = widget.discounts.where((d) => !d.isVoucher && d.activeAt(now)).toList();

    return AppSheet(
      title: 'Diskon dan promo',
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 7,
            children: [
              _PickRow(
                label: 'Tanpa diskon',
                selected: current == null,
                onTap: () => _apply(null),
              ),
              for (final p in promos)
                _PickRow(
                  label: p.name,
                  trailing: [
                    p.type == 'percent' ? '${p.value}%' : rp(p.value),
                    if (p.minPurchase > 0) 'min. ${rp(p.minPurchase)}',
                  ].join(' · '),
                  selected: current?.discountId == p.id,
                  onTap: () => _apply(AppliedDiscount.fromInfo(p)),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Kode voucher'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Expanded(
                    child: AppField(
                      controller: _voucher,
                      hint: 'Ketik kode',
                      capitalization: TextCapitalization.characters,
                      errorText: _voucherError,
                      onChanged: (_) {
                        if (_voucherError != null) setState(() => _voucherError = null);
                      },
                      onSubmitted: (_) => _applyVoucher(),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _applyVoucher,
                    child: const Text('Pakai'),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(
                canApproveDirect
                    ? 'Diskon manual · tidak perlu PIN owner'
                    : 'Diskon manual · butuh PIN owner',
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SizedBox(
                    width: 52,
                    child: PickButton(
                      label: '%',
                      selected: _manualType == 'percent',
                      onTap: () => setState(() => _manualType = 'percent'),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: PickButton(
                      label: 'Rp',
                      selected: _manualType == 'amount',
                      onTap: () => setState(() => _manualType = 'amount'),
                    ),
                  ),
                  Expanded(
                    child: AppField(
                      controller: _manual,
                      hint: 'Nilai',
                      digitsOnly: true,
                      errorText: _manualError,
                      onChanged: (_) {
                        if (_manualError != null) setState(() => _manualError = null);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TintButton(label: 'Terapkan diskon manual', onPressed: _applyManual),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris pilihan selebar lembar: nama di kiri, nilai di kanan.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected ? accent : AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: selected ? accent : AppColors.line(context), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : null,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 11.5,
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
