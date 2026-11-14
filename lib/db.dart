import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

typedef M = Map<String, dynamic>;

class DB {
  static Database? _d;
  static final tick = ValueNotifier<int>(0);
  static void bump() => tick.value++;
  static Future<Database> get db async => _d ??= await _open();

  static Future<Database> _open() async {
    final d = await openDatabase(join(await getDatabasesPath(), 'mera_khata.db'),
        version: 1, onCreate: (d, _) async {
      await d.execute(
          'CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, photo TEXT, deleted_at INTEGER)');
      await d.execute(
          'CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER, amount REAL, type TEXT, note TEXT, date INTEGER)');
    });
    // Recycle bin: only khate deleted more than 30 days ago are removed.
    final cut = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final old = await d.query('customers', columns: ['id'], where: 'deleted_at IS NOT NULL AND deleted_at<?', whereArgs: [cut]);
    for (final o in old) {
      await d.delete('entries', where: 'customer_id=?', whereArgs: [o['id']]);
      await d.delete('customers', where: 'id=?', whereArgs: [o['id']]);
    }
    return d;
  }

  // balance > 0 : usne dena hai (green) | balance < 0 : humne dena hai (red)
  static const _sel =
      "SELECT c.*, COALESCE(SUM(CASE WHEN e.type='given' THEN e.amount ELSE -e.amount END),0) AS balance "
      "FROM customers c LEFT JOIN entries e ON e.customer_id=c.id ";

  static Future<List<M>> customers({String q = ''}) async {
    final d = await db;
    final t = q.trim();
    return d.rawQuery(
        '$_sel WHERE c.deleted_at IS NULL ${t.isEmpty ? '' : 'AND (c.name LIKE ? OR c.phone LIKE ?)'} GROUP BY c.id ORDER BY c.name COLLATE NOCASE',
        t.isEmpty ? [] : ['%$t%', '%$t%']);
  }

  static Future<M?> customer(int id) async {
    final r = await (await db).rawQuery('$_sel WHERE c.id=? GROUP BY c.id', [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<List<M>> deleted() async => (await db).query('customers', where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');

  static Future<List<M>> entries(int id) async =>
      (await db).query('entries', where: 'customer_id=?', whereArgs: [id], orderBy: 'date DESC, id DESC');

  static Future<int> addCustomer(String name, String phone, String? photo) async {
    final id = await (await db).insert('customers', {'name': name, 'phone': phone, 'photo': photo});
    bump();
    return id;
  }

  static Future<void> addEntry(int cid, double amt, String type, String note, DateTime date) async {
    await (await db).insert('entries',
        {'customer_id': cid, 'amount': amt, 'type': type, 'note': note, 'date': date.millisecondsSinceEpoch});
    bump();
  }

  static Future<void> delEntry(int id) async {
    await (await db).delete('entries', where: 'id=?', whereArgs: [id]);
    bump();
  }

  static Future<void> softDelete(int id) async {
    await (await db).update('customers', {'deleted_at': DateTime.now().millisecondsSinceEpoch}, where: 'id=?', whereArgs: [id]);
    bump();
  }

  static Future<void> restore(int id) async {
    await (await db).update('customers', {'deleted_at': null}, where: 'id=?', whereArgs: [id]);
    bump();
  }
}
