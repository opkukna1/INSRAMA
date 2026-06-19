// lib/database/db_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // V5 पर वर्शन बढ़ा दिया है ताकि टेबल स्कीमा अपडेट हो सके
    _database = await _initDB('ins_rama_v5.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Societies Table
    await db.execute('''
      CREATE TABLE societies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT, code TEXT, bank_account TEXT, ifsc TEXT
      )
    ''');

    // 2. Processed Files (डुप्लीकेट रोकने के लिए)
    await db.execute('''
      CREATE TABLE processed_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        file_hash TEXT UNIQUE, -- SHA-256 हैश ताकि एक फाइल दोबारा न आए
        file_name TEXT,
        process_date TEXT
      )
    ''');

    // 3. Master Ledger (सारे फाइनेंशियल डेटा का आधार)
    await db.execute('''
      CREATE TABLE master_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        date TEXT,
        particulars TEXT,
        amount REAL,
        type TEXT, -- 'DEBIT' या 'CREDIT'
        category TEXT, -- 'Income', 'Expense', 'Asset', 'Liability'
        doc_type TEXT, -- 'Bill', 'Voucher', 'BankStatement'
        reference_no TEXT
      )
    ''');
  }

  // --- फाइल डुप्लीकेशन रोकने का लॉजिक ---
  Future<bool> isFileAlreadyProcessed(String hash) async {
    final db = await database;
    final res = await db.query('processed_files', where: 'file_hash = ?', whereArgs: [hash]);
    return res.isNotEmpty;
  }

  Future<void> markFileAsProcessed(int societyId, String hash, String fileName) async {
    final db = await database;
    await db.insert('processed_files', {
      'society_id': societyId,
      'file_hash': hash,
      'file_name': fileName,
      'process_date': DateTime.now().toIso8601String()
    });
  }

  // --- मास्टर लेजर में एंट्री ---
  Future<int> insertLedgerEntry(Map<String, dynamic> entry) async {
    final db = await database;
    return await db.insert('master_ledger', entry);
  }
  
  // --- डेटा एक्सपोर्ट के लिए सारा डेटा निकालना ---
  Future<List<Map<String, dynamic>>> getMasterLedger(int societyId) async {
    final db = await database;
    return await db.query('master_ledger', where: 'society_id = ?', orderBy: 'date DESC');
  }
}
