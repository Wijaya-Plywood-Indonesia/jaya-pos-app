import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db.dart';
import '../../data/order_models.dart';
import '../../data/order_repository.dart';
import '../session/session_controller.dart';

final orderRepoProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(localDbProvider)),
);

/// Dinaikkan setiap ada transaksi baru supaya riwayat memuat ulang.
final ordersRevisionProvider =
    NotifierProvider<OrdersRevision, int>(OrdersRevision.new);

class OrdersRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Riwayat transaksi di tablet ini, terbaru dulu.
final historyProvider = FutureProvider<List<PaidOrder>>((ref) async {
  ref.watch(ordersRevisionProvider);
  final cafeId = ref.watch(sessionProvider.select((s) => s.value?.cafe?.id));
  if (cafeId == null) return const [];

  return ref.read(orderRepoProvider).list(cafeId);
});
