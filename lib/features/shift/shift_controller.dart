import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_db.dart';
import '../../data/shift_repository.dart';
import '../session/session_controller.dart';

final shiftRepoProvider = Provider<ShiftRepository>(
  (ref) => ShiftRepository(ref.watch(localDbProvider)),
);

/// Shift yang sedang berjalan. null = belum ada, jadi aplikasi meminta kas awal.
/// Shift milik perangkat, bukan milik akun: ganti kasir tidak menutup shift.
final shiftProvider =
    AsyncNotifierProvider<ShiftController, ShiftRecord?>(ShiftController.new);

class ShiftController extends AsyncNotifier<ShiftRecord?> {
  @override
  Future<ShiftRecord?> build() async {
    final cafeId = ref.watch(sessionProvider.select((s) => s.value?.cafe?.id));
    if (cafeId == null) return null;

    return ref.read(shiftRepoProvider).current(cafeId);
  }

  Future<void> open(int openingCash) async {
    final session = ref.read(sessionProvider).requireValue;
    final user = session.user;
    final cafe = session.cafe;
    if (user == null || cafe == null) return;

    final shift = await ref.read(shiftRepoProvider).start(
          cafeId: cafe.id,
          user: user,
          openingCash: openingCash,
        );

    state = AsyncData(shift);
  }

  Future<void> close(int counted) async {
    final shift = state.value;
    if (shift == null) return;

    final repo = ref.read(shiftRepoProvider);
    final summary = await repo.summary(shift.id);

    await repo.close(
      shift.id,
      counted: counted,
      expected: shift.openingCash + summary.cashSales,
    );

    state = const AsyncData(null);
  }
}