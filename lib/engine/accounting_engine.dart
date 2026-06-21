// lib/engine/accounting_engine.dart

class LedgerItem {
  final String name;
  double amount;
  final String category; 
  
  LedgerItem({required this.name, required this.amount, required this.category});
}

class AccountingEngine {
  List<LedgerItem> items = [];

  void addCustomItem(String name, double amount, String category) {
    items.add(LedgerItem(name: name, amount: amount, category: category));
  }

  // ==========================================
  // 🧮 1. Receipts and Payments Account Data
  // ==========================================
  
  // PDF टेबल के लिए लिस्ट्स
  List<LedgerItem> get receipts => items.where((i) => i.amount > 0 && ['Opening_Cash', 'Core_Cr', 'Income', 'Receipt_Liability', 'Receipt_Only'].contains(i.category)).toList();
  List<LedgerItem> get payments => items.where((i) => i.amount > 0 && ['Core_Dr', 'Direct_Expense', 'Expense', 'Payment_Asset', 'Payment_Only'].contains(i.category)).toList();
  
  // टोटल्स
  double get totalReceipts => receipts.fold(0.0, (sum, i) => sum + i.amount);
  double get totalPayments => payments.fold(0.0, (sum, i) => sum + i.amount);
  double get closingCashBal => totalReceipts - totalPayments; // 🌟 Auto-Calculated Cash Balance

  // ==========================================
  // 🧮 2. Trading Account Data
  // ==========================================
  
  // PDF टेबल के लिए लिस्ट्स (यहीं पर एरर आ रहा था)
  List<LedgerItem> get tradingDr => items.where((i) => i.amount > 0 && ['Opening_Stock', 'Core_Dr', 'Direct_Expense'].contains(i.category)).toList();
  List<LedgerItem> get tradingCr => items.where((i) => i.amount > 0 && ['Core_Cr', 'Closing_Stock', 'Stock_Loss'].contains(i.category)).toList();
  
  double get grossProfit {
    double dr = tradingDr.fold(0.0, (sum, i) => sum + i.amount);
    double cr = tradingCr.fold(0.0, (sum, i) => sum + i.amount);
    return cr - dr; 
  }

  // ==========================================
  // 🧮 3. Profit & Loss Account Data
  // ==========================================
  
  // PDF टेबल के लिए लिस्ट्स
  List<LedgerItem> get pnlDr => items.where((i) => i.amount > 0 && ['Expense', 'Depreciation', 'Stock_Loss'].contains(i.category)).toList();
  List<LedgerItem> get pnlCr => items.where((i) => i.amount > 0 && ['Income'].contains(i.category)).toList();
  
  double get netProfit {
    double exp = pnlDr.fold(0.0, (sum, i) => sum + i.amount);
    double inc = pnlCr.fold(0.0, (sum, i) => sum + i.amount);
    return grossProfit + inc - exp;
  }

  // ==========================================
  // 🧮 4. Balance Sheet Data
  // ==========================================
  
  // PDF टेबल के लिए लिस्ट्स
  List<LedgerItem> get liabilities => items.where((i) => i.amount > 0 && ['Liability', 'Receipt_Liability', 'Prev_Profit'].contains(i.category)).toList();
  List<LedgerItem> get assets => items.where((i) => i.amount > 0 && ['Asset', 'Payment_Asset', 'Closing_Stock', 'Prev_Loss'].contains(i.category)).toList();

  Map<String, double> get balanceSheetTotals {
    double ast = assets.fold(0.0, (sum, i) => sum + i.amount);
    
    // 🌟 Double Entry Automations:
    ast += closingCashBal; // 1. Closing Cash/Bank automatically added to Assets
    double dep = items.where((i) => i.category == 'Depreciation').fold(0.0, (sum, i) => sum + i.amount);
    ast -= dep; // 2. Depreciation automatically subtracted from Assets

    double lib = liabilities.fold(0.0, (sum, i) => sum + i.amount);
    lib += netProfit; // 3. Net Profit automatically added to Liabilities (Capital)

    return {"Total Assets": ast, "Total Liabilities": lib};
  }
}
