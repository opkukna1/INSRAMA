// lib/screens/master_ledger_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; // 🚀 नया: डायरेक्ट WhatsApp/Email शेयरिंग के लिए
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

  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    if (!mounted) return;
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
        _loadLedgerData();
      }
    });
  }

  void _loadLedgerData() async {
    if (_selectedSocietyId == null) return;
    setState(() => _isLoading = true);
    
    final data = await DatabaseHelper.instance.getMasterLedger(_selectedSocietyId!);
    
    if (!mounted) return;
    setState(() {
      _ledgerData = data;
      _isLoading = false;
    });
  }

  void _showEditDialog(Map<String, dynamic> row) {
    TextEditingController dateCtrl = TextEditingController(text: row['date']);
    TextEditingController particularsCtrl = TextEditingController(text: row['particulars']);
    TextEditingController amountCtrl = TextEditingController(text: row['amount'].toString());
    
    String selectedType = row['type'] ?? 'DEBIT';
    String selectedCategory = row['category'] ?? 'Expense';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('एंट्री एडिट करें'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'तारीख (YYYY-MM-DD)')),
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
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('रद्द करें')),
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
                  
                  // 🚀 फिक्स: Async Gap क्रैश को रोकने के लिए
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  _loadLedgerData(); 
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

  void _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteLedgerEntry(id);
    
    // 🚀 फिक्स: Async Gap क्रैश को रोकने के लिए
    if (!mounted) return; 
    _loadLedgerData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एंट्री डिलीट कर दी गई।')));
  }

  // 🚀 असली अपग्रेड: एक्सेल फाइल बनाकर सीधे शेयर (WhatsApp/Email) करना
  void _exportToExcelAndShare() async {
    if (_ledgerData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एक्सपोर्ट करने के लिए कोई डेटा नहीं है!')));
      return;
    }

    try {
      // लोडिंग इंडिकेटर दिखाना
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एक्सेल फाइल तैयार हो रही है...'), duration: Duration(seconds: 1)));

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

      // 🚀 फिक्स: फाइल को Temporary Directory में सेव करें ताकि वहां से शेयर की जा सके
      Directory tempDir = await getTemporaryDirectory();
      
      // फाइल का नाम समिति के नाम और तारीख के साथ
      String societyName = _societies.firstWhere((s) => s['id'] == _selectedSocietyId)['name'] ?? 'Society';
      String cleanSocietyName = societyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      String filePath = '${tempDir.path}/Ledger_${cleanSocietyName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      if (!mounted) return;
      
      // शेयरिंग डायलॉग खोलना (WhatsApp, Email, Telegram आदि के लिए)
      await Share.shareXFiles(
        [XFile(filePath)], 
        text: '$societyName का मास्टर लेज़र (Excel Report) तैयार है।'
      );

    } catch (e) {
      if (!mounted) return;
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
            icon: const Icon(Icons.share), // 🚀 आइकॉन को Download से Share में बदला
            tooltip: 'Export & Share Excel',
            onPressed: _exportToExcelAndShare,
          )
        ],
      ),
      body: Column(
        children: [
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
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ledgerData.isEmpty
                    ? const Center(child: Text("इस समिति का कोई लेज़र डेटा नहीं मिला।"))
                    : InteractiveViewer( 
                        constrained: false,
                        child: DataTable(
                          // 🚀 फिक्स: MaterialStateProperty अब डेप्रिकेट (पुराना) हो गया है, WidgetStatePropertyAll का इस्तेमाल करें
                          headingRowColor: const WidgetStatePropertyAll(Color(0xFFC8E6C9)), 
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
      // 🚀 यूज़र की सुविधा के लिए एक फ्लोटिंग बटन भी दे दिया गया है
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportToExcelAndShare,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.import_export),
        label: const Text("Export Excel"),
      ),
    );
  }
}
