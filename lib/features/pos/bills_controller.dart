import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/bill_repository.dart';
import '../../data/local_db.dart';
import '../../data/models.dart';
import '../../data/order_models.dart';
import '../session/session_controller.dart';
import 'cart_controller.dart';

final billRepoProvider = Provider<BillRepository>(
  (ref) => BillRepository(ref.watch(localDbProvider)),
);

final billsProvider =
    AsyncNotifierProvider<BillsController, List<SavedBill>>(BillsController.new);

/// Jumlah bill tersimpan (angka di ikon penanda).
final billCountProvider = Provider<int>(
  (ref) => ref.watch(billsProvider).value?.length ?? 0,
);

class BillsController extends AsyncNotifier<List<SavedBill>> {
  @override
  Future<List<SavedBill>> build() async {
    final cafeId = ref.watch(sessionProvider.select((s) => s.value?.cafe?.id));
    if (cafeId == null) return const [];

    return ref.read(billRepoProvider).list(cafeId);
  }

  /// Simpan pesanan aktif sebagai bill. Keranjang dikosongkan oleh pemanggil.
  Future<void> save({required CartState cart, DiningTableInfo? table}) async {
    final cafeId = ref.read(sessionProvider).value?.cafe?.id;
    if (cafeId == null || cart.isEmpty) return;

    final dineIn = cart.type == OrderType.dineIn;
    final name = cart.customerName.trim();

    final bill = SavedBill(
      id: const Uuid().v4(),
      cafeId: cafeId,
      createdAt: DateTime.now(),
      lines: cart.lines,
      type: cart.type,
      tableId: dineIn ? table?.id : null,
      tableName: dineIn ? table?.name : null,
      customerName: name.isNotEmpty ? name : null,
    );

    await ref.read(billRepoProvider).insert(bill);
    state = AsyncData([...(state.value ?? const <SavedBill>[]), bill]);
  }

  Future<void> remove(String id) async {
    await ref.read(billRepoProvider).delete(id);
    state = AsyncData(
      (state.value ?? const <SavedBill>[]).where((b) => b.id != id).toList(),
    );
  }
}