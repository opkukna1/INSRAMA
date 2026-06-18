// lib/database/db_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  // Singleton pattern ताकि पूरे ऐप में डेटाबेस का एक ही इंस्टेंस रहे
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // 1. डेटाबेस इनिशियलाइज़ करना
  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'ins_rama_accounting.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // 2. टेबल बनाना (AI के JSON Schema के आधार पर)
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_no TEXT,
        start_date TEXT,
        end_date TEXT,
        total_milk REAL,
        milk_payment REAL,
        head_load REAL,
        overhead REAL,
        ghee_deduction REAL,
        cattle_feed_deduction REAL
      )
    ''');
  }

  // 3. नया बिल डेटाबेस में सेव करना (AI प्रोसेसिंग के बाद)
  Future<int> insertBill(Map<String, dynamic> billData) async {
    Database db = await database;
    return await db.insert('bills', billData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 4. सारे बिल डेटाबेस से निकालना (UI में दिखाने और P&L बनाने के लिए)
  Future<List<Map<String, dynamic>>> getAllBills() async {
    Database db = await database;
    return await db.query('bills', orderBy: "id DESC");
  }

  // 5. किसी बिल को अपडेट करना (जब यूज़र कोई गलती सुधार कर Edit करे)
  Future<int> updateBill(int id, Map<String, dynamic> updatedData) async {
    Database db = await database;
    return await db.update(
      'bills',
      updatedData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 6. किसी बिल को डिलीट करना
  Future<int> deleteBill(int id) async {
    Database db = await database;
    return await db.delete(
      'bills',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 7. डेटाबेस का सारा कचरा साफ करना (Reset all data)
  Future<void> clearAllBills() async {
    Database db = await database;
    await db.execute('DELETE FROM bills');
  }
}
