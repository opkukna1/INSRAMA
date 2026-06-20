// lib/screens/manual_ledger_screen.dart
import 'package:flutter/material.dart';
import '../engine/accounting_engine.dart';
import 'package:share_plus/share_plus.dart'; // शेयरिंग के लिए

class ManualLedgerScreen extends StatefulWidget {
  const ManualLedgerScreen({super.key});

  @override
  State<ManualLedgerScreen> createState() => _ManualLedgerScreenState();
}

class _ManualLedgerScreenState extends State<ManualLedgerScreen> {
  final AccountingEngine engine = AccountingEngine();
  
  String selectedSocietyType = "Milk"; // Default
  String selectedYear = "2024-25";      // Default
  
  final List<String> societyTypes = ["Milk", "Women", "GSS"];
  final List<String> years = ["2024-25", "2025-26", "2026-27"];

  @override
  void initState() {
    super.initState();
    engine.initializeDefaultItems();
  }

  // डेटा सेव करने का लॉजिक (इसे अपने DB Helper से जोड़ें)
  void _saveToDatabase() {
    // TODO: engine.items और calculated results को Local DB में सेव करें
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Records saved for $selectedSocietyType ($selectedYear)")),
    );
  }

  void _generateAndShareAccounts() {
    // यहाँ आप चारों रिपोर्ट्स की कैलकुलेशन कॉल करें
    // 1. Receipts & Payments, 2. Trading, 3. P&L, 4. Balance Sheet
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Text("Final Accounts Report", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView(
                children: [
                  _buildReportSection("Receipts & Payments Account"),
                  _buildReportSection("Trading Account"),
                  _buildReportSection("Profit & Loss Account"),
                  _buildReportSection("Balance Sheet"),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _saveToDatabase, child: Text("Save to DB"))),
                SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => Share.share("Report data..."), child: Text("Share"))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportSection(String title) {
    return ExpansionTile(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      children: [ListTile(title: Text("Data details here..."))],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manual Ledger - $selectedSocietyType")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: DropdownButtonFormField(
                  value: selectedSocietyType,
                  items: societyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => selectedSocietyType = val!),
                  decoration: InputDecoration(labelText: "Society Type"),
                )),
                SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField(
                  value: selectedYear,
                  items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => selectedYear = val!),
                  decoration: InputDecoration(labelText: "Audit Year"),
                )),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: engine.items.length,
              itemBuilder: (context, index) {
                final item = engine.items[index];
                return ListTile(
                  title: Text(item.name),
                  trailing: SizedBox(width: 100, child: TextField(onChanged: (v) => item.amount = double.tryParse(v)??0)),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateAndShareAccounts,
        label: Text("Generate & Save"),
        icon: Icon(Icons.save),
      ),
    );
  }
}
