  import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/order_models.dart';
import '../pos/order_controller.dart';
import '../pos/pos_widgets.dart';
import '../pos/receipt_sheet.dart';
import '../shift/shift_controller.dart';

/// Riwayat transaksi yang tersimpan di tablet ini.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _onlyShift = true;

  @override
  Widget build(BuildContext context) {
    final shift = ref.watch(shiftProvider).value;
    final history = ref.watch(historyProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const Text('Riwayat gagal dimuat.'),
              OutlinedButton(
                onPressed: () => ref.invalidate(historyProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final list = (_onlyShift && shift != null)
            ? all.where((o) => o.shiftId == shift.id).toList()
            : all;

        final paid = list.where((o) => o.status == 'paid');
        final sum = paid.fold<int>(0, (s, o) => s + o.totals.total);

        return LayoutBuilder(
          builder: (context, c) {
            final twoCols = c.maxWidth >= 700;
            const pad = 12.0;
            const gap = 10.0;
            final cardWidth = twoCols ? (c.maxWidth - pad * 2 - gap) / 2 : c.maxWidth - pad * 2;

            return ListView(
              padding: const EdgeInsets.all(pad),
              children: [
                Row(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Shift ini',
                      selected: _onlyShift,
                      accent: accent,
                      onTap: () => setState(() => _onlyShift = true),
                    ),
                    _FilterChip(
                      label: 'Semua',
                      selected: !_onlyShift,
                      accent: accent,
                      onTap: () => setState(() => _onlyShift = false),
                    ),
                    const Spacer(),
                    Text(
                      '${paid.length} transaksi · ${rp(sum)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const NoteBox('Ketuk transaksi untuk melihat detail dan mencetak ulang struk.'),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Belum ada transaksi',
                        style: TextStyle(color: AppColors.muted(context)),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final o in list)
                        SizedBox(width: cardWidth, child: _HistoryCard(order: o)),
                    ],
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: accent,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : null,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order});

  final PaidOrder order;

  String _time() {
    final t = order.orderedAt;
    final now = DateTime.now();
    final today = t.year == now.year && t.month == now.month && t.day == now.day;

    return DateFormat(today ? 'HH:mm' : 'dd/MM HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final first = order.items.isEmpty ? null : order.items.first;
    final more = order.items.length > 1 ? ' +${order.items.length - 1} lainnya' : '';
    final isVoid = order.status == 'void';

    return Opacity(
      opacity: isVoid ? 0.62 : 1,
      child: Material(
        color: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.line(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showReceiptSheet(context, order),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.number,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (isVoid) const Pill('Dibatalkan', tone: PillTone.red),
                        if (!order.synced) const Pill('Belum sinkron', tone: PillTone.amber),
                        Pill(order.methodLabel),
                      ],
                    ),
                  ],
                ),
                if (first != null)
                  Text(
                    '${first.qty}× ${first.name}$more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        '${_time()} · ${order.where}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ),
                    Text(
                      rp(order.totals.total),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        decoration: isVoid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
