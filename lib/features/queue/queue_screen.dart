import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sheet.dart';
import '../../core/theme.dart';
import '../../data/order_models.dart';
import '../pos/pos_widgets.dart';
import 'queue_controller.dart';

/// Pesanan yang sudah dibayar dan menunggu dibuat atau diserahkan.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  static const _cols = [('new', 'Baru'), ('ready', 'Siap diambil')];

  Timer? _tick;
  String _tab = 'new';

  @override
  void initState() {
    super.initState();

    // Perbarui "N mnt" dan penanda terlambat
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return queue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Text('Antrian gagal dimuat.'),
            OutlinedButton(
              onPressed: () => ref.invalidate(queueProvider),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
      data: (list) {
        List<PaidOrder> of(String status) =>
            list.where((o) => o.kitchenStatus == status).toList();

        return LayoutBuilder(
          builder: (context, c) {
            // Tablet: dua kolom berdampingan. HP: satu kolom, ganti lewat tombol di atas.
            if (c.maxWidth >= 600) {
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    for (final (key, label) in _cols)
                      Expanded(child: _Column(title: label, orders: of(key), showHeader: true)),
                  ],
                ),
              );
            }

            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final (key, label) in _cols)
                        ChoiceChip(
                          label: Text('$label (${of(key).length})'),
                          selected: _tab == key,
                          showCheckmark: false,
                          selectedColor: accent,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _tab == key ? Colors.white : null,
                          ),
                          onSelected: (_) => setState(() => _tab = key),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _Column(
                      title: '',
                      orders: of(_tab),
                      showHeader: false,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.title, required this.orders, required this.showHeader});

  final String title;
  final List<PaidOrder> orders;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Pill('${orders.length}'),
              ],
            ),
          ),
        Expanded(
          child: orders.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Tidak ada pesanan',
                      style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _QueueCard(order: orders[i]),
                ),
        ),
      ],
    );
  }
}

class _QueueCard extends ConsumerWidget {
  const _QueueCard({required this.order});

  final PaidOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = isDarkMode(context);
    final mins = DateTime.now().difference(order.orderedAt).inMinutes.clamp(0, 99999);
    final isNew = order.kitchenStatus == 'new';

    // Lebih dari 8 menit dan belum siap: tandai terlambat
    final isLate = mins >= 8 && isNew;
    const red = Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLate
            ? (dark ? const Color(0xFF2A1618) : const Color(0xFFFFFAFA))
            : AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLate ? const Color(0xFFFCA5A5) : AppColors.line(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  order.number,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                isLate ? '$mins mnt · terlambat' : '$mins mnt',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLate ? red : AppColors.muted(context),
                ),
              ),
            ],
          ),
          Align(alignment: Alignment.centerLeft, child: Pill(order.where)),
          for (final l in order.items)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${l.qty}× ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: l.name),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                if (l.optionsLabel.isNotEmpty) SubText(l.optionsLabel),
              ],
            ),
          const SizedBox(height: 2),
          SizedBox(
            height: 42,
            child: isNew
                ? DarkButton(
                    label: 'Tandai siap',
                    onPressed: () async {
                      await advanceQueue(ref, order);
                      if (context.mounted) showToast(context, '${order.number} siap diambil');
                    },
                  )
                : TintButton(
                    label: 'Sudah diserahkan',
                    onPressed: () => advanceQueue(ref, order),
                  ),
          ),
        ],
      ),
    );
  }
}
