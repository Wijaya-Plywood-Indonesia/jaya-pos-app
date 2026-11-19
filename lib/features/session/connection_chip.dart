import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pos/sync_controller.dart';
import 'online_controller.dart';

/// Penanda Online / Offline seperti di mockup, plus jumlah transaksi yang
/// belum terkirim ke server.
class ConnectionChip extends ConsumerWidget {
  const ConnectionChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider);
    final pending = ref.watch(syncProvider.select((s) => s.pending));
    final color = online ? const Color(0xFF16A34A) : const Color(0xFFD97706);

    final label = online
        ? (pending > 0 ? 'Online · $pending menunggu' : 'Online')
        : (pending > 0 ? 'Offline · $pending' : 'Offline');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}