// lib/database/db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // 🚀 वर्जन 2: नए 4-अकाउंट सपोर्ट और मैपिंग के साथ
    _database = await _initDB('ins_rama_v2.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    // वर्जन 1 से 2 पर जाने के लिए onUpgrade सपोर्ट जोड़ा गया
    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // अगर पुराना डेटाबेस है, तो उसे नए वर्ज़न में अपग्रेड करना (क्रैश से बचाने के लिए)
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // यदि पुराने डेटाबेस में master_ledger है, तो उसे अपडेट करें या नया बनाएं
      try {
        await db.execute("ALTER TABLE master_ledger ADD COLUMN account_head TEXT;");
        await db.execute("ALTER TABLE master_ledger ADD COLUMN is_manual INTEGER DEFAULT 0;");
      } catch (e) {
        // अगर टेबल नहीं है, तो कुछ न करें, onCreate उसे बना लेगा
        print("Upgrade Log: Columns might already exist or table missing.");
      }
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. Societies Table
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

    // 2. Processed Files Table (AI Bills History)
    await db.execute('''
      CREATE TABLE processed_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        file_hash TEXT UNIQUE,
        file_name TEXT,
        process_date TEXT
      )
    ''');

    // 3. Master Ledger Table (🚀 AI और Manual दोनों का संयुक्त डेटा)
    await db.execute('''
      CREATE TABLE master_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        date TEXT,
        particulars TEXT,
        amount REAL,
        type TEXT,          -- 'DEBIT' या 'CREDIT'
        category TEXT,      -- 'Income', 'Expense', 'Asset', 'Liability'
        doc_type TEXT,      -- 'Milk Bill', 'Voucher', 'Bank Statement', 'Other'
        reference_no TEXT,
        account_head TEXT,  -- 🌟 'milk_purchase', 'milk_sales', 'establishment_expense', etc.
        is_manual INTEGER DEFAULT 0 -- 🌟 0 = AI, 1 = हाथ से जोड़ी गई एंट्री
      )
    ''');

    // 4. Document Doubts Table (AI Alerts)
    await db.execute('''
      CREATE TABLE document_doubts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        society_id INTEGER,
        file_name TEXT,
        doubt_text TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_ledger_society ON master_ledger (society_id);');
    await db.execute('CREATE INDEX idx_files_society ON processed_files (society_id);');
    await db.execute('CREATE INDEX idx_doubts_society ON document_doubts (society_id);');
  }

  // ==========================================
  //  💡 मैन्युअल सम्पादन (CRUD): ADD, EDIT, DELETE
  // ==========================================
  
  // 1. नई मैन्युअल एंट्री जोड़ना (जैसे बिना बिल का फुटकर खर्च या आय)
  Future<int> insertLedgerEntry(Map<String, dynamic> entry) async {
    final db = await database;
    return await db.insert('master_ledger', entry);
  }

  // 2. लेज़र का डेटा निकालना
  Future<List<Map<String, dynamic>>> getMasterLedger(int societyId) async {
    final db = await database;
    return await db.query(
      'master_ledger', 
      where: 'society_id = ?', 
      whereArgs: [societyId], 
      orderBy: 'date DESC'
    );
  }

  // 3. एंट्री को एडिट (संशोधित) करना
  Future<int> updateLedgerEntry(int id, Map<String, dynamic> updatedData) async {
    final db = await database;
    return await db.update(
      'master_ledger',
      updatedData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 4. एंट्री डिलीट करना
  Future<int> deleteLedgerEntry(int id) async {
    final db = await database;
    return await db.delete(
      'master_ledger',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  //  🧮 फाइनल 4 खातों का समरी इंजन (SQL Aggregation)
  // ==========================================
  Future<Map<String, double>> calculateFourAccounts(int societyId) async {
    final db = await database;

    // हेल्पर फंक्शन: विशिष्ट हेड का टोटल निकालने के लिए
    Future<double> sumByHead(String head) async {
      final res = await db.rawQuery(
        "SELECT SUM(amount) as total FROM master_ledger WHERE society_id = ? AND account_head = ?",
        [societyId, head]
      );
      return (res.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    // 1. ट्रेडिंग अकाउंट की मदें
    double milkPurchase = await sumByHead('milk_purchase');
    double milkSales = await sumByHead('milk_sales');
    double cattleFeedPurchase = await sumByHead('feed_purchase');
    double cattleFeedSales = await sumByHead('feed_sales');
    
    // सकल लाभ (Gross Profit) = कुल बिक्री - कुल खरीद
    double totalTradingSales = milkSales + cattleFeedSales;
    double totalTradingPurchase = milkPurchase + cattleFeedPurchase;
    double grossProfit = totalTradingSales - totalTradingPurchase;

    // 2. लाभ-हानि खाते की मदें
    double establishmentExpense = await sumByHead('establishment_expense');
    double auditFeeProvision = await sumByHead('audit_fee_provision');
    double miscIncome = await sumByHead('miscellaneous_income');

    // शुद्ध लाभ (Net Profit) = सकल लाभ + अन्य आय - अप्रत्यक्ष खर्चे
    double netProfit = (grossProfit > 0 ? grossProfit : 0.0) + miscIncome - (establishmentExpense + auditFeeProvision);

    // 3. आय-व्यय खाता / कैश बुक (Receipts & Payments)
    double openingCash = await sumByHead('opening_cash');
    
    final recRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM master_ledger WHERE society_id = ? AND type = 'CREDIT'", [societyId]);
    double totalReceipts = (recRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final payRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM master_ledger WHERE society_id = ? AND type = 'DEBIT'", [societyId]);
    double totalPayments = (payRes.first['total'] as num?)?.toDouble() ?? 0.0;

    double closingCash = (openingCash + totalReceipts) - totalPayments;

    // 4. संतुलन चित्र (Balance Sheet) की मदें
    double shareCapital = await sumByHead('share_capital');
    double dairyDebtors = await sumByHead('dairy_debtors');

    return {
      'milkPurchase': milkPurchase,
      'milkSales': milkSales,
      'feedPurchase': cattleFeedPurchase,
      'feedSales': cattleFeedSales,
      'grossProfit': grossProfit,
      'establishmentExpense': establishmentExpense,
      'auditFee': auditFeeProvision,
      'miscIncome': miscIncome,
      'netProfit': netProfit,
      'openingCash': openingCash,
      'closingCash': closingCash,
      'shareCapital': shareCapital,
      'dairyDebtors': dairyDebtors,
    };
  }

  // ==========================================
  //  🏢 सोसायटी और फाइल प्रोसेसिंग
  // ==========================================
  Future<int> insertSociety(Map<String, dynamic> row) async { 
    final db = await database; 
    return await db.insert('societies', row); 
  }
  
  Future<List<Map<String, dynamic>>> queryAllSocieties() async { 
    final db = await database; 
    return await db.query('societies', orderBy: 'id DESC'); 
  }
  
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
  //  🚨 AI ऑडिट अलर्ट्स / विसंगतियां (Doubts)
  // ==========================================
  Future<int> insertDocumentDoubt(Map<String, dynamic> doubtData) async { 
    final db = await database; 
    return await db.insert('document_doubts', doubtData); 
  }
  
  Future<List<Map<String, dynamic>>> getDoubtsBySociety(int societyId) async { 
    final db = await database; 
    return await db.query('document_doubts', where: 'society_id = ?', whereArgs: [societyId], orderBy: 'id DESC'); 
  }

  // 🔥 फिक्स: CI/CD बिल्ड को क्रैश होने से बचाने के लिए 'queryDocumentDoubts' का एलियास (Alias) मेथड
  Future<List<Map<String, dynamic>>> queryDocumentDoubts(int societyId) async {
    return await getDoubtsBySociety(societyId);
  }
}
