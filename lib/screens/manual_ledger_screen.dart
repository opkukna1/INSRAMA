// lib/screens/manual_ledger_screen.dart
import 'package:flutter/material.dart';
import '../engine/accounting_engine.dart';
import '../services/pdf_export_service.dart';
import '../database/db_helper.dart';

// 🚀 स्मार्ट आइटम मॉडल जो UI और Accounting Engine को जोड़ेगा
class SmartItem {
  String name;
  String group;
  String engineCategory; // 'Core_Dr', 'Expense', 'Income', 'Asset', 'Liability' etc.
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
  
  final List<String> societyTypes = ["Milk", "Women", "GSS"];
  final List<String> years = ["2024-25", "2025-26", "2026-27"];

  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;

  // 🌟 आपकी 14-Groups वाली मास्टर लिस्ट
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
      // 1. MILK BUSINESS
      SmartItem(name: "Milk Purchase", group: "1. Milk Business", engineCategory: "Core_Dr"),
      SmartItem(name: "Milk Sale", group: "1. Milk Business", engineCategory: "Core_Cr"),
      SmartItem(name: "Milk Collection Charges", group: "1. Milk Business", engineCategory: "Core_Dr"),
      SmartItem(name: "Transport Charges", group: "1. Milk Business", engineCategory: "Core_Dr"),
      // 2. FEED BUSINESS
      SmartItem(name: "Feed Purchase", group: "2. Feed Business", engineCategory: "Core_Dr"),
      SmartItem(name: "Feed Sale", group: "2. Feed Business", engineCategory: "Core_Cr"),
      SmartItem(name: "Feed Transport", group: "2. Feed Business", engineCategory: "Core_Dr"),
      // 3. GHEE & SEED BUSINESS
      SmartItem(name: "Ghee Purchase", group: "3. Ghee & Seed Business", engineCategory: "Core_Dr"),
      SmartItem(name: "Ghee Sale", group: "3. Ghee & Seed Business", engineCategory: "Core_Cr"),
      SmartItem(name: "Seed Purchase", group: "3. Ghee & Seed Business", engineCategory: "Core_Dr"),
      SmartItem(name: "Seed Sale", group: "3. Ghee & Seed Business", engineCategory: "Core_Cr"),
      // 4. STOCK (Opening / Closing)
      SmartItem(name: "Opening Stock (Milk/Feed)", group: "4. Opening/Closing Stock", engineCategory: "Trading_Dr_Only"),
      SmartItem(name: "Closing Stock (Milk/Feed)", group: "4. Opening/Closing Stock", engineCategory: "Trading_Cr_Asset"),
      // 5. ADMINISTRATIVE EXPENSES
      SmartItem(name: "Salary / Honorarium", group: "5. Administrative Expenses", engineCategory: "Expense"),
      SmartItem(name: "Electricity / Water", group: "5. Administrative Expenses", engineCategory: "Expense"),
      SmartItem(name: "Audit Fees", group: "5. Administrative Expenses", engineCategory: "Expense"),
      SmartItem(name: "Stationery & Printing", group: "5. Administrative Expenses", engineCategory: "Expense"),
      SmartItem(name: "Bank Charges", group: "5. Administrative Expenses", engineCategory: "Expense"),
      // 6. REPAIR & MAINTENANCE
      SmartItem(name: "Building Repair", group: "6. Repair & Maintenance", engineCategory: "Expense"),
      SmartItem(name: "Vehicle/Can Repair", group: "6. Repair & Maintenance", engineCategory: "Expense"),
      // 7. OTHER INCOME
      SmartItem(name: "Bank/FD Interest Received", group: "7. Other Income", engineCategory: "Income"),
      SmartItem(name: "Commission Received", group: "7. Other Income", engineCategory: "Income"),
      SmartItem(name: "Membership/Admission Fee", group: "7. Other Income", engineCategory: "Income"),
      // 8. FIXED ASSETS & DEPRECIATION
      SmartItem(name: "Building / Furniture", group: "8. Fixed Assets", engineCategory: "Asset"),
      SmartItem(name: "Computers & Equipments", group: "8. Fixed Assets", engineCategory: "Asset"),
      SmartItem(name: "Depreciation (All Assets)", group: "8. Fixed Assets", engineCategory: "Expense_NonCash"),
      // 9. CURRENT ASSETS (Cash & Bank)
      SmartItem(name: "Opening Cash/Bank Bal", group: "9. Cash & Bank (Current Assets)", engineCategory: "Opening_Bal"),
      SmartItem(name: "Closing Cash in Hand", group: "9. Cash & Bank (Current Assets)", engineCategory: "Cash_Asset"),
      SmartItem(name: "Closing Bank Balance", group: "9. Cash & Bank (Current Assets)", engineCategory: "Cash_Asset"),
      // 10. CAPITAL & LIABILITIES
      SmartItem(name: "Share Capital", group: "10. Capital & Liabilities", engineCategory: "Liability"),
      SmartItem(name: "Reserve Funds", group: "10. Capital & Liabilities", engineCategory: "Liability"),
      SmartItem(name: "Loan Outstanding", group: "10. Capital & Liabilities", engineCategory: "Liability"),
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

  // 🚀 कस्टम आइटम (Custom Item) जोड़ने का डायलॉग
  void _showCustomItemDialog() {
    String newName = "";
    double newAmount = 0;
    String selectedCategory = "Expense"; 

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("नया कस्टम आइटम जोड़ें", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      var newItem = SmartItem(name: newName, group: "11. Custom Added Items", engineCategory: selectedCategory, isActive: true, amount: newAmount);
                      allItems.add(newItem);
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

  // 🚀 डेटाबेस में सेव करना
  void _saveToDatabase() async {
    if (_selectedSocietyId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("डेटाबेस में सेव किया जा रहा है...")));

    // सिर्फ एक्टिव आइटम्स को सेव करें
    for (var item in allItems.where((i) => i.isActive && i.amount > 0)) {
      String type = (item.engineCategory.contains('Cr') || item.engineCategory == 'Income' || item.engineCategory.contains('Liability') || item.engineCategory == 'Opening_Bal') ? 'CREDIT' : 'DEBIT';
      String dbCat = 'Expense';
      if (item.engineCategory.contains('Asset')) dbCat = 'Asset';
      if (item.engineCategory.contains('Liability')) dbCat = 'Liability';
      if (item.engineCategory == 'Income' || item.engineCategory.contains('Cr') || item.engineCategory == 'Opening_Bal') dbCat = 'Income';

      await DatabaseHelper.instance.insertLedgerEntry({
        'society_id': _selectedSocietyId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'particulars': item.name,
        'amount': item.amount,
        'type': type,
        'category': dbCat,
        'doc_type': 'Manual Ledger',
        'is_manual': 1 
      });
    }

    if (!mounted) return;
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ रिकॉर्ड्स सफलतापूर्वक लोकल DB में सेव हो गए हैं!")));
  }

  // 🚀 Generate Accounts & T-Shape Logic
  void _generateAndShareAccounts() {
    engine.items.clear();
    
    // सिर्फ टॉगल ON वाले आइटम्स को इंजन में डालें
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
        height: MediaQuery.of(context).size.height * 0.7,
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
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.save),
                    label: const Text("Save to DB"),
                    onPressed: _saveToDatabase,
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
    List<String> groupKeys = groupedItems.keys.toList()..sort();

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
