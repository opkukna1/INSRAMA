// lib/screens/manual_ledger_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/accounting_engine.dart';
import '../services/pdf_export_service.dart';
import '../database/db_helper.dart';

class SmartItem {
  String name;
  String group;
  String engineCategory;
  bool isActive;
  double amount;

  SmartItem({required this.name, required this.group, required this.engineCategory, this.isActive = false, this.amount = 0.0});
}

class ManualLedgerScreen extends StatefulWidget {
  const ManualLedgerScreen({super.key});

  @override
  State<ManualLedgerScreen> createState() => _ManualLedgerScreenState();
}

class _ManualLedgerScreenState extends State<ManualLedgerScreen> {
  final AccountingEngine engine = AccountingEngine();
  
  String selectedSocietyType = "Milk"; 
  String selectedYear = "2024-25";      
  
  final List<String> societyTypes = ["Milk", "Women", "GSS", "Agriculture"];
  final List<String> years = ["2023-24", "2024-25", "2025-26", "2026-27"];

  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;

  List<SmartItem> allItems = [];
  Map<String, List<SmartItem>> groupedItems = {};

  @override
  void initState() {
    super.initState();
    _initMasterData();
    _loadSocieties();
  }

  void _initMasterData() {
    allItems = [
      // 1. BUY (खरीद)
      SmartItem(name: "Milk Buy", group: "1. BUY (खरीद)", engineCategory: "Core_Dr"),
      SmartItem(name: "Ghee Buy", group: "1. BUY (खरीद)", engineCategory: "Core_Dr"),
      SmartItem(name: "Feed Buy", group: "1. BUY (खरीद)", engineCategory: "Core_Dr"),
      SmartItem(name: "Sweet Buy", group: "1. BUY (खरीद)", engineCategory: "Core_Dr"),

      // 2. SELL (बिक्री)
      SmartItem(name: "Milk Sell", group: "2. SELL (बिक्री)", engineCategory: "Core_Cr"),
      SmartItem(name: "Ghee Sell", group: "2. SELL (बिक्री)", engineCategory: "Core_Cr"),
      SmartItem(name: "Feed Sell", group: "2. SELL (बिक्री)", engineCategory: "Core_Cr"),
      SmartItem(name: "Sweet Sell", group: "2. SELL (बिक्री)", engineCategory: "Core_Cr"),

      // 3. EXPENSES (खर्चे)
      SmartItem(name: "Salary", group: "3. EXPENSES (खर्चे)", engineCategory: "Expense"),
      SmartItem(name: "Electricity", group: "3. EXPENSES (खर्चे)", engineCategory: "Expense"),
      SmartItem(name: "Audit Fees", group: "3. EXPENSES (खर्चे)", engineCategory: "Expense"),
      SmartItem(name: "Stationary & Printing", group: "3. EXPENSES (खर्चे)", engineCategory: "Expense"),
      SmartItem(name: "Repairs & Maint.", group: "3. EXPENSES (खर्चे)", engineCategory: "Expense"),
      SmartItem(name: "Transport Charges", group: "3. EXPENSES (खर्चे)", engineCategory: "Direct_Expense"), // Trading Dr

      // 4. INCOME (आय)
      SmartItem(name: "Commission Received", group: "4. INCOME (आय)", engineCategory: "Income"),
      SmartItem(name: "Head Load Recovery", group: "4. INCOME (आय)", engineCategory: "Income"),
      SmartItem(name: "Overheads Recovery", group: "4. INCOME (आय)", engineCategory: "Income"),
      SmartItem(name: "Interest Received", group: "4. INCOME (आय)", engineCategory: "Income"),

      // 5. RECEIPTS (नकद प्राप्तियां)
      SmartItem(name: "Share Capital Received", group: "5. RECEIPTS (प्राप्तियां)", engineCategory: "Receipt_Liability"),
      SmartItem(name: "Loan Received", group: "5. RECEIPTS (प्राप्तियां)", engineCategory: "Receipt_Liability"),
      SmartItem(name: "Advance Recovery", group: "5. RECEIPTS (प्राप्तियां)", engineCategory: "Receipt_Only"),

      // 6. PAYMENTS (नकद भुगतान)
      SmartItem(name: "Asset Purchase", group: "6. PAYMENTS (भुगतान)", engineCategory: "Payment_Asset"),
      SmartItem(name: "Loan Repayment", group: "6. PAYMENTS (भुगतान)", engineCategory: "Payment_Only"),
      SmartItem(name: "FD Deposit", group: "6. PAYMENTS (भुगतान)", engineCategory: "Payment_Asset"),

      // 7. ASSETS (सम्पत्तियां)
      SmartItem(name: "Building & Machines", group: "7. ASSETS (सम्पत्तियां)", engineCategory: "Asset"),
      SmartItem(name: "Furniture", group: "7. ASSETS (सम्पत्तियां)", engineCategory: "Asset"),
      SmartItem(name: "Debtors (लेनदारी)", group: "7. ASSETS (सम्पत्तियां)", engineCategory: "Asset"),

      // 8. LIABILITIES (दायित्व)
      SmartItem(name: "Creditors (देनदारी)", group: "8. LIABILITIES (दायित्व)", engineCategory: "Liability"),
      SmartItem(name: "Payables (बकाया खर्चे)", group: "8. LIABILITIES (दायित्व)", engineCategory: "Liability"),

      // 9. STOCKS (स्टॉक)
      SmartItem(name: "Opening Stock", group: "9. STOCKS (स्टॉक)", engineCategory: "Opening_Stock"),
      SmartItem(name: "Closing Stock", group: "9. STOCKS (स्टॉक)", engineCategory: "Closing_Stock"),
      SmartItem(name: "Stock Loss / Theft", group: "9. STOCKS (स्टॉक)", engineCategory: "Stock_Loss"),

      // 10. PREVIOUS YEAR (गत वर्ष)
      SmartItem(name: "Previous Year Profit", group: "10. PREVIOUS YEAR (गत वर्ष)", engineCategory: "Prev_Profit"),
      SmartItem(name: "Previous Year Loss", group: "10. PREVIOUS YEAR (गत वर्ष)", engineCategory: "Prev_Loss"),

      // 11. DEPRECIATION (मूल्यह्रास)
      SmartItem(name: "Depreciation", group: "11. DEPRECIATION (मूल्यह्रास)", engineCategory: "Depreciation"),

      // 12. OPENING CASH (प्रारम्भिक रोकड़)
      SmartItem(name: "Opening Cash & Bank", group: "12. OPENING CASH", engineCategory: "Opening_Cash"),
    ];
    _groupItems();
  }

