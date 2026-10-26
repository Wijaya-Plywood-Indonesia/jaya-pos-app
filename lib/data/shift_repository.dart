import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';
import 'models.dart';

class ShiftRecord {
  const ShiftRecord({
    required this.id,
    required this.cafeId,
    required this.userId,
    required this.userName,
    required this.openedAt,
    required this.openingCash,
    this.outletId,
  });

  final String id;
  final int cafeId;
  final int userId;
  final String userName;
  final int? outletId;
  final DateTime openedAt;
  final int openingCash;

  factory ShiftRecord.fromRow(Map<String, Object?> r) => ShiftRecord(
        id: r['id'] as String,
        cafeId: r['cafe_id'] as int,
        userId: r['user_id'] as int,
        userName: r['user_name'] as String,
        outletId: r['outlet_id'] as int?,
        openedAt: DateTime.fromMillisecondsSinceEpoch(r['opened_at'] as int),
        openingCash: r['opening_cash'] as int,
      );
}

/// Ringkasan penjualan dalam satu shift, dihitung dari transaksi di tablet.
class ShiftSummary {
  const ShiftSummary({required this.byMethod, required this.count});

  /// cash, qris, card -> total rupiah
  final Map<String, int> byMethod;
  final int count;

  int get cashSales => byMethod['cash'] ?? 0;
}

class ShiftRepository {
  ShiftRepository(this._local);

  final LocalDb _local;

  Database get _db => _local.db;

  /// Shift yang masih berjalan di perangkat ini (satu laci kas per perangkat).
  Future<ShiftRecord?> current(int cafeId) async {
    final rows = await _db.query(
      'shifts',
      where: 'cafe_id = ? AND closed_at IS NULL',
      whereArgs: [cafeId],
      orderBy: 'opened_at DESC',
      limit: 1,
    );

    return rows.isEmpty ? null : ShiftRecord.fromRow(rows.first);
  }

  Future<ShiftRecord> start({
    required int cafeId,
    required AppUser user,
    required int openingCash,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.insert('shifts', {
      'id': id,
      'cafe_id': cafeId,
      'user_id': user.id,
      'user_name': user.name,
      'outlet_id': user.outletId,
      'opened_at': now.millisecondsSinceEpoch,
      'opening_cash': openingCash,
      'synced': 0,
    });

    return ShiftRecord(
      id: id,
      cafeId: cafeId,
      userId: user.id,
      userName: user.name,
      outletId: user.outletId,
      openedAt: now,
      openingCash: openingCash,
    );
  }

  Future<ShiftSummary> summary(String shiftId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT method, COUNT(*) AS n, COALESCE(SUM(total), 0) AS s
      FROM orders
      WHERE shift_id = ? AND status = 'paid'
      GROUP BY method
      ''',
      [shiftId],
    );

    final byMethod = <String, int>{};
    var count = 0;

    for (final r in rows) {
      byMethod[r['method'] as String] = (r['s'] as num).toInt();
      count += (r['n'] as num).toInt();
    }

    return ShiftSummary(byMethod: byMethod, count: count);
  }

  Future<void> close(
    String shiftId, {
    required int counted,
    required int expected,
  }) async {
    await _db.update(
      'shifts',
      {
        'closed_at': DateTime.now().millisecondsSinceEpoch,
        'closing_cash': counted,
        'expected_cash': expected,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }
}