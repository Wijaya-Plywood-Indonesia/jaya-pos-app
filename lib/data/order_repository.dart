import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';
import 'models.dart';
import 'order_models.dart';
import 'shift_repository.dart';

/// Transaksi disimpan di tablet (tabel `orders`), jadi tetap ada walau internet mati.
/// Kolom `synced` = 0 berarti belum dikirim ke server.
class OrderRepository {
  OrderRepository(this._local);

  final LocalDb _local;

  Database get _db => _local.db;

  /// Simpan transaksi yang sudah dibayar.
  ///
  /// Nomor struk dibuat di perangkat: `yyMMdd-XXXX-001`, dengan XXXX = 4 karakter
  /// awal ID shift dan 001 = urutan di shift itu. Nomor tidak bentrok antar-tablet
  /// karena tiap shift punya ID acak.
  Future<PaidOrder> savePaid({
    required Cafe cafe,
    required AppUser user,
    required ShiftRecord shift,
    required List<CartLine> lines,
    required OrderType type,
    required String method,
    DiningTableInfo? table,
    String? customerName,
    AppliedDiscount? discount,
    int cashReceived = 0,
  }) async {
    if (lines.isEmpty) throw StateError('Pesanan kosong');

    // Diskon yang syaratnya belum terpenuhi (potongan 0) tidak dicatat
    final subtotal = lines.fold<int>(0, (s, l) => s + l.lineTotal);
    final discountAmount = discount?.amountFor(subtotal).amount ?? 0;
    final applied = discountAmount > 0 ? discount : null;

    final totals = OrderTotals.forCart(lines, cafe, discount: discountAmount);
    final isCash = method == 'cash';

    if (isCash && cashReceived < totals.total) {
      throw StateError('Uang tunai kurang');
    }

    final now = DateTime.now();
    late PaidOrder order;

    await _db.transaction((txn) async {
      final count = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM orders WHERE shift_id = ?',
              [shift.id],
            ),
          ) ??
          0;

      final number = '${DateFormat('yyMMdd').format(now)}'
          '-${shift.id.substring(0, 4).toUpperCase()}'
          '-${(count + 1).toString().padLeft(3, '0')}';

      order = PaidOrder(
        id: const Uuid().v4(),
        number: number,
        cafeId: cafe.id,
        outletId: shift.outletId ?? user.outletId,
        shiftId: shift.id,
        cashierId: user.id,
        cashierName: user.name,
        type: type,
        tableId: type == OrderType.dineIn ? table?.id : null,
        tableName: type == OrderType.dineIn ? table?.name : null,
        customerName: (customerName?.trim().isEmpty ?? true) ? null : customerName!.trim(),
        items: lines,
        totals: totals,
        taxPercent: cafe.taxPercent,
        servicePercent: cafe.servicePercent,
        method: method,
        cashReceived: isCash ? cashReceived : 0,
        change: isCash ? cashReceived - totals.total : 0,
        orderedAt: now,
        discountId: applied?.discountId,
        discountName: applied?.label,
        approvedBy: applied?.approvedBy,
      );

      await txn.insert('orders', {
        'id': order.id,
        'cafe_id': cafe.id,
        'shift_id': shift.id,
        'number': number,
        'created_at': now.millisecondsSinceEpoch,
        'status': 'paid',
        'method': method,
        'total': totals.total,
        'synced': 0,
        'kitchen_status': 'new',
        'kitchen_dirty': 0,
        'json': jsonEncode(order.toJson()),
      });
    });

    return order;
  }

  PaidOrder _fromRow(Map<String, Object?> r) {
    return PaidOrder.fromJson(
      jsonDecode(r['json'] as String) as Map<String, dynamic>,
      synced: (r['synced'] as int) == 1,
      status: r['status'] as String,
      kitchenStatus: r['kitchen_status'] as String?,
    );
  }

  /// Transaksi terbaru dulu.
  Future<List<PaidOrder>> list(int cafeId, {int limit = 200}) async {
    final rows = await _db.query(
      'orders',
      where: 'cafe_id = ?',
      whereArgs: [cafeId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(_fromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Antrian
  // ---------------------------------------------------------------------------

  /// Pesanan yang masih harus dikerjakan atau diserahkan (baru dan siap diambil),
  /// yang paling lama di atas. Hanya 24 jam terakhir, supaya pesanan yang lupa
  /// ditandai tidak menumpuk selamanya.
  Future<List<PaidOrder>> queue(int cafeId) async {
    final since = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    final rows = await _db.query(
      'orders',
      where: "cafe_id = ? AND status = 'paid' "
          "AND kitchen_status IN ('new', 'ready') AND created_at >= ?",
      whereArgs: [cafeId, since],
      orderBy: 'created_at ASC',
    );

    return rows.map(_fromRow).toList();
  }

  /// Ubah status antrian. Ditandai belum terkirim ke server (kitchen_dirty = 1).
  Future<void> setKitchenStatus(String id, String status) {
    return _db.update(
      'orders',
      {'kitchen_status': status, 'kitchen_dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Jumlah perubahan status antrian yang belum terkirim ke server.
  Future<int> dirtyKitchenCount(int cafeId) async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM orders WHERE cafe_id = ? AND kitchen_dirty = 1',
            [cafeId],
          ),
        ) ??
        0;
  }

  /// Perubahan status yang siap dikirim: transaksinya sudah ada di server.
  Future<List<({String id, String status})>> dirtyKitchen(int cafeId) async {
    final rows = await _db.query(
      'orders',
      columns: ['id', 'kitchen_status'],
      where: 'cafe_id = ? AND kitchen_dirty = 1 AND synced = 1',
      whereArgs: [cafeId],
      orderBy: 'created_at ASC',
    );

    return [
      for (final r in rows) (id: r['id'] as String, status: r['kitchen_status'] as String),
    ];
  }

  /// Hanya dibersihkan bila status belum berubah lagi selama pengiriman.
  Future<void> markKitchenSynced(String id, String status) {
    return _db.update(
      'orders',
      {'kitchen_dirty': 0},
      where: 'id = ? AND kitchen_status = ?',
      whereArgs: [id, status],
    );
  }

  // ---------------------------------------------------------------------------
  // Sinkronisasi ke server
  // ---------------------------------------------------------------------------

  /// Transaksi yang belum terkirim, terlama dulu. Yang pernah ditolak server
  /// dilewati kecuali [retryFailed].
  Future<List<PaidOrder>> pending(int cafeId, {bool retryFailed = false}) async {
    final rows = await _db.query(
      'orders',
      where: retryFailed
          ? 'cafe_id = ? AND synced = 0'
          : 'cafe_id = ? AND synced = 0 AND sync_error IS NULL',
      whereArgs: [cafeId],
      orderBy: 'created_at ASC',
    );

    return rows.map(_fromRow).toList();
  }

  /// Jumlah transaksi yang belum terkirim (termasuk yang pernah ditolak).
  Future<int> pendingCount(int cafeId) async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM orders WHERE cafe_id = ? AND synced = 0',
            [cafeId],
          ),
        ) ??
        0;
  }

  Future<void> markSynced(String id) {
    return _db.update(
      'orders',
      {'synced': 1, 'sync_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(String id, String error) {
    return _db.update(
      'orders',
      {'sync_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}