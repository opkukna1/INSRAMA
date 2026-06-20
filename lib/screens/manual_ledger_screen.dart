// lib/screens/manual_ledger_screen.dart

import 'package:flutter/material.dart';
import '../engine/accounting_engine.dart';

class ManualLedgerScreen extends StatefulWidget {
  @override
  _ManualLedgerScreenState createState() => _ManualLedgerScreenState();
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

  // नया आइटम जोड़ने का पॉपअप
  void _showAddCustomItemDialog() {
    String newName = "";
    double newAmount = 0;
    String selectedCategory = "Expense"; // Default

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Custom Ledger Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: "Item Name (e.g. Tea Exp)"),
                onChanged: (val) => newName = val,
              ),
              TextField(
                decoration: InputDecoration(labelText: "Amount (₹)"),
                keyboardType: TextInputType.number,
                onChanged: (val) => newAmount = double.tryParse(val) ?? 0,
              ),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: ["Income", "Expense", "Core_Dr", "Core_Cr", "Asset", "Liability"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedCategory = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text("Cancel")
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  engine.addCustomItem(newName, newAmount, selectedCategory);
                });
                Navigator.pop(context);
              },
              child: Text("Add & Save"),
            )
          ],
        );
      }
    );
  }

  void _generateAccounts() {
    double gp = engine.grossProfit;
    double np = engine.netProfit;
    var bs = engine.balanceSheet;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📊 Automatic Accounts Prepared!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              Divider(),
              Text("1. Gross Profit (Trading A/c): ₹$gp", style: TextStyle(fontSize: 16)),
              Text("2. Net Profit (P&L A/c): ₹$np", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("3. Balance Sheet Totals:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("   Liabilities Side: ₹${bs['Total Liabilities']}"),
              Text("   Assets Side: ₹${bs['Total Assets']}"),
              if(bs['Total Liabilities'] == bs['Total Assets'])
                 Text("✅ Balance Sheet Matched Perfectly!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.picture_as_pdf),
                    label: Text("Download PDF"),
                    onPressed: () { /* Add 'pdf' package logic here */ },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.table_chart),
                    label: Text("Download Excel"),
                    onPressed: () { /* Add 'excel' package logic here */ },
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
      appBar: AppBar(title: Text("Manual Ledger Entry")),
      body: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: engine.items.length,
        itemBuilder: (context, index) {
          final item = engine.items[index];
          return Card(
            child: ListTile(
              title: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Category: ${item.category}"),
              trailing: Container(
                width: 120,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: "₹ ",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8)
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
            backgroundColor: Colors.blue,
            child: Icon(Icons.add),
            onPressed: _showCustomItemDialog,
            tooltip: "Add Custom Item",
          ),
          SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "genBtn",
            backgroundColor: Colors.green,
            icon: Icon(Icons.receipt_long),
            label: Text("Generate Accounts"),
            onPressed: _generateAccounts,
          ),
        ],
      ),
    );
  }
}