  void _groupItems() {
    groupedItems.clear();
    for (var item in allItems) {
      if (!groupedItems.containsKey(item.group)) {
        groupedItems[item.group] = [];
      }
      groupedItems[item.group]!.add(item);
    }
  }

  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    if (!mounted) return;
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) _selectedSocietyId = _societies.first['id'];
    });
  }

  void _showCustomItemDialog() {
    String newName = "";
    double newAmount = 0;
    String selectedCategory = "Expense"; 

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("कस्टम आइटम जोड़ें", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(decoration: const InputDecoration(labelText: "आइटम का नाम"), onChanged: (val) => newName = val),
                TextField(decoration: const InputDecoration(labelText: "राशि (₹)"), keyboardType: TextInputType.number, onChanged: (val) => newAmount = double.tryParse(val) ?? 0),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'खाता श्रेणी'),
                  items: ["Income", "Expense", "Core_Dr", "Core_Cr", "Asset", "Liability"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("रद्द करें")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                onPressed: () {
                  if (newName.isNotEmpty) {
                    setState(() {
                      allItems.add(SmartItem(name: newName, group: "13. CUSTOM ITEMS", engineCategory: selectedCategory, isActive: true, amount: newAmount));
                      _groupItems();
                    });
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text("जोड़ें"),
              )
            ],
          );
        });
      }
    );
  }

  // 🚀 Excel/CSV Export Feature
  Future<void> _exportToCSV() async {
    List<SmartItem> activeItems = allItems.where((i) => i.isActive && i.amount > 0).toList();
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("एक्सपोर्ट करने के लिए कोई डेटा नहीं है!")));
      return;
    }

    String csvData = "Group,Item Name,Category,Amount\n";
    for (var item in activeItems) {
      csvData += '"${item.group}","${item.name}","${item.engineCategory}",${item.amount}\n';
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Manual_Ledger_$selectedYear.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: "Manual Ledger Data for $selectedYear");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Exporting CSV: $e")));
    }
  }

  void _generateAndShareAccounts() {
    engine.items.clear();
    List<SmartItem> activeItems = allItems.where((i) => i.isActive && i.amount > 0).toList();
    
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("कृपया कोई आइटम चालू (Toggle ON) करें और राशि भरें!")));
      return;
    }

    for (var item in activeItems) {
      engine.addCustomItem(item.name, item.amount, item.engineCategory);
    }

    double gp = engine.grossProfit;
    double np = engine.netProfit;
    var bs = engine.balanceSheetTotals;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("📊 4-Stage Automated Accounts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            
            Text("1. Cash/Bank Closing Bal: ₹${engine.closingCashBal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("2. Gross Profit (Trading): ₹${gp.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("3. Net Profit (P&L): ₹${np.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text("4. Balance Sheet Match Check:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text("   Liabilities Total: ₹${bs['Total Liabilities']?.toStringAsFixed(2)}"),
            Text("   Assets Total: ₹${bs['Total Assets']?.toStringAsFixed(2)}"),
            
            const SizedBox(height: 10),
            if (bs['Total Liabilities'] == bs['Total Assets'])
              Container(padding: const EdgeInsets.all(8), color: Colors.green.shade50, child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width:8), Text("Balance Sheet Tally Passed!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]))
            else
              Container(padding: const EdgeInsets.all(8), color: Colors.red.shade50, child: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width:8), Text("Mismatch! Check closing cash/stock.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))])),

            const Spacer(),
            
            // 🚀 Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.table_chart),
                    label: const Text("CSV Excel"),
                    onPressed: _exportToCSV, // 🌟 नया CSV एक्सपोर्ट फंक्शन
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("T-Shape PDF"),
                    onPressed: () {
                      String societyName = _societies.isNotEmpty && _selectedSocietyId != null ? _societies.firstWhere((s) => s['id'] == _selectedSocietyId)['name'] : "Society";
                      PdfExportService.generateAndShareManualAccounts(engine, societyName, selectedYear);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keys को Sort करने के लिए कस्टम लॉजिक ताकि '10.', '11.' सही जगह आएं
    List<String> groupKeys = groupedItems.keys.toList()
      ..sort((a, b) => int.parse(a.split('.')[0]).compareTo(int.parse(b.split('.')[0])));

    return Scaffold(
      appBar: AppBar(
        title: const Text("स्मार्ट मैन्युअल लेज़र"),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedSocietyId,
                  decoration: const InputDecoration(labelText: "समिति चुनें", border: OutlineInputBorder(), isDense: true, fillColor: Colors.white, filled: true),
                  items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
                  onChanged: (val) => setState(() => _selectedSocietyId = val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selectedSocietyType,
                      decoration: const InputDecoration(labelText: "समिति का प्रकार", border: OutlineInputBorder(), isDense: true, fillColor: Colors.white, filled: true),
                      items: societyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => selectedSocietyType = val!),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selectedYear,
                      decoration: const InputDecoration(labelText: "ऑडिट वर्ष", border: OutlineInputBorder(), isDense: true, fillColor: Colors.white, filled: true),
                      items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => selectedYear = val!),
                    )),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: groupKeys.length,
              itemBuilder: (context, index) {
                String groupName = groupKeys[index];
                List<SmartItem> items = groupedItems[groupName]!;
                bool anyActive = items.any((i) => i.isActive);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: anyActive ? 3 : 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: anyActive ? Colors.green.shade300 : Colors.transparent)),
                  child: ExpansionTile(
                    initiallyExpanded: anyActive,
                    title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold, color: anyActive ? Colors.green.shade800 : Colors.black87)),
                    children: items.map((item) {
                      return Container(
                        color: item.isActive ? Colors.green.shade50 : Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          title: Text(item.name, style: TextStyle(fontSize: 14, fontWeight: item.isActive ? FontWeight.bold : FontWeight.normal)),
                          value: item.isActive,
                          activeColor: Colors.green.shade700,
                          onChanged: (val) {
                            setState(() {
                              item.isActive = val;
                              if (!val) item.amount = 0.0;
                            });
                          },
                          secondary: SizedBox(
                            width: 130, 
                            child: TextField(
                              enabled: item.isActive,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: "₹ ", 
                                border: const OutlineInputBorder(),
                                isDense: true,
                                fillColor: item.isActive ? Colors.white : Colors.grey.shade200,
                                filled: true,
                              ),
                              onChanged: (v) => item.amount = double.tryParse(v) ?? 0
                            )
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "addBtn",
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            onPressed: _showCustomItemDialog,
            tooltip: "Add Custom Item",
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "genBtn",
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.auto_awesome_mosaic_rounded),
            label: const Text("Generate Accounts", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _generateAndShareAccounts,
          ),
        ],
      ),
    );
  }
}
