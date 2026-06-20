// lib/screens/manual_ledger_screen.dart
import 'package:flutter/material.dart';
import '../engine/accounting_engine.dart';
import '../services/pdf_export_service.dart'; // 🚀 PDF सर्विस जोड़ी गई
import '../database/db_helper.dart'; // 🚀 डेटाबेस सेव करने के लिए

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

  // डेटाबेस से समितियां लोड करने के लिए
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;

  @override
  void initState() {
    super.initState();
    engine.initializeDefaultItems();
    _loadSocieties();
  }

  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    if (!mounted) return;
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
      }
    });
  }

  // 🚀 नया आइटम जोड़ने का डायलॉग (जिससे पहले एरर आ रहा था)
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
                TextField(
                  decoration: const InputDecoration(labelText: "आइटम का नाम (उदा. चाय खर्च)"),
                  onChanged: (val) => newName = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "राशि (₹)"),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => newAmount = double.tryParse(val) ?? 0,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'खाता श्रेणी (Category)'),
                  items: ["Income", "Expense", "Core_Dr", "Core_Cr", "Asset", "Liability"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedCategory = val!);
                  },
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
                      engine.addCustomItem(newName, newAmount, selectedCategory);
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

  // 🚀 लोकल डेटाबेस (SQLite) में सेव करने का लॉजिक
  void _saveToDatabase() async {
    if (_selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("कृपया पहले समिति चुनें!")));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("डेटाबेस में सेव किया जा रहा है...")));

    for (var item in engine.items) {
      if (item.amount > 0) {
        // क्रेडिट/डेबिट तय करना
        String type = (item.category.contains('Cr') || item.category == 'Income' || item.category.contains('Liability') || item.category == 'Opening_Bal') ? 'CREDIT' : 'DEBIT';
        
        // मास्टर लेज़र की मुख्य कैटेगरी तय करना
        String dbCat = 'Expense';
        if (item.category.contains('Asset')) dbCat = 'Asset';
        if (item.category.contains('Liability')) dbCat = 'Liability';
        if (item.category == 'Income' || item.category.contains('Cr') || item.category == 'Opening_Bal') dbCat = 'Income';

        Map<String, dynamic> row = {
          'society_id': _selectedSocietyId,
          'date': DateTime.now().toIso8601String().split('T')[0],
          'particulars': item.name,
          'amount': item.amount,
          'type': type,
          'category': dbCat,
          'doc_type': 'Manual Ledger',
          'is_manual': 1 // 1 = मुनीम द्वारा हाथ से डाला गया
        };
        
        await DatabaseHelper.instance.insertLedgerEntry(row);
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // बॉटम शीट बंद करें
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ रिकॉर्ड्स सफलतापूर्वक लोकल DB में सेव हो गए हैं!")));
  }

  // 🚀 4 अकाउंट जेनरेट और शेयर करने का UI
  void _generateAndShareAccounts() {
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
            
            // 1. Receipts & Payments Summary
            Text("1. Cash/Bank Closing Bal: ₹${engine.closingCashBal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // 2. Trading Summary
            Text("2. Gross Profit (Trading): ₹${gp.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // 3. P&L Summary
            Text("3. Net Profit (P&L): ₹${np.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // 4. Balance Sheet Check
            const Text("4. Balance Sheet Match Check:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text("   Liabilities Total: ₹${bs['Total Liabilities']?.toStringAsFixed(2)}"),
            Text("   Assets Total: ₹${bs['Total Assets']?.toStringAsFixed(2)}"),
            
            const SizedBox(height: 10),
            if (bs['Total Liabilities'] == bs['Total Assets'])
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.green.shade50,
                child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width:8), Text("Balance Sheet Tally Passed!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width:8), Text("Mismatch! Check entries.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
              ),

            const Spacer(),
            
            // एक्शन बटन्स (Save & PDF)
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
                      String societyName = _societies.isNotEmpty && _selectedSocietyId != null 
                        ? _societies.firstWhere((s) => s['id'] == _selectedSocietyId)['name'] 
                        : "Society";
                      // 🚀 असली T-Shape PDF जनरेटर को कॉल करना
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("मैन्युअल लेज़र एंट्री"),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // टॉप फ़िल्टर बार (Society, Type, Year)
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedSocietyId,
                  decoration: const InputDecoration(labelText: "समिति चुनें", border: OutlineInputBorder(), isDense: true),
                  items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
                  onChanged: (val) => setState(() => _selectedSocietyId = val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selectedSocietyType,
                      decoration: const InputDecoration(labelText: "समिति का प्रकार", border: OutlineInputBorder(), isDense: true),
                      items: societyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => selectedSocietyType = val!),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selectedYear,
                      decoration: const InputDecoration(labelText: "ऑडिट वर्ष", border: OutlineInputBorder(), isDense: true),
                      items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => selectedYear = val!),
                    )),
                  ],
                ),
              ],
            ),
          ),
          
          // एंट्री लिस्ट
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: engine.items.length,
              itemBuilder: (context, index) {
                final item = engine.items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(item.category, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    trailing: SizedBox(
                      width: 120, 
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: "₹ ", 
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => item.amount = double.tryParse(v) ?? 0
                      )
                    ),
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
            icon: const Icon(Icons.receipt_long),
            label: const Text("Generate Accounts"),
            onPressed: _generateAndShareAccounts,
          ),
        ],
      ),
    );
  }
}
