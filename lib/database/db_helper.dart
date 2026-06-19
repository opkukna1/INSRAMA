// lib/database/db_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // 1. Singleton pattern (अब यह DatabaseHelper.instance के नाम से चलेगा)
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // 🚀 फिक्स 1: डेटाबेस का नाम बदल दिया ताकि नया फ्रेश डेटाबेस बने और पुरानी एरर खत्म हो
    _database = await _initDB('ins_rama_v4.db'); 
    return _database!;
  }

  // 2. डेटाबेस इनिशियलाइज़ करना
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // 3. टेबल बनाना (Societies और Bills दोनों के लिए)
  Future _createDB(Database db, int version) async {
    // A. समिति (Society) की टेबल 
    // 🔥 फिक्स 2: इसमें UI के हिसाब से सारे कॉलम (type, code, bank, ifsc) जोड़ दिए गए हैं
    await db.execute('''
      CREATE TABLE societies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT,
        code TEXT,
        bank_account TEXT,
        ifsc TEXT
      )
    ''');

    // B. दूध के बिलों (Bills) की टेबल
    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        bill_no TEXT,
        start_date TEXT,
        end_date TEXT,
        total_milk REAL,
        milk_payment REAL,
        head_load REAL,
        overhead REAL,
        ghee_deduction REAL,
        cattle_feed_deduction REAL,
        FOREIGN KEY (society_id) REFERENCES societies (id) ON DELETE CASCADE
      )
    ''');
  }

  // ==========================================
  //         SOCIETY (समिति) के फंक्शन्स
  // ==========================================
  
  Future<int> insertSociety(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('societies', row);
  }

  Future<List<Map<String, dynamic>>> queryAllSocieties() async {
    final db = await database;
    return await db.query('societies', orderBy: 'id DESC');
  }


  // ==========================================
  //         BILLS (दूध बिल) के फंक्शन्स
  // ==========================================

  // नया बिल डेटाबेस में सेव करना (AI प्रोसेसिंग के बाद)
  Future<int> insertMilkBill(Map<String, dynamic> billData) async {
    final db = await database;
    return await db.insert('bills', billData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // किसी एक समिति के सारे बिल निकालने के लिए
  Future<List<Map<String, dynamic>>> queryBillsBySociety(int societyId) async {
    final db = await database;
    return await db.query('bills', where: 'society_id = ?', whereArgs: [societyId]);
  }

  // सारे बिल निकालने के लिए (बिना समिति के फिल्टर के)
  Future<List<Map<String, dynamic>>> getAllBills() async {
    final db = await database;
    return await db.query('bills', orderBy: "id DESC");
  }

  // किसी बिल को अपडेट करना (जब यूज़र कोई गलती सुधार कर Edit करे)
  Future<int> updateBill(int id, Map<String, dynamic> updatedData) async {
    final db = await database;
    return await db.update(
      'bills',
      updatedData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // किसी बिल को डिलीट करना
  Future<int> deleteBill(int id) async {
    final db = await database;
    return await db.delete(
      'bills',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // डेटाबेस का सारा कचरा साफ करना (Reset all data)
  Future<void> clearAllBills() async {
    final db = await database;
    await db.execute('DELETE FROM bills');
  }
}
