// lib/screens/master_ledger_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; // एक्सेल फाइल बनाने के लिए
import 'package:path_provider/path_provider.dart'; // फाइल सेव करने की लोकेशन के लिए
import '../database/db_helper.dart';

class MasterLedgerScreen extends StatefulWidget {
  const MasterLedgerScreen({super.key});

  @override
  State<MasterLedgerScreen> createState() => _MasterLedgerScreenState();
}

class _MasterLedgerScreenState extends State<MasterLedgerScreen> {
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  List<Map<String, dynamic>> _ledgerData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  // 1. समितियां लोड करना
  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
        _loadLedgerData();
      }
    });
  }

  // 2. लेज़र का डेटा लोड करना
  void _loadLedgerData() async {
    if (_selectedSocietyId == null) return;
    setState(() => _isLoading = true);
    
    final data = await DatabaseHelper.instance.getMasterLedger(_selectedSocietyId!);
    
    setState(() {
      _ledgerData = data;
      _isLoading = false;
    });
  }

  // 3. किसी एंट्री को एडिट करने का डायलॉग
  void _showEditDialog(Map<String, dynamic> row) {
    TextEditingController dateCtrl = TextEditingController(text: row['date']);
    TextEditingController particularsCtrl = TextEditingController(text: row['particulars']);
    TextEditingController amountCtrl = TextEditingController(text: row['amount'].toString());
    
    String selectedType = row['type'] ?? 'DEBIT';
    String selectedCategory = row['category'] ?? 'Expense';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('एंट्री एडिट करें'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'तारीख (DD-MM-YYYY)')),
                  TextField(controller: particularsCtrl, decoration: const InputDecoration(labelText: 'विवरण (Particulars)')),
                  TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'राशि (Amount)')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'प्रकार (Type)'),
                    items: ['DEBIT', 'CREDIT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setDialogState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'कैटेगरी (Category)'),
                    items: ['Income', 'Expense', 'Asset', 'Liability'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategory = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  Map<String, dynamic> updatedData = {
                    'date': dateCtrl.text,
                    'particulars': particularsCtrl.text,
                    'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                    'type': selectedType,
                    'category': selectedCategory,
                  };
                  await DatabaseHelper.instance.updateLedgerEntry(row['id'], updatedData);
                  Navigator.pop(context);
                  _loadLedgerData(); // रिफ्रेश करें
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एंट्री अपडेट हो गई!')));
                },
                child: const Text('सेव करें'),
              ),
            ],
          );
        });
      },
    );
  }

  // 4. एंट्री डिलीट करना
  void _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteLedgerEntry(id);
    _loadLedgerData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एंट्री डिलीट कर दी गई।')));
  }

  // 5. 🚀 असली एक्सेल (Excel) फाइल जनरेट और सेव करना
  void _exportToExcel() async {
    if (_ledgerData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एक्सपोर्ट करने के लिए कोई डेटा नहीं है!')));
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Master Ledger'];
      excel.setDefaultSheet('Master Ledger');

      // हेडिंग्स जोड़ना
      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Particulars'),
        TextCellValue('Amount (Rs)'),
        TextCellValue('Type'),
        TextCellValue('Category'),
        TextCellValue('Document Type')
      ]);

      // सारा डेटा एक्सेल में डालना
      for (var row in _ledgerData) {
        sheetObject.appendRow([
          TextCellValue(row['date'].toString()),
          TextCellValue(row['particulars'].toString()),
          DoubleCellValue(row['amount']),
          TextCellValue(row['type'].toString()),
          TextCellValue(row['category'].toString()),
          TextCellValue(row['doc_type'].toString()),
        ]);
      }

      // फाइल सेव करने की लोकेशन (लोकल स्टोरेज)
      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/Master_Ledger_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('एक्सेल फाइल सेव हो गई:\n$filePath'),
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.green.shade800,
      ));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('एक्सेल बनाने में त्रुटि: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 मास्टर लेज़र (Excel View)'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _exportToExcel,
          )
        ],
      ),
      body: Column(
        children: [
          // टॉप सेक्शन: समिति चुनना
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('समिति चुनें: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedSocietyId,
                    items: _societies.map((s) => DropdownMenuItem<int>(
                      value: s['id'] as int, 
                      child: Text(s['name'])
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSocietyId = val;
                      });
                      _loadLedgerData();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // एक्सेल शीट ग्रिड व्यू
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ledgerData.isEmpty
                    ? const Center(child: Text("इस समिति का कोई लेज़र डेटा नहीं मिला।"))
                    : InteractiveViewer( // ज़ूम और पैन करने के लिए
                        constrained: false,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.green.shade100),
                          columns: const [
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Particulars', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _ledgerData.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row['date'] ?? '')),
                                DataCell(Text(row['particulars'] ?? '')),
                                DataCell(Text('₹${row['amount']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(
                                  row['type'] ?? '',
                                  style: TextStyle(
                                    color: row['type'] == 'CREDIT' ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold
                                  )
                                )),
                                DataCell(Text(row['category'] ?? '')),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      onPressed: () => _showEditDialog(row),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _deleteEntry(row['id']),
                                    ),
                                  ],
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
