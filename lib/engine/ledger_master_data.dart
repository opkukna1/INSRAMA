// lib/engine/ledger_master_data.dart

class LedgerMapping {
  String ledgerName;
  String groupName;
  String? accountHead; // 🔥 फिक्स: AI और डेटाबेस के टेक्निकल नाम को सिंक करने के लिए नया फील्ड
  String? rpType;     // 'Receipt' या 'Payment'
  String? trading;    // 'Dr' या 'Cr'
  String? pnl;        // 'Income' या 'Expense'
  String? bs;         // 'Asset', 'Liability', 'Capital', 'Reserve', 'Current Asset', 'Current Liability'
  
  // UI State के लिए
  bool isActive;
  double amount;

  LedgerMapping({
    required this.ledgerName,
    required this.groupName,
    this.accountHead, // 🔥 जोड़ा गया
    this.rpType,
    this.trading,
    this.pnl,
    this.bs,
    this.isActive = false,
    this.amount = 0.0,
  });
}

// यह आपकी दी गई पूरी लिस्ट का मास्टर डेटा है (अपग्रेडेड विद दुग्ध बिल वर्गीकरण)
class LedgerMasterDatabase {
  static List<LedgerMapping> getAllLedgers() {
    return [
      // 1. MILK BUSINESS HEADS (दुग्ध व्यवसाय खाते)
      LedgerMapping(ledgerName: "Milk Purchase", accountHead: "milk_purchase", groupName: "Milk Business", rpType: "Payment", trading: "Dr", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Milk Sale", accountHead: "milk_sales", groupName: "Milk Business", rpType: "Receipt", trading: "Cr", bs: "Current Asset"),
      LedgerMapping(ledgerName: "Milk Collection Charges", groupName: "Milk Business", rpType: "Payment", trading: "Dr"),
      LedgerMapping(ledgerName: "Milk Testing Charges", groupName: "Milk Business", rpType: "Payment", trading: "Dr"),
      LedgerMapping(ledgerName: "Transport Charges", groupName: "Milk Business", rpType: "Payment", trading: "Dr"),

      // 🌟 दुग्ध बिल का संपूर्ण वर्गीकरण (NEW BREAKDOWN HEADS ADDED HERE)
      LedgerMapping(ledgerName: "Head Load Income", accountHead: "head_load", groupName: "Milk Business", rpType: "Receipt", pnl: "Income"), 
      LedgerMapping(ledgerName: "Overhead Income", accountHead: "overhead_load", groupName: "Milk Business", rpType: "Receipt", pnl: "Income"),
      LedgerMapping(ledgerName: "Ghee Katoti Stock", accountHead: "ghee_katoti", groupName: "Milk Business", rpType: "Payment", trading: "Dr", bs: "Current Liability"),

      // 2. FEED BUSINESS (पशु आहार खाते)
      LedgerMapping(ledgerName: "Feed Purchase", accountHead: "feed_purchase", groupName: "Feed Business", rpType: "Payment", trading: "Dr", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Feed Sale", accountHead: "feed_sales", groupName: "Feed Business", rpType: "Receipt", trading: "Cr", bs: "Current Asset"),
      LedgerMapping(ledgerName: "Feed Transport", groupName: "Feed Business", rpType: "Payment", trading: "Dr"),

      // 5. STOCK (Opening / Closing)
      LedgerMapping(ledgerName: "Opening Stock Milk", groupName: "Stock & Inventory", trading: "Dr"),
      LedgerMapping(ledgerName: "Closing Stock Milk", groupName: "Stock & Inventory", trading: "Cr", bs: "Current Asset"),

      // 6. ADMIN EXPENSES (प्रशासनिक खर्चे)
      LedgerMapping(ledgerName: "Salary", accountHead: "establishment_expense", groupName: "Administrative Expenses", rpType: "Payment", pnl: "Expense", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Electricity", groupName: "Administrative Expenses", rpType: "Payment", pnl: "Expense", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Audit Fees", accountHead: "audit_fee_provision", groupName: "Administrative Expenses", rpType: "Payment", pnl: "Expense", bs: "Current Liability"),
      LedgerMapping(ledgerName: "Bank Charges", groupName: "Administrative Expenses", pnl: "Expense"), 

      // 8. OTHER INCOME (अन्य आय)
      LedgerMapping(ledgerName: "Bank Interest", groupName: "Other Income", rpType: "Receipt", pnl: "Income"),
      LedgerMapping(ledgerName: "Membership Fee", groupName: "Other Income", rpType: "Receipt", pnl: "Income"),

      // 9. FIXED ASSETS (अचल संपत्ति)
      LedgerMapping(ledgerName: "Building", groupName: "Fixed Assets", rpType: "Payment", bs: "Fixed Asset"),
      LedgerMapping(ledgerName: "Computer", groupName: "Fixed Assets", rpType: "Payment", bs: "Fixed Asset"),
      
      // 11. CURRENT ASSETS (नकद एवं बैंक बैलेंस)
      LedgerMapping(ledgerName: "Opening Cash", groupName: "Cash & Bank Balances", rpType: "Receipt", bs: "Current Asset"),
      LedgerMapping(ledgerName: "Opening Bank", groupName: "Cash & Bank Balances", rpType: "Receipt", bs: "Current Asset"),

      // 12. CAPITAL & RESERVES (पूंजी एवं संचय)
      LedgerMapping(ledgerName: "Share Capital", accountHead: "share_capital", groupName: "Capital & Reserves", rpType: "Receipt", bs: "Capital"),
      LedgerMapping(ledgerName: "Reserve Fund", groupName: "Capital & Reserves", bs: "Reserve"),
      LedgerMapping(ledgerName: "Dairy Union Debtors", accountHead: "dairy_debtors", groupName: "Capital & Reserves", rpType: "DEBIT", bs: "Current Asset"),
    ];
  }
}
