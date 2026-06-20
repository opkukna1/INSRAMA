// lib/screens/master_ledger_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; 
import '../database/db_helper.dart';

class MasterLedgerScreen extends StatefulWidget {
  const MasterLedgerScreen({super.key});

  @override
  State<MasterLedgerScreen> createState() => _MasterLedgerScreenState();
}

class _MasterLedgerScreenState extends State<MasterLedgerScreen> {
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  List<Map<String, dynamic>> _allLedgerData = []; 
  List<Map<String, dynamic>> _filteredLedgerData = []; // 🔥 फिक्स: सही वेरिएबल नाम
  bool _isLoading = false;
  
  final TextEditingController _searchController = TextEditingController(); 

  final Map<String, String> _headNamesHindi = {
    "none": "सामान्य प्रविष्टि / कोई नहीं",
    "milk_purchase": "दुग्ध खरीद (Milk Purchase)",
    "milk_sales": "दुग्ध बिक्री (Milk Sales)",
    "feed_purchase": "पशु आहार खरीद (Feed Purchase)",
    "feed_sales": "पशु आहार बिक्री (Feed Sales)",
    "establishment_expense": "स्थापना एवं मानदेय (Establishment)",
    "audit_fee_provision": "ऑडिट फीस प्रावधान (Audit Provision)",
    "miscellaneous_income": "विविध डायरेक्ट आय (Misc Income)",
    "share_capital": "सदस्य शेयर पूंजी (Share Capital)",
    "dairy_debtors": "डेयरी संघ देनदार (Dairy Debtors)"
  };

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
      _allLedgerData = data;
      _filteredLedgerData = data; // 🔥 फिक्स 
      _searchController.clear(); 
      _isLoading = false;
    });
  }

  void _filterLedger(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLedgerData = _allLedgerData); // 🔥 फिक्स
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredLedgerData = _allLedgerData.where((row) { // 🔥 फिक्स
        final particulars = (row['particulars'] ?? '').toString().toLowerCase();
        final head = (row['account_head'] ?? '').toString().toLowerCase();
        final headHindi = (_headNamesHindi[head] ?? '').toLowerCase();
        
        return particulars.contains(lowercaseQuery) || 
               head.contains(lowercaseQuery) || 
               headHindi.contains(lowercaseQuery);
      }).toList();
    });
  }

  void _showEditDialog(Map<String, dynamic> row) {
    TextEditingController dateCtrl = TextEditingController(text: row['date']);
    TextEditingController particularsCtrl = TextEditingController(text: row['particulars']);
    TextEditingController amountCtrl = TextEditingController(text: row['amount'].toString());
    
    String selectedType = row['type'] ?? 'DEBIT';
    String selectedCategory = row['category'] ?? 'Expense';
    
    String selectedHead = row['account_head'] ?? 'none';
    if (!_headNamesHindi.containsKey(selectedHead)) {
      selectedHead = 'none';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.green.shade800),
                const SizedBox(width: 8),
                const Text('लेज़र प्रविष्टि संशोधित करें'),
              ],
            ),
            content: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'दिनांक (YYYY-MM-DD)', prefixIcon: Icon(Icons.calendar_today, size: 18))),
                  const SizedBox(height: 8),
                  TextField(controller: particularsCtrl, decoration: const InputDecoration(labelText: 'विवरण / मद का नाम (Particulars)', prefixIcon: Icon(Icons.description, size: 18))),
                  const SizedBox(height: 8),
                  TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'राशि (Amount ₹)', prefixIcon: Icon(Icons.currency_rupee, size: 18))),
                  const SizedBox(height: 14),
                  
                  DropdownButtonFormField<String>(
                    value: selectedHead,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'वैधानिक खाता हेड',
                      filled: true,
                      fillColor: Colors.amber.shade50.withOpacity(0.5), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _headNamesHindi.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedHead = val!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('रद्द करें')),
              ElevatedButton(
                onPressed: () async {
                  Map<String, dynamic> updatedData = {
                    'date': dateCtrl.text,
                    'particulars': particularsCtrl.text,
                    'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                    'account_head': selectedHead == 'none' ? null : selectedHead,
                    'is_manual': 1 
                  };
                  await DatabaseHelper.instance.updateLedgerEntry(row['id'], updatedData);
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  _loadLedgerData();
                },
                child: const Text('सुरक्षित करें'),
              ),
            ],
          );
        });
      },
    );
  }

  void _deleteEntry(int id) async {
    await DatabaseHelper.instance.deleteLedgerEntry(id);
    _loadLedgerData();
  }

  void _exportToExcelAndShare() async {
    if (_filteredLedgerData.isEmpty) return; // 🔥 फिक्स
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Master Ledger'];
      
      sheetObject.appendRow([TextCellValue('Date'), TextCellValue('Particulars'), TextCellValue('Amount')]);
      for (var row in _filteredLedgerData) { // 🔥 फिक्स
        sheetObject.appendRow([TextCellValue(row['date'].toString()), TextCellValue(row['particulars'].toString()), DoubleCellValue(row['amount'])]);
      }
      
      Directory tempDir = await getTemporaryDirectory();
      String filePath = '${tempDir.path}/Ledger.xlsx';
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 मास्टर लेज़र'),
        backgroundColor: Colors.green.shade800,
        actions: [
          IconButton(icon: const Icon(Icons.share_rounded), onPressed: _exportToExcelAndShare), 
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            child: DropdownButton<int>(
              value: _selectedSocietyId,
              isExpanded: true,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15), 
              items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
              onChanged: (val) {
                setState(() => _selectedSocietyId = val);
                _loadLedgerData();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer( 
                    constrained: false, 
                    child: DataTable(
                      border: TableBorder.all(color: Colors.grey.shade200),
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Particulars')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: _filteredLedgerData.map((row) { // 🔥 फिक्स
                        return DataRow(cells: [
                          DataCell(Text(row['date'] ?? '')),
                          DataCell(Text(row['particulars'] ?? '')),
                          DataCell(Text(row['amount'].toString())),
                          DataCell(IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditDialog(row))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
