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
  List<Map<String, dynamic>> _filteredLedgerData = []; 
  bool _isLoading = false;
  
  final TextEditingController _searchController = TextEditingController(); 

  // 🌟 फिक्स: यहाँ आपके नए तीनों खाते हिंदी नामों के साथ जोड़ दिए गए हैं
  final Map<String, String> _headNamesHindi = {
    "none": "सामान्य प्रविष्टि / कोई नहीं",
    "milk_purchase": "दुग्ध खरीद (Milk Purchase)",
    "milk_sales": "दुग्ध बिक्री (Milk Sales)",
    "head_load": "हेड लोड आय (Head Load Income) 🟢",
    "overhead_load": "ओवरहेड आय (Overhead Income) 🟢",
    "ghee_katoti": "घी कटौती खरीद (Ghee Purchase) 🔴",
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
      _filteredLedgerData = data; 
      _searchController.clear(); 
      _isLoading = false;
    });
  }

  void _filterLedger(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLedgerData = _allLedgerData); 
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredLedgerData = _allLedgerData.where((row) { 
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
                  // खाता हेड के आधार पर ऑटो-कैटेगरी सेट करना ताकि बैलेंस शीट न बिगड़े
                  String category = 'Expense';
                  String type = 'DEBIT';
                  
                  if (['milk_sales', 'head_load', 'overhead_load', 'miscellaneous_income', 'feed_sales'].contains(selectedHead)) {
                    category = 'Income';
                    type = 'CREDIT';
                  } else if (selectedHead == 'share_capital') {
                    category = 'Liability';
                    type = 'CREDIT';
                  } else if (selectedHead == 'dairy_debtors') {
                    category = 'Asset';
                    type = 'DEBIT';
                  }

                  Map<String, dynamic> updatedData = {
                    'date': dateCtrl.text,
                    'particulars': particularsCtrl.text,
                    'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                    'account_head': selectedHead == 'none' ? null : selectedHead,
                    'category': category,
                    'type': type,
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
    if (_filteredLedgerData.isEmpty) return; 
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Master Ledger'];
      
      sheetObject.appendRow([TextCellValue('Date'), TextCellValue('Particulars'), TextCellValue('Account Head'), TextCellValue('Amount'), TextCellValue('Type')]);
      for (var row in _filteredLedgerData) { 
        final headKey = row['account_head'] ?? 'none';
        final headHindi = _headNamesHindi[headKey] ?? 'सामान्य';
        sheetObject.appendRow([
          TextCellValue(row['date'].toString()), 
          TextCellValue(row['particulars'].toString()), 
          TextCellValue(headHindi),
          DoubleCellValue(row['amount']),
          TextCellValue(row['type'] ?? 'DEBIT')
        ]);
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
          // सर्च बार जोड़ दिया ताकि आप सीधे "हेड लोड" या "लीटर" सर्च कर सकें
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLedger,
              decoration: InputDecoration(
                hintText: 'विवरण या खाता हेड खोजें (उदा: हेड लोड, 1200 Ltr)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: DropdownButton<int>(
              value: _selectedSocietyId,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15), 
              items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
              onChanged: (val) {
                setState(() => _selectedSocietyId = val);
                _loadLedgerData();
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLedgerData.isEmpty 
                    ? const Center(child: Text('कोई प्रविष्टि नहीं मिली।'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        physics: const BouncingScrollPhysics(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            border: TableBorder.all(color: Colors.grey.shade200),
                            headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
                            columns: const [
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Particulars & Account Head', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredLedgerData.map((row) { 
                              final isCredit = row['type'] == 'CREDIT' || row['category'] == 'Income';
                              final headKey = row['account_head'] ?? 'none';
                              final headHindi = _headNamesHindi[headKey] ?? 'सामान्य';

                              return DataRow(cells: [
                                DataCell(Text(row['date'] ?? '')),
                                // 🌟 विजुअल फिक्स: नाम के नीचे छोटा खाता हेड दिखेगा
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(row['particulars'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(
                                        headHindi,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                // 🌟 विजुअल फिक्स: इनकम हरी दिखेगी और खर्च लाल दिखेगा
                                DataCell(
                                  Text(
                                    '₹${row['amount']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showEditDialog(row)),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20), 
                                        onPressed: () => _deleteEntry(row['id']),
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
