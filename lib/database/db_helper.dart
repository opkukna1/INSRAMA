import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = "ins_rama_local.db";
  static const _databaseVersion = 1;

  // सिंगलटन पैटर्न (ताकि पूरे ऐप में डेटाबेस का एक ही कनेक्शन रहे)
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // फोन के अंदर लोकल टेबल्स बनाने का कोड
  Future _onCreate(Database db, int version) async {
    // 1. समितियों की मास्टर टेबल (Dugdh, GSS, Mahila Samiti सब इसी में हैंडल होंगी)
    await db.execute('''
      CREATE TABLE societies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        code TEXT UNIQUE,
        bank_account TEXT,
        ifsc TEXT
      )
    ''');

    // 2. दुग्ध बिलों का डेटा स्टोर करने के लिए टेबल
    await db.execute('''
      CREATE TABLE milk_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        bill_no TEXT UNIQUE,
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

    // 3. सदस्यों की बकाया सूची (Bakaya Suchi) के लिए टेबल
    await db.execute('''
      CREATE TABLE members_outstanding (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        member_name TEXT NOT NULL,
        father_name TEXT,
        share_capital REAL DEFAULT 0.0,
        outstanding_amount REAL DEFAULT 0.0,
        FOREIGN KEY (society_id) REFERENCES societies (id) ON DELETE CASCADE
      )
    ''');

    // 4. बैंक पासबुक / लेजर एंट्रीज के लिए टेबल
    await db.execute('''
      CREATE TABLE bank_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        txn_date TEXT,
        description TEXT,
        debit REAL,
        credit REAL,
        balance REAL,
        FOREIGN KEY (society_id) REFERENCES societies (id) ON DELETE CASCADE
      )
    ''');
  }

  // ------------------------------------------------------------------
  // डेटाबेस में डेटा इन्सर्ट (Insert) और क्वेरी (Query) करने के फंक्शन्स
  // ------------------------------------------------------------------

  // नई समिति जोड़ें
  Future<int> insertSociety(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('societies', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // सभी समितियों की लिस्ट देखें
  Future<List<Map<String, dynamic>>> queryAllSocieties() async {
    Database db = await instance.database;
    return await db.query('societies');
  }

  // नया दुग्ध बिल डेटा सेव करें
  Future<int> insertMilkBill(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('milk_bills', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // किसी एक समिति के सभी बिल निकालें
  Future<List<Map<String, dynamic>>> queryBillsBySociety(int societyId) async {
    Database db = await instance.database;
    return await db.query('milk_bills', where: 'society_id = ?', whereArgs: [societyId]);
  }

  // सदस्यों की बकाया सूची सेव करें
  Future<int> insertMemberOutstanding(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('members_outstanding', row);
  }

  // किसी समिति की पूरी बकाया सूची निकालें
  Future<List<Map<String, dynamic>>> queryOutstandingBySociety(int societyId) async {
    Database db = await instance.database;
    return await db.query('members_outstanding', where: 'society_id = ?', whereArgs: [societyId]);
  }
}
