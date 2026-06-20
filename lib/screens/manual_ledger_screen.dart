// lib/screens/manual_ledger_screen.dart

import 'package:flutter/material.dart';
import '../engine/accounting_engine.dart';

class ManualLedgerScreen extends StatefulWidget {
  const ManualLedgerScreen({super.key});

  @override
  State<ManualLedgerScreen> createState() => _ManualLedgerScreenState();
}

class _ManualLedgerScreenState extends State<ManualLedgerScreen> {
  final AccountingEngine engine = AccountingEngine();
  
  // Basic Details
  String societyName = "Select Society";
  String year = "2024-2025";
  String inspectorName = "";

  @override
  void initState() {
    super.initState();
    engine.initializeDefaultItems();
  }

  // 🚀 फिक्स: फंक्शन का नाम सही कर दिया गया है और StatefulBuilder जोड़ दिया गया है
  void _showCustomItemDialog() {
    String newName = "";
    double newAmount = 0;
    String selectedCategory = "Expense"; // Default

    showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder डायलॉग के अंदर की स्टेट (जैसे ड्रॉपडाउन) को अपडेट करने के लिए जरूरी है
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Custom Ledger Item"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: "Item Name (e.g. Tea Exp)"),
                  onChanged: (val) => newName = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Amount (₹)"),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => newAmount = double.tryParse(val) ?? 0,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Category'),
                  items: ["Income", "Expense", "Core_Dr", "Core_Cr", "Asset", "Liability"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    // setDialogState से सिर्फ डायलॉग का UI रिफ्रेश होगा
                    setDialogState(() => selectedCategory = val!);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext), 
                child: const Text("Cancel")
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () {
                  if (newName.isNotEmpty) {
                    setState(() {
                      engine.addCustomItem(newName, newAmount, selectedCategory);
                    });
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text("Add & Save"),
              )
            ],
          );
        });
      }
    );
  }

  void _generateAccounts() {
    double gp = engine.grossProfit;
    double np = engine.netProfit;
    var bs = engine.balanceSheet;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📊 Automatic Accounts Prepared!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              Text("1. Gross Profit (Trading A/c): ₹$gp", style: const TextStyle(fontSize: 16)),
              Text("2. Net Profit (P&L A/c): ₹$np", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              const Text("3. Balance Sheet Totals:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("   Liabilities Side: ₹${bs['Total Liabilities']}", style: const TextStyle(fontSize: 15)),
              Text("   Assets Side: ₹${bs['Total Assets']}", style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 10),
              if(bs['Total Liabilities'] == bs['Total Assets'])
                 const Text("✅ Balance Sheet Matched Perfectly!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))
              else
                 const Text("⚠️ Balance Sheet Mismatch. Please check entries.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("PDF"),
                    onPressed: () { /* TODO: Add PDF logic */ },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.table_chart),
                    label: const Text("Excel"),
                    onPressed: () { /* TODO: Add Excel logic */ },
                  ),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manual Ledger Entry"),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: engine.items.length,
        itemBuilder: (context, index) {
          final item = engine.items[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Category: ${item.category}", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              trailing: SizedBox(
                width: 130,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: "₹ ",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                  ),
                  onChanged: (val) {
                    item.amount = double.tryParse(val) ?? 0;
                  },
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "addBtn",
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            onPressed: _showCustomItemDialog, // 🔥 फिक्स: सही नाम कॉल किया गया
            tooltip: "Add Custom Item",
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "genBtn",
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.receipt_long),
            label: const Text("Generate Accounts", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _generateAccounts,
          ),
        ],
      ),
    );
  }
}
