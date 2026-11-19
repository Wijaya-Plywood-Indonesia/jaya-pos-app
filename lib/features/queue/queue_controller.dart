import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/order_models.dart';
import '../pos/order_controller.dart';
import '../pos/sync_controller.dart';
import '../session/session_controller.dart';

/// Pesanan yang masih di antrian: Baru dan Siap diambil, yang paling lama di atas.
final queueProvider = FutureProvider<List<PaidOrder>>((ref) async {
  ref.watch(ordersRevisionProvider);
  final cafeId = ref.watch(sessionProvider.select((s) => s.value?.cafe?.id));
  if (cafeId == null) return const [];

  return ref.read(orderRepoProvider).queue(cafeId);
});

/// Jumlah pesanan baru (angka merah di menu Antrian).
final queueNewCountProvider = Provider<int>((ref) {
  final list = ref.watch(queueProvider).value ?? const <PaidOrder>[];

  return list.where((o) => o.kitchenStatus == 'new').length;
});

/// Baru -> Siap diambil -> Sudah diserahkan (hilang dari antrian).
/// Tersimpan di tablet dulu, lalu dikirim ke server saat online.
Future<void> advanceQueue(WidgetRef ref, PaidOrder order) async {
  final next = order.kitchenStatus == 'new' ? 'ready' : 'served';

  await ref.read(orderRepoProvider).setKitchenStatus(order.id, next);
  ref.read(ordersRevisionProvider.notifier).bump();
  ref.read(syncProvider.notifier).run();
}
