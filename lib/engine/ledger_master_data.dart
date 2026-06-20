// lib/engine/ledger_master_data.dart

class LedgerMapping {
  String ledgerName;
  String groupName;
  String? rpType;     // 'Receipt' या 'Payment'
  String? trading;    // 'Dr' या 'Cr'
  String? pnl;        // 'Income' या 'Expense'
  String? bs;         // 'Asset', 'Liability', 'Capital', 'Reserve'
  
  // UI State के लिए
  bool isActive;
  double amount;

  LedgerMapping({
    required this.ledgerName,
    required this.groupName,
    this.rpType,
    this.trading,
    this.pnl,
    this.bs,
    this.isActive = false,
    this.amount = 0.0,
  });
}

// यह आपकी दी गई पूरी लिस्ट का मास्टर डेटा है
class LedgerMasterDatabase {
  static List<LedgerMapping> getAllLedgers() {
    return [
      // 1. MILK BUSINESS HEADS
      LedgerMapping(ledgerName: "Milk Purchase", groupName: "Milk Business", rpType: "Payment", trading: "Dr", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Milk Sale", groupName: "Milk Business", rpType: "Receipt", trading: "Cr", bs: "Current Asset"),
      LedgerMapping(ledgerName: "Milk Collection Charges", groupName: "Milk Business", rpType: "Payment", trading: "Dr"),
      LedgerMapping(ledgerName: "Milk Testing Charges", groupName: "Milk Business", rpType: "Payment", trading: "Dr"),
      LedgerMapping(ledgerName: "Transport Charges", groupName: "Milk Business", rpType: "Payment", trading: "Dr"),

      // 2. FEED BUSINESS
      LedgerMapping(ledgerName: "Feed Purchase", groupName: "Feed Business", rpType: "Payment", trading: "Dr", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Feed Sale", groupName: "Feed Business", rpType: "Receipt", trading: "Cr", bs: "Current Asset"),
      LedgerMapping(ledgerName: "Feed Transport", groupName: "Feed Business", rpType: "Payment", trading: "Dr"),

      // 5. STOCK (Opening / Closing)
      LedgerMapping(ledgerName: "Opening Stock Milk", groupName: "Stock & Inventory", trading: "Dr"),
      LedgerMapping(ledgerName: "Closing Stock Milk", groupName: "Stock & Inventory", trading: "Cr", bs: "Current Asset"),

      // 6. ADMIN EXPENSES
      LedgerMapping(ledgerName: "Salary", groupName: "Administrative Expenses", rpType: "Payment", pnl: "Expense", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Electricity", groupName: "Administrative Expenses", rpType: "Payment", pnl: "Expense", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Audit Fees", groupName: "Administrative Expenses", rpType: "Payment", pnl: "Expense", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Bank Charges", groupName: "Administrative Expenses", pnl: "Expense"), // Not typically a direct cash payment, deducted by bank

      // 8. OTHER INCOME
      LedgerMapping(ledgerName: "Bank Interest", groupName: "Other Income", rpType: "Receipt", pnl: "Income"),
      LedgerMapping(ledgerName: "Membership Fee", groupName: "Other Income", rpType: "Receipt", pnl: "Income"),

      // 9. FIXED ASSETS
      LedgerMapping(ledgerName: "Building", groupName: "Fixed Assets", rpType: "Payment", bs: "Fixed Asset"),
      LedgerMapping(ledgerName: "Computer", groupName: "Fixed Assets", rpType: "Payment", bs: "Fixed Asset"),
      
      // 11. CURRENT ASSETS (Cash & Bank)
      LedgerMapping(ledgerName: "Opening Cash", groupName: "Cash & Bank Balances", rpType: "Receipt", bs: "Current Asset"),
      LedgerMapping(ledgerName: "Opening Bank", groupName: "Cash & Bank Balances", rpType: "Receipt", bs: "Current Asset"),

      // 12. CAPITAL & RESERVES
      LedgerMapping(ledgerName: "Share Capital", groupName: "Capital & Reserves", rpType: "Receipt", bs: "Capital"),
      LedgerMapping(ledgerName: "Reserve Fund", groupName: "Capital & Reserves", bs: "Reserve"),
    ];
  }
}
