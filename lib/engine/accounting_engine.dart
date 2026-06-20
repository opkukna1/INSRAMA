// lib/engine/accounting_engine.dart

class LedgerItem {
  final String name;
  double amount;
  final String category; 
  
  LedgerItem({required this.name, required this.amount, required this.category});
}

class AccountingEngine {
  List<LedgerItem> items = [];

  void initializeDefaultItems() {
    items = [
      // 1. Receipts & Payments Specific
      LedgerItem(name: "Opening Cash/Bank", amount: 0, category: "Opening_Bal"), 
      
      // 2. Core Business (Trading)
      LedgerItem(name: "Opening Stock", amount: 0, category: "Trading_Dr_Only"),
      LedgerItem(name: "Milk Buy", amount: 0, category: "Core_Dr"), 
      LedgerItem(name: "Milk Sell", amount: 0, category: "Core_Cr"), 
      LedgerItem(name: "Ghee Buy", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Ghee Sell", amount: 0, category: "Core_Cr"),
      LedgerItem(name: "Seed Buy", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Seed Sell", amount: 0, category: "Core_Cr"),
      LedgerItem(name: "Head load", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Closing Stock", amount: 0, category: "Trading_Cr_Asset"),
      
      // 3. Expenses (P&L Debit)
      LedgerItem(name: "Salary", amount: 0, category: "Expense"),
      LedgerItem(name: "Stationary", amount: 0, category: "Expense"),
      LedgerItem(name: "Audit fee", amount: 0, category: "Expense"),
      LedgerItem(name: "Insurance premium", amount: 0, category: "Expense"),
      LedgerItem(name: "Interest Paid", amount: 0, category: "Expense"),
      LedgerItem(name: "Over head loss", amount: 0, category: "Expense"),
      LedgerItem(name: "Commission Paid", amount: 0, category: "Expense"),
      LedgerItem(name: "Depreciation", amount: 0, category: "Expense_NonCash"), // Non-cash, so not in Payments

      // 4. Income (P&L Credit)
      LedgerItem(name: "Interest Received", amount: 0, category: "Income"),
      LedgerItem(name: "Commission Received", amount: 0, category: "Income"),

      // 5. Assets & Cash (Closing)
      LedgerItem(name: "Fixed Assets", amount: 0, category: "Asset"),
      LedgerItem(name: "Cash in hand", amount: 0, category: "Cash_Asset"),
      LedgerItem(name: "Cash at Bank", amount: 0, category: "Cash_Asset"),

      // 6. Liabilities & Previous Year
      LedgerItem(name: "Loan", amount: 0, category: "Liability"),
      LedgerItem(name: "Debenture", amount: 0, category: "Liability"),
      LedgerItem(name: "Previous Year Profit", amount: 0, category: "Liability_NonCash"), // Non-cash
    ];
  }

  void addCustomItem(String name, double amount, String category) {
    items.add(LedgerItem(name: name, amount: amount, category: category));
  }

  // ==========================================
  // 🧮 1. Receipts and Payments Account Data
  // ==========================================
  List<LedgerItem> get receipts => items.where((i) => i.amount > 0 && ['Opening_Bal', 'Core_Cr', 'Income', 'Liability'].contains(i.category)).toList();
  List<LedgerItem> get payments => items.where((i) => i.amount > 0 && ['Core_Dr', 'Expense'].contains(i.category)).toList();
  double get totalReceipts => receipts.fold(0, (sum, i) => sum + i.amount);
  double get totalPayments => payments.fold(0, (sum, i) => sum + i.amount);
  double get closingCashBal => totalReceipts - totalPayments; // यह Closing Cash से मैच होना चाहिए

  // ==========================================
  // 🧮 2. Trading Account Data
  // ==========================================
  List<LedgerItem> get tradingDr => items.where((i) => i.amount > 0 && ['Core_Dr', 'Trading_Dr_Only'].contains(i.category)).toList();
  List<LedgerItem> get tradingCr => items.where((i) => i.amount > 0 && ['Core_Cr', 'Trading_Cr_Asset'].contains(i.category)).toList();
  
  double get grossProfit {
    double dr = tradingDr.fold(0, (sum, i) => sum + i.amount);
    double cr = tradingCr.fold(0, (sum, i) => sum + i.amount);
    return cr - dr; 
  }

  // ==========================================
  // 🧮 3. Profit & Loss Account Data
  // ==========================================
  List<LedgerItem> get pnlDr => items.where((i) => i.amount > 0 && ['Expense', 'Expense_NonCash'].contains(i.category)).toList();
  List<LedgerItem> get pnlCr => items.where((i) => i.amount > 0 && ['Income'].contains(i.category)).toList();
  
  double get netProfit {
    double exp = pnlDr.fold(0, (sum, i) => sum + i.amount);
    double inc = pnlCr.fold(0, (sum, i) => sum + i.amount);
    return grossProfit + inc - exp;
  }

  // ==========================================
  // 🧮 4. Balance Sheet Data
  // ==========================================
  List<LedgerItem> get liabilities => items.where((i) => i.amount > 0 && ['Liability', 'Liability_NonCash'].contains(i.category)).toList();
  List<LedgerItem> get assets => items.where((i) => i.amount > 0 && ['Asset', 'Cash_Asset', 'Trading_Cr_Asset'].contains(i.category)).toList();

  Map<String, double> get balanceSheetTotals {
    double ast = assets.fold(0, (sum, i) => sum + i.amount);
    double dep = items.where((i) => i.category == 'Expense_NonCash').fold(0, (sum, i) => sum + i.amount);
    ast -= dep; // Asset में से Depreciation घटाएं

    double lib = liabilities.fold(0, (sum, i) => sum + i.amount);
    lib += netProfit; // Net Profit लायबिलिटी साइड जुड़ेगा

    return {"Total Assets": ast, "Total Liabilities": lib};
  }
}
