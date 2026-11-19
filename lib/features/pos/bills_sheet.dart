import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/bill_repository.dart';
import 'bills_controller.dart';
import 'cart_controller.dart';
import 'pos_widgets.dart';

/// Daftar bill tersimpan. Mengembalikan true bila sebuah bill dibuka ke keranjang.
Future<bool?> showBillsSheet(BuildContext context) {
  return showAppSheet<bool>(context, (_) => const BillsSheet());
}

class BillsSheet extends ConsumerWidget {
  const BillsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider);

    return AppSheet(
      title: 'Bill tersimpan',
      onClose: () => Navigator.pop(context),
      body: bills.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Bill gagal dimuat.')),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(Icons.bookmark_border, size: 40, color: AppColors.line(context)),
                  Text(
                    'Belum ada bill tersimpan',
                    style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final b in list) _BillRow(bill: b)],
          );
        },
      ),
    );
  }
}

class _BillRow extends ConsumerWidget {
  const _BillRow({required this.bill});

  final SavedBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('HH:mm').format(bill.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: softLine(context))),
      ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                SubText('${bill.itemCount} item · ${rp(bill.subtotal)} · $time'),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () async {
              // Digabung ke pesanan aktif, lalu bill-nya dihapus dari daftar
              ref.read(cartProvider.notifier).restore(bill);
              await ref.read(billsProvider.notifier).remove(bill.id);

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Buka'),
          ),
          SquareIconButton(
            icon: Icons.delete_outline,
            label: 'Hapus bill',
            onTap: () => ref.read(billsProvider.notifier).remove(bill.id),
          ),
        ],
      ),
    );
  }
}
