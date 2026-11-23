import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../data/menu_repository.dart';
import '../../data/order_models.dart';
import '../pos/sync_controller.dart';
import '../session/session_controller.dart';

/// Data menu untuk layar Stok (daftar bahan, resep, HPP). Dimuat ulang setiap kali
/// transaksi terkirim ke server, karena saat itu stok di server berkurang.
final menuDataProvider = FutureProvider<MenuResult>((ref) async {
  ref.watch(syncProvider.select((s) => s.batchId));
  ref.watch(stockRevisionProvider);

  final s = ref.watch(sessionProvider).value;
  final baseUrl = s?.baseUrl;
  if (s == null || baseUrl == null) throw StateError('Belum masuk');

  final repo = MenuRepository(Api(baseUrl, token: s.token), ref.read(storeProvider));

  return repo.load(skipNetwork: s.offline);
});

/// Dinaikkan setelah stok dibeli, supaya layar Kasir dan Stok memuat ulang.
final stockRevisionProvider = NotifierProvider<StockRevision, int>(StockRevision.new);

class StockRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Porsi yang sudah terjual di tablet ini sejak menu terakhir dimuat dari server.
/// Dipakai supaya menu yang hampir habis tidak terjual berlebihan, terutama saat offline.
final soldLocalProvider = NotifierProvider<SoldLocal, Map<int, int>>(SoldLocal.new);

class SoldLocal extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};

  void add(List<CartLine> lines) {
    final next = {...state};

    for (final l in lines) {
      next[l.productId] = (next[l.productId] ?? 0) + l.qty;
    }

    state = next;
  }

  void reset() {
    if (state.isNotEmpty) state = const {};
  }
}

/// Beli stok (hanya owner atau manajer, dan butuh internet).
Future<void> restockIngredient(
  WidgetRef ref, {
  required int ingredientId,
  required double quantity,
}) async {
  final s = ref.read(sessionProvider).value;
  final baseUrl = s?.baseUrl;
  final token = s?.token;

  if (baseUrl == null || token == null) {
    throw ApiException('Butuh internet. Masuk lagi saat online untuk membeli stok.');
  }

  await Api(baseUrl, token: token).post(
    '/stock/restock',
    data: {'ingredient_id': ingredientId, 'quantity': quantity},
  );

  ref.read(stockRevisionProvider.notifier).bump();
}
