import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import '../session/session_controller.dart';
import 'bills_controller.dart';
import 'bills_sheet.dart';
import 'cart_controller.dart';
import 'pos_widgets.dart';

/// Panel "Pesanan aktif". Di tablet menempel di kanan katalog,
/// di HP dibuka dari bawah lewat tombol "Lihat pesanan".
class CartPanel extends ConsumerWidget {
  const CartPanel({
    super.key,
    required this.tables,
    required this.onPay,
    this.onClose,
  });

  final List<DiningTableInfo> tables;
  final VoidCallback onPay;

  /// Hanya diisi di HP (tombol turun di pojok kiri atas).
  final VoidCallback? onClose;

  /// Simpan pesanan aktif sebagai bill, lalu kosongkan keranjang.
  Future<void> _saveBill(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    DiningTableInfo? table,
  ) async {
    await ref.read(billsProvider.notifier).save(cart: cart, table: table);
    ref.read(cartProvider.notifier).clear();

    if (context.mounted) {
      showToast(context, 'Bill disimpan. Buka lagi lewat ikon penanda.');
    }

    onClose?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final cafe = ref.watch(sessionProvider.select((s) => s.value?.cafe));
    final accent = Theme.of(context).colorScheme.primary;
    final line = softLine(context);

    final table = tables.where((t) => t.id == cart.tableId).firstOrNull;
    final where = orderWhere(
      cart.type,
      tableName: table?.name,
      customerName: cart.customerName,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: onClose == null
            ? Border(left: BorderSide(color: AppColors.line(context)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              spacing: 8,
              children: [
                if (onClose != null)
                  SquareIconButton(
                    icon: Icons.keyboard_arrow_down,
                    label: 'Tutup pesanan',
                    onTap: onClose,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pesanan aktif',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        where,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                _BillsButton(
                  onTap: () async {
                    final opened = await showBillsSheet(context);
                    if (opened == true && context.mounted) showToast(context, 'Bill dibuka');
                  },
                ),
                SquareIconButton(
                  icon: Icons.delete_outline,
                  label: 'Kosongkan pesanan',
                  onTap: cart.isEmpty
                      ? null
                      : () {
                          ref.read(cartProvider.notifier).clear();
                          showToast(context, 'Pesanan dikosongkan');
                        },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: line),
          _CartControls(tables: tables),
          Divider(height: 1, color: line),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 40,
                          color: AppColors.line(context),
                        ),
                        Text(
                          'Belum ada pesanan',
                          style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: cart.lines.length,
                    itemBuilder: (_, i) => _LineRow(line: cart.lines[i]),
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: fieldFill(context),
              border: Border(top: BorderSide(color: AppColors.line(context))),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SumRow('Subtotal', rp(totals.subtotal)),
                    if (totals.discount > 0)
                      _SumRow('Diskon', '− ${rp(totals.discount)}', color: const Color(0xFF15803D)),
                    if (totals.service > 0 && cafe != null)
                      _SumRow('Layanan ${fmtPercent(cafe.servicePercent)}%', rp(totals.service)),
                    if (totals.tax > 0 && cafe != null)
                      _SumRow('Pajak ${fmtPercent(cafe.taxPercent)}%', rp(totals.tax)),
                    if (totals.rounding != 0)
                      _SumRow(
                        'Pembulatan',
                        '${totals.rounding > 0 ? '+' : '−'} ${rp(totals.rounding.abs())}',
                      ),
                    const DashedDivider(margin: EdgeInsets.only(top: 3, bottom: 7)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          rp(totals.total),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: TintButton(
                            label: 'Simpan bill',
                            onPressed: cart.isEmpty
                                ? null
                                : () => _saveBill(context, ref, cart, table),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: cart.isEmpty ? null : onPay,
                            child: Text(
                              cart.isEmpty ? 'Bayar' : 'Bayar · ${rp(totals.total)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.muted(context);
    final weight = color == null ? FontWeight.w500 : FontWeight.w600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 8,
        children: [
          Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: c, fontWeight: weight))),
          Text(value, style: TextStyle(fontSize: 13, color: c, fontWeight: weight)),
        ],
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final opts = line.optionsLabel;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: softLine(context))),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(fontSize: 13.5, height: 1.25, fontWeight: FontWeight.w700),
                ),
                if (opts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SubText(opts),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    rp(line.lineTotal),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                  ),
                ),
              ],
            ),
          ),
          QtyStepper(
            value: line.qty,
            onChanged: (v) => ref.read(cartProvider.notifier).setQty(line.key, v),
          ),
        ],
      ),
    );
  }
}

/// Dine In / Take Away, lalu pilih meja atau isi nama pelanggan.
class _CartControls extends ConsumerStatefulWidget {
  const _CartControls({required this.tables});

  final List<DiningTableInfo> tables;

  @override
  ConsumerState<_CartControls> createState() => _CartControlsState();
}

class _CartControlsState extends ConsumerState<_CartControls> {
  late final TextEditingController _name =
      TextEditingController(text: ref.read(cartProvider).customerName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final dineIn = cart.type == OrderType.dineIn;

    // Pesanan dikosongkan atau selesai dibayar: kosongkan juga kolom nama
    ref.listen(cartProvider.select((c) => c.customerName), (_, next) {
      if (_name.text != next) _name.text = next;
    });

    final validTable = widget.tables.any((t) => t.id == cart.tableId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: _Toggle(
              label: OrderType.dineIn.label,
              on: dineIn,
              onTap: () => notifier.setType(OrderType.dineIn),
            ),
          ),
          Expanded(
            child: _Toggle(
              label: OrderType.takeAway.label,
              on: !dineIn,
              onTap: () => notifier.setType(OrderType.takeAway),
            ),
          ),
          if (dineIn && widget.tables.isNotEmpty)
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: validTable ? cart.tableId : null,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more, size: 18),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    items: [
                      // Meja bersifat opsional: tidak semua cafe memakai nomor meja
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tanpa meja', overflow: TextOverflow.ellipsis),
                      ),
                      for (final t in widget.tables)
                        DropdownMenuItem<int?>(
                          value: t.id,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: notifier.setTable,
                  ),
                ),
              ),
            ),
          if (!dineIn)
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _name,
                  onChanged: notifier.setName,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Atas nama',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.muted(context)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.line(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.line(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final onBg = dark ? const Color(0xFFF3F4F6) : const Color(0xFF111111);
    final onFg = dark ? const Color(0xFF111111) : Colors.white;

    return Material(
      color: on ? onBg : chipFill(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? onFg : AppColors.muted(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikon penanda bill tersimpan, dengan angka jumlahnya.
class _BillsButton extends ConsumerWidget {
  const _BillsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(billCountProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SquareIconButton(
          icon: count > 0 ? Icons.bookmark : Icons.bookmark_border,
          label: 'Bill tersimpan',
          onTap: onTap,
        ),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.card(context), width: 2),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
