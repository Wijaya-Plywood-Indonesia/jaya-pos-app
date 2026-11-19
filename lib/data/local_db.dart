import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Diisi di main.dart
final localDbProvider = Provider<LocalDb>(
  (ref) => throw UnimplementedError('localDbProvider harus di-override di main.dart'),
);

/// Database lokal di tablet. Shift dan transaksi disimpan di sini, jadi tetap ada
/// walau aplikasi ditutup atau internet mati.
class LocalDb {
  LocalDb._(this.db);

  final Database db;

  static Future<LocalDb> open() async {
    final path = p.join(await getDatabasesPath(), 'jaya_pos.db');

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shifts (
            id TEXT PRIMARY KEY,
            cafe_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            user_name TEXT NOT NULL,
            outlet_id INTEGER,
            opened_at INTEGER NOT NULL,
            opening_cash INTEGER NOT NULL,
            closed_at INTEGER,
            closing_cash INTEGER,
            expected_cash INTEGER,
            synced INTEGER NOT NULL DEFAULT 0,
            sync_error TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE orders (
            id TEXT PRIMARY KEY,
            cafe_id INTEGER NOT NULL,
            shift_id TEXT,
            number TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            method TEXT NOT NULL,
            total INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            json TEXT NOT NULL,
            sync_error TEXT
          )
        ''');

        await db.execute('CREATE INDEX idx_orders_shift ON orders(shift_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Versi 2: catatan alasan bila server menolak sebuah data
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE shifts ADD COLUMN sync_error TEXT');
          await db.execute('ALTER TABLE orders ADD COLUMN sync_error TEXT');
        }
      },
    );

    return LocalDb._(db);
  }
}