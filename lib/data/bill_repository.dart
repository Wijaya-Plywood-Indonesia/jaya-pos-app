import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_db.dart';
import 'order_models.dart';

/// Pesanan yang disimpan dulu sebelum dibayar (misalnya pelanggan belum selesai memilih).
/// Hanya ada di tablet, tidak dikirim ke server.
class SavedBill {
  const SavedBill({
    required this.id,
    required this.cafeId,
    required this.createdAt,
    required this.lines,
    required this.type,
    this.tableId,
    this.tableName,
    this.customerName,
  });

  final String id;
  final int cafeId;
  final DateTime createdAt;
  final List<CartLine> lines;
  final OrderType type;
  final int? tableId;
  final String? tableName;
  final String? customerName;

  int get itemCount => lines.fold(0, (s, l) => s + l.qty);

  int get subtotal => lines.fold(0, (s, l) => s + l.lineTotal);

  String get where => orderWhere(type, tableName: tableName, customerName: customerName);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafe_id': cafeId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'type': type.api,
        'table_id': tableId,
        'table_name': tableName,
        'customer_name': customerName,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory SavedBill.fromJson(Map<String, dynamic> j) => SavedBill(
        id: j['id'] as String,
        cafeId: (j['cafe_id'] as num).toInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['created_at'] as num).toInt()),
        type: OrderType.fromApi(j['type'] as String?),
        tableId: (j['table_id'] as num?)?.toInt(),
        tableName: j['table_name'] as String?,
        customerName: j['customer_name'] as String?,
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BillRepository {
  BillRepository(this._local);

  final LocalDb _local;

  Database get _db => _local.db;

  /// Yang paling lama disimpan di atas.
  Future<List<SavedBill>> list(int cafeId) async {
    final rows = await _db.query(
      'bills',
      where: 'cafe_id = ?',
      whereArgs: [cafeId],
      orderBy: 'created_at ASC',
    );

    return rows
        .map((r) => SavedBill.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> insert(SavedBill bill) {
    return _db.insert('bills', {
      'id': bill.id,
      'cafe_id': bill.cafeId,
      'created_at': bill.createdAt.millisecondsSinceEpoch,
      'json': jsonEncode(bill.toJson()),
    });
  }

  Future<void> delete(String id) {
    return _db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }
}
