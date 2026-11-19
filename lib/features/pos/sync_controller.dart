import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../session/session_controller.dart';
import '../shift/shift_controller.dart';
import 'order_controller.dart';

class SyncState {
  const SyncState({
    this.pending = 0,
    this.syncing = false,
    this.lastBatch = 0,
    this.batchId = 0,
    this.announce = false,
  });

  /// Transaksi di tablet yang belum terkirim ke server.
  final int pending;
  final bool syncing;

  /// Jumlah transaksi yang terkirim pada putaran terakhir.
  final int lastBatch;

  /// Naik setiap kali ada putaran yang berhasil mengirim transaksi.
  final int batchId;

  /// true = putaran terakhir perlu diumumkan ke kasir (setelah sempat offline).
  final bool announce;

  SyncState copyWith({
    int? pending,
    bool? syncing,
    int? lastBatch,
    int? batchId,
    bool? announce,
  }) {
    return SyncState(
      pending: pending ?? this.pending,
      syncing: syncing ?? this.syncing,
      lastBatch: lastBatch ?? this.lastBatch,
      batchId: batchId ?? this.batchId,
      announce: announce ?? this.announce,
    );
  }
}

enum _Outcome { ok, retryLater, rejected }

final syncProvider = NotifierProvider<SyncController, SyncState>(SyncController.new);

/// Mengirim shift dan transaksi yang tersimpan di tablet ke server.
/// Shift dikirim lebih dulu karena transaksi merujuk ke shift.
class SyncController extends Notifier<SyncState> {
  bool _running = false;
  bool _announce = false;

  @override
  SyncState build() {
    // Hitung ulang jumlah yang menunggu setiap ada transaksi baru
    ref.listen(ordersRevisionProvider, (_, _) => _refreshPending());
    Future.microtask(_refreshPending);

    return const SyncState();
  }

  /// Dipanggil saat internet kembali: putaran berikutnya yang berhasil mengirim
  /// akan diumumkan ("Online lagi. N transaksi disinkronkan").
  void announceNext() => _announce = true;

  Future<void> _refreshPending() async {
    final cafeId = ref.read(sessionProvider).value?.cafe?.id;
    if (cafeId == null) return;

    final n = await ref.read(orderRepoProvider).pendingCount(cafeId);
    if (n != state.pending) state = state.copyWith(pending: n);
  }

  /// Kirim semua yang tertunda. Aman dipanggil kapan saja: tidak melakukan apa-apa
  /// bila tidak ada yang tertunda, belum punya token, atau sedang berjalan.
  /// [retryFailed] = coba lagi data yang sebelumnya ditolak server.
  Future<void> run({bool retryFailed = false}) async {
    if (_running) return;

    final s = ref.read(sessionProvider).value;
    final token = s?.token;
    final baseUrl = s?.baseUrl;
    final cafeId = s?.cafe?.id;

    // Masuk lewat PIN offline: belum punya token, tunggu sampai online
    if (token == null || baseUrl == null || cafeId == null) return;

    _running = true;
    var started = false;
    var sent = 0;

    try {
      final shifts = ref.read(shiftRepoProvider);
      final orders = ref.read(orderRepoProvider);
      final api = Api(baseUrl, token: token);

      final shiftList = await shifts.pendingForSync(cafeId, retryFailed: retryFailed);
      final orderList = await orders.pending(cafeId, retryFailed: retryFailed);

      final kitchenCount = await orders.dirtyKitchenCount(cafeId);

      if (shiftList.isEmpty && orderList.isEmpty && kitchenCount == 0) {
        _announce = false;
        await _refreshPending();
        return;
      }

      started = true;
      state = state.copyWith(syncing: true);

      var stop = false;
      var halted = false;
      final rejectedShifts = <String>{};

      // 1. Shift dulu
      for (final sh in shiftList) {
        final (outcome, error) = await _post(api, '/shifts', sh.body);

        if (outcome == _Outcome.ok) {
          await shifts.markSynced(sh.id);
        } else if (outcome == _Outcome.rejected) {
          await shifts.markFailed(sh.id, error ?? 'Ditolak server');
          rejectedShifts.add(sh.id);
        } else {
          stop = true;
          break;
        }
      }

      // 2. Lalu transaksi, yang paling lama dulu
      if (!stop) {
        for (final o in orderList) {
          if (o.shiftId != null && rejectedShifts.contains(o.shiftId)) continue;

          final (outcome, error) = await _post(api, '/orders', o.toJson());

          if (outcome == _Outcome.ok) {
            await orders.markSynced(o.id);
            sent++;
          } else if (outcome == _Outcome.rejected) {
            await orders.markFailed(o.id, error ?? 'Ditolak server');
          } else {
            halted = true;
            break;
          }
        }
      }

      // 3. Terakhir, perubahan status antrian (Baru, Siap, Selesai).
      // Dicari setelah transaksi terkirim, supaya yang baru terkirim ikut diproses.
      if (!stop && !halted) {
        for (final k in await orders.dirtyKitchen(cafeId)) {
          final (outcome, _) = await _post(
            api,
            '/orders/${k.id}/kitchen-status',
            {'status': k.status},
          );

          if (outcome == _Outcome.retryLater) break;

          // Diterima, atau ditolak server (misalnya transaksinya tidak ada):
          // jangan dikirim ulang terus-menerus
          await orders.markKitchenSynced(k.id, k.status);
        }
      }
    } finally {
      _running = false;

      if (started) {
        final show = _announce && sent > 0;
        if (sent > 0) _announce = false;

        state = state.copyWith(
          syncing: false,
          lastBatch: sent > 0 ? sent : state.lastBatch,
          batchId: sent > 0 ? state.batchId + 1 : state.batchId,
          announce: show,
        );

        await _refreshPending();

        // Riwayat memuat ulang supaya label "Belum sinkron" hilang
        if (sent > 0) ref.read(ordersRevisionProvider.notifier).bump();
      }
    }
  }

  /// ok = diterima (termasuk "sudah pernah diterima"),
  /// retryLater = gangguan jaringan atau server, coba lagi nanti,
  /// rejected = server menolak datanya, jangan dikirim ulang terus-menerus.
  Future<(_Outcome, String?)> _post(
    Api api,
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      await api.post(path, data: body);
      return (_Outcome.ok, null);
    } on ApiException catch (e) {
      final status = e.status;
      final transient =
          status == null || status >= 500 || status == 401 || status == 429;

      return (transient ? _Outcome.retryLater : _Outcome.rejected, e.message);
    }
  }
}