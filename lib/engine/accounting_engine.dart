// lib/engine/accounting_engine.dart

class LedgerItem {
  final String name;
  double amount;
  final String category; // 'Core', 'Expense', 'Income', 'Asset', 'Liability', 'Cash'
  
  LedgerItem({required this.name, required this.amount, required this.category});
}

class AccountingEngine {
  List<LedgerItem> items = [];

  // डिफ़ॉल्ट आइटम्स जो स्क्रीन पर पहले से दिखेंगे
  void initializeDefaultItems() {
    items = [
      // Core Business
      LedgerItem(name: "Milk Buy", amount: 0, category: "Core_Dr"), // Trading Dr / Payment
      LedgerItem(name: "Milk Sell", amount: 0, category: "Core_Cr"), // Trading Cr / Receipt
      LedgerItem(name: "Ghee Buy", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Ghee Sell", amount: 0, category: "Core_Cr"),
      LedgerItem(name: "Seed Buy", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Seed Sell", amount: 0, category: "Core_Cr"),
      LedgerItem(name: "Head load", amount: 0, category: "Core_Dr"),
      LedgerItem(name: "Opening Stock", amount: 0, category: "Trading_Dr_Only"),
      LedgerItem(name: "Closing Stock", amount: 0, category: "Trading_Cr_Asset"),
      
      // Expenses (P&L Debit)
      LedgerItem(name: "Salary", amount: 0, category: "Expense"),
      LedgerItem(name: "Stationary", amount: 0, category: "Expense"),
      LedgerItem(name: "Audit fee", amount: 0, category: "Expense"),
      LedgerItem(name: "Insurance premium", amount: 0, category: "Expense"),
      LedgerItem(name: "Interest Paid", amount: 0, category: "Expense"),
      LedgerItem(name: "Over head loss", amount: 0, category: "Expense"),
      LedgerItem(name: "Commission Paid", amount: 0, category: "Expense"),
      LedgerItem(name: "Depreciation", amount: 0, category: "Expense_NonCash"),

      // Income (P&L Credit)
      LedgerItem(name: "Interest Received", amount: 0, category: "Income"),
      LedgerItem(name: "Commission Received", amount: 0, category: "Income"),

      // Assets & Cash
      LedgerItem(name: "Fixed Assets", amount: 0, category: "Asset"),
      LedgerItem(name: "Cash in hand", amount: 0, category: "Cash_Asset"),
      LedgerItem(name: "Cash at Bank", amount: 0, category: "Cash_Asset"),

      // Liabilities & Previous Year
      LedgerItem(name: "Loan", amount: 0, category: "Liability"),
      LedgerItem(name: "Debenture", amount: 0, category: "Liability"),
      LedgerItem(name: "Previous Year Profit", amount: 0, category: "Liability"),
    ];
  }

  // कोई नया मैन्युअल आइटम जोड़ने के लिए
  void addCustomItem(String name, double amount, String category) {
    items.add(LedgerItem(name: name, amount: amount, category: category));
  }

  // === 4 खातों का ऑटोमैटिक कैलकुलेशन ===

  // 1. Trading Account (Gross Profit)
  double get grossProfit {
    double drTotal = items.where((i) => i.category == 'Core_Dr' || i.category == 'Trading_Dr_Only').fold(0, (sum, i) => sum + i.amount);
    double crTotal = items.where((i) => i.category == 'Core_Cr' || i.category == 'Trading_Cr_Asset').fold(0, (sum, i) => sum + i.amount);
    return crTotal - drTotal; // अगर प्लस है तो Gross Profit, माइनस है तो Gross Loss
  }

  // 2. Profit & Loss Account (Net Profit)
  double get netProfit {
    double expenseTotal = items.where((i) => i.category.contains('Expense')).fold(0, (sum, i) => sum + i.amount);
    double incomeTotal = items.where((i) => i.category == 'Income').fold(0, (sum, i) => sum + i.amount);
    return grossProfit + incomeTotal - expenseTotal;
  }

  // 3. Balance Sheet Matching Check
  Map<String, double> get balanceSheet {
    double assets = items.where((i) => i.category == 'Asset' || i.category == 'Cash_Asset' || i.category == 'Trading_Cr_Asset').fold(0, (sum, i) => sum + i.amount);
    
    // Depreciation एसेट्स में से माइनस होता है
    double depreciation = items.where((i) => i.category == 'Expense_NonCash').fold(0, (sum, i) => sum + i.amount);
    assets -= depreciation;

    double liabilities = items.where((i) => i.category == 'Liability').fold(0, (sum, i) => sum + i.amount);
    
    // Net profit हमेशा Liability साइड (Capital में) जुड़ता है
    liabilities += netProfit;

    return {"Total Assets": assets, "Total Liabilities": liabilities};
  }
}
