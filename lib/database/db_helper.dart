// lib/database/db_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // 🚀 फ्रेश डेटाबेस वर्जन ताकि सभी नई टेबल बिना किसी एरर के बन जाएँ
    _database = await _initDB('ins_rama_v6.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Societies Table (समितियों की जानकारी)
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

    // 2. Processed Files Table (डुप्लीकेट फाइल्स रोकने के लिए SHA-256 हैश)
    await db.execute('''
      CREATE TABLE processed_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        file_hash TEXT UNIQUE,
        file_name TEXT,
        process_date TEXT
      )
    ''');

    // 3. Master Ledger Table (सारे फाइनेंशियल डाक्यूमेंट्स का कंबाइंड डेटा)
    await db.execute('''
      CREATE TABLE master_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        date TEXT,
        particulars TEXT,
        amount REAL,
        type TEXT,          -- 'DEBIT' या 'CREDIT'
        category TEXT,      -- 'Income', 'Expense', 'Asset', 'Liability'
        doc_type TEXT,      -- 'Milk Bill', 'Voucher', 'Bank Statement', 'Minutes of Meeting', 'Other'
        reference_no TEXT
      )
    ''');

    // 🚀 4. नई टेबल: Document Doubts Table (AI द्वारा खोजी गई संदिग्ध गड़बड़ियां - हिंदी में)
    await db.execute('''
      CREATE TABLE document_doubts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        file_name TEXT,
        doubt_text TEXT,    -- शुद्ध हिंदी में अलर्ट नोट
        created_at TEXT
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
  //     PROCESSED FILES (डुप्लीकेट रोकने के लिए)
  // ==========================================
  
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

  // ==========================================
  //      MASTER LEDGER (इन-ऐप एक्सेल एडिटिंग के लिए)
  // ==========================================
  
  // नई एंट्री जोड़ना
  Future<int> insertLedgerEntry(Map<String, dynamic> entry) async {
    final db = await database;
    return await db.insert('master_ledger', entry);
  }
  
  // किसी समिति का सारा मास्टर लेज़र डेटा निकालना
  Future<List<Map<String, dynamic>>> getMasterLedger(int societyId) async {
    final db = await database;
    return await db.query('master_ledger', where: 'society_id = ?', orderBy: 'date DESC');
  }

  // 🚀 नया: एंट्री अपडेट करना (जब यूजर इन-ऐप एक्सेल शीट में डाटा एडिट करे)
  Future<int> updateLedgerEntry(int id, Map<String, dynamic> updatedData) async {
    final db = await database;
    return await db.update(
      'master_ledger',
      updatedData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 🚀 नया: एंट्री डिलीट करना
  Future<int> deleteLedgerEntry(int id) async {
    final db = await database;
    return await db.delete(
      'master_ledger',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // लेज़र का सारा कचरा साफ करना
  Future<void> clearMasterLedger(int societyId) async {
    final db = await database;
    await db.delete('master_ledger', where: 'society_id = ?', whereArgs: [societyId]);
  }

  // ==========================================
  //     🚀 DOCUMENT DOUBTS (हिंदी ऑडिट रिपोर्ट्स)
  // ==========================================
  
  // संदिग्ध एंट्री या गड़बड़ी को सेव करना
  Future<int> insertDocumentDoubt(Map<String, dynamic> doubtData) async {
    final db = await database;
    return await db.insert('document_doubts', doubtData);
  }

  // किसी समिति के सारे हिंदी डाउट्स/अलर्ट्स स्क्रीन पर दिखाने के लिए निकालना
  Future<List<Map<String, dynamic>>> getDoubtsBySociety(int societyId) async {
    final db = await database;
    return await db.query('document_doubts', where: 'society_id = ?', orderBy: 'id DESC');
  }

  // किसी स्पेसिफिक डाउट को हटाने के लिए (अगर यूजर ने गड़बड़ी चेक करके ठीक कर दी हो)
  Future<int> deleteDocumentDoubt(int id) async {
    final db = await database;
    return await db.delete('document_doubts', where: 'id = ?', whereArgs: [id]);
  }
}
