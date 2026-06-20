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
      // 1. Core Business (Trading)
      LedgerItem(name: "Opening Stock", amount: 0, category: "Trading_Dr_Only"),
      LedgerItem(name: "Milk Buy", amount: 0, category: "Core_Dr"), 
      LedgerItem(name: "Milk Sell", amount: 0, category: "Core_Cr"), 
      LedgerItem(name: "Ghee Buy", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Ghee Sell", amount: 0, category: "Core_Cr"),
      LedgerItem(name: "Seed Buy", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Seed Sell", amount: 0, category: "Core_Cr"),
      LedgerItem(name: "Head load", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Closing Stock", amount: 0, category: "Trading_Cr_Asset"),
      
      // 2. Expenses (P&L Debit)
      LedgerItem(name: "Salary", amount: 0, category: "Expense"),
      LedgerItem(name: "Stationary", amount: 0, category: "Expense"),
      LedgerItem(name: "Audit fee", amount: 0, category: "Expense"),
      LedgerItem(name: "Insurance premium", amount: 0, category: "Expense"),
      LedgerItem(name: "Interest Paid", amount: 0, category: "Expense"),
      LedgerItem(name: "Over head loss", amount: 0, category: "Expense"),
      LedgerItem(name: "Commission Paid", amount: 0, category: "Expense"),
      LedgerItem(name: "Depreciation", amount: 0, category: "Expense_NonCash"),

      // 3. Income (P&L Credit)
      LedgerItem(name: "Interest Received", amount: 0, category: "Income"),
      LedgerItem(name: "Commission Received", amount: 0, category: "Income"),

      // 4. Assets & Liabilities
      LedgerItem(name: "Fixed Assets", amount: 0, category: "Asset"),
      LedgerItem(name: "Loan", amount: 0, category: "Liability"),
      LedgerItem(name: "Debenture", amount: 0, category: "Liability"),
      LedgerItem(name: "Previous Year Profit", amount: 0, category: "Liability_NonCash"),
      
      // 5. Cash/Bank (Opening/Closing)
      LedgerItem(name: "Opening Cash/Bank", amount: 0, category: "Opening_Bal"), 
      LedgerItem(name: "Cash in hand", amount: 0, category: "Cash_Asset"),
      LedgerItem(name: "Cash at Bank", amount: 0, category: "Cash_Asset"),
    ];
  }

  void addCustomItem(String name, double amount, String category) {
    items.add(LedgerItem(name: name, amount: amount, category: category));
  }

  // 1. Receipts & Payments
  // Logic: Receipt side में Capital, Loan, Sales और Income जुड़ेंगे। 
  // Payment side में Purchases और Expenses जुड़ेंगे।
  double get totalReceipts => items.where((i) => ['Opening_Bal', 'Core_Cr', 'Income', 'Liability'].contains(i.category)).fold(0, (s, i) => s + i.amount);
  double get totalPayments => items.where((i) => ['Core_Dr', 'Expense'].contains(i.category)).fold(0, (s, i) => s + i.amount);
  double get closingCashBal => totalReceipts - totalPayments; 

  // 2. Trading Account
  double get grossProfit {
    double dr = items.where((i) => ['Core_Dr', 'Trading_Dr_Only'].contains(i.category)).fold(0, (s, i) => s + i.amount);
    double cr = items.where((i) => ['Core_Cr', 'Trading_Cr_Asset'].contains(i.category)).fold(0, (s, i) => s + i.amount);
    return cr - dr;
  }

  // 3. Profit & Loss Account
  double get netProfit {
    double exp = items.where((i) => i.category == 'Expense').fold(0, (s, i) => s + i.amount);
    double inc = items.where((i) => i.category == 'Income').fold(0, (s, i) => s + i.amount);
    return grossProfit + inc - exp;
  }

  // 4. Balance Sheet
  Map<String, double> get balanceSheetTotals {
    // Assets = Fixed Assets + Closing Stock + Actual Cash/Bank
    double closingStock = items.firstWhere((i) => i.name == "Closing Stock", orElse: () => LedgerItem(name: "", amount: 0, category: "")).amount;
    double fixedAssets = items.where((i) => i.category == 'Asset').fold(0, (s, i) => s + i.amount);
    double dep = items.where((i) => i.category == 'Expense_NonCash').fold(0, (s, i) => s + i.amount);
    
    double totalAssets = (fixedAssets - dep) + closingStock + closingCashBal;

    // Liabilities = Loan + Debenture + Previous Year Profit + Current Net Profit
    double liabilities = items.where((i) => ['Liability', 'Liability_NonCash'].contains(i.category)).fold(0, (s, i) => s + i.amount);
    double totalLiabilities = liabilities + netProfit;

    return {"Total Assets": totalAssets, "Total Liabilities": totalLiabilities};
  }
}
