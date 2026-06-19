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
  List<Map<String, dynamic>> _allLedgerData = []; // 🚀 नया: ओरिजिनल बैकअप डेटा रखने के लिए
  List<Map<String, dynamic>> _filteredLedgerData = []; // 🚀 नया: लाइव सर्च फ़िल्टर डेटा
  bool _isLoading = false;
  
  final TextEditingController _searchController = TextEditingController(); // 🚀 नया: सर्च बार कंट्रोलर

  // हमारे ERP के सभी प्रामाणिक अकाउंट हेड्स की सूची (हिंदी मैपिंग के साथ)
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
      _filteredLedgerData = data; // शुरुआती तौर पर फ़िल्टर्ड डेटा में पूरा डेटा डालें
      _searchController.clear(); // सोसाइटी बदलते ही सर्च क्लियर करें
      _isLoading = false;
    });
  }

  // 🚀 नया: ऑन-द-स्पॉट लाइव सर्च फ़िल्टर मैकेनिज्म (विवरण या हेड के आधार पर सर्च)
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

  // 🚀 महा-अपग्रेड: नए Strict Account Heads सिलेक्शन के साथ उन्नत एडिट डायलॉग
  void _showEditDialog(Map<String, dynamic> row) {
    TextEditingController dateCtrl = TextEditingController(text: row['date']);
    TextEditingController particularsCtrl = TextEditingController(text: row['particulars']);
    TextEditingController amountCtrl = TextEditingController(text: row['amount'].toString());
    
    String selectedType = row['type'] ?? 'DEBIT';
    String selectedCategory = row['category'] ?? 'Expense';
    
    // वर्तमान अकाउंट हेड निकालें (यदि खाली या नल है तो 'none' सेट करें)
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
                  
                  // 🎯 सबसे महत्वपूर्ण अपडेट: वैधानिक अकाउंट हेड ड्रॉपडाउन मैपिंग
                  DropdownButtonFormField<String>(
                    value: selectedHead,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'वैधानिक खाता हेड (Strict Account Head)',
                      filled: true,
                      fillColor: Colors.amber.shade50 / 2,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _headNamesHindi.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedHead = val!;
                        // 🧠 ऑटो-पायलट मैपिंग: जब हेड चुना जाए, तो प्रकार और कैटेगरी को बैकग्राउंड में ऑटो-सेट कर दें
                        if (selectedHead == 'milk_sales' || selectedHead == 'feed_sales') {
                          selectedType = 'CREDIT'; selectedCategory = 'Income';
                        } else if (selectedHead == 'milk_purchase' || selectedHead == 'feed_purchase') {
                          selectedType = 'DEBIT'; selectedCategory = 'Expense';
                        } else if (selectedHead == 'miscellaneous_income') {
                          selectedType = 'CREDIT'; selectedCategory = 'Income';
                        } else if (selectedHead == 'establishment_expense' || selectedHead == 'audit_fee_provision') {
                          selectedType = 'DEBIT'; selectedCategory = 'Expense';
                        } else if (selectedHead == 'dairy_debtors') {
                          selectedCategory = 'Asset';
                        } else if (selectedHead == 'share_capital') {
                          selectedCategory = 'Liability';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(labelText: 'प्रकार (Type)'),
                          items: ['DEBIT', 'CREDIT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setDialogState(() => selectedType = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(labelText: 'कैटेगरी (Category)'),
                          items: ['Income', 'Expense', 'Asset', 'Liability'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setDialogState(() => selectedCategory = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('रद्द करें', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('सुरक्षित करें'),
                onPressed: () async {
                  Map<String, dynamic> updatedData = {
                    'date': dateCtrl.text,
                    'particulars': particularsCtrl.text,
                    'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                    'type': selectedType,
                    'category': selectedCategory,
                    'account_head': selectedHead == 'none' ? null : selectedHead,
                    'is_manual': 1 // मुनीम जी द्वारा हाथ से एडिट किया गया मार्क करें
                  };
                  
                  await DatabaseHelper.instance.updateLedgerEntry(row['id'], updatedData);
                  
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _loadLedgerData(); 
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ प्रविष्टि को सफलतापूर्वक संशोधित एवं लॉक कर दिया गया है!')));
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _deleteEntry(int id) async {
    // सुरक्षा अलर्ट डायलॉग
    bool confirmDelete = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ प्रविष्टि हटाना सुनिश्चित करें?"),
        content: const Text("क्या आप सचमुच इस लेज़र रिकॉर्ड को हमेशा के लिए डिलीट करना चाहते हैं? इससे आपके P&L खाते और ऑडिट रिपोर्ट बदल जाएंगे।"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("रद्द करें")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("हाँ, हटाएं")
          )
        ],
      )
    ) ?? false;

    if (!confirmDelete) return;

    await DatabaseHelper.instance.deleteLedgerEntry(id);
    if (!mounted) return; 
    _loadLedgerData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ रिकॉर्ड सफलतापूर्वक हटा दिया गया है।')));
  }

  // 🚀 एक्सेल एक्सपोर्ट मैकेनिज्म: नए 'Account Head' कॉलम के साथ अपडेटेड
  void _exportToExcelAndShare() async {
    if (_filteredLedgerData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('एक्सपोर्ट करने के लिए कोई डेटा नहीं है!')));
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('आधिकारिक एक्सेल शीट जनरेट हो रही है...'), duration: Duration(seconds: 1)));

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Master Ledger'];
      excel.setDefaultSheet('Master Ledger');

      // हेडर रो में 'Account Head' कॉलम को जोड़ना
      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Particulars / Item'),
        TextCellValue('Account Head (Strict)'),
        TextCellValue('Amount (INR)'),
        TextCellValue('Type'),
        TextCellValue('Category'),
        TextCellValue('Source Document'),
        TextCellValue('Entry Mode')
      ]);

      for (var row in _filteredLedgerData) {
        String headKey = row['account_head'] ?? 'none';
        String headReadable = _headNamesHindi[headKey] ?? 'General Entry';
        String entryMode = (row['is_manual'] ?? 0) == 1 ? "MANUAL" : "AI_AUTO";

        sheetObject.appendRow([
          TextCellValue(row['date'].toString()),
          TextCellValue(row['particulars'].toString()),
          TextCellValue(headReadable),
          DoubleCellValue(row['amount']),
          TextCellValue(row['type'].toString()),
          TextCellValue(row['category'].toString()),
          TextCellValue((row['doc_type'] ?? 'Voucher').toString()),
          TextCellValue(entryMode),
        ]);
      }

      Directory tempDir = await getTemporaryDirectory();
      String societyName = _societies.firstWhere((s) => s['id'] == _selectedSocietyId)['name'] ?? 'Society';
      String cleanSocietyName = societyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      String filePath = '${tempDir.path}/Audited_Ledger_${cleanSocietyName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      if (!mounted) return;
      
      await Share.shareXFiles(
        [XFile(filePath)], 
        text: '◆ $societyName ◆ का वैधानिक मास्टर लेज़र ऑडिट रेडी एक्सेल फॉर्मेट में साझा किया गया है।'
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
        title: const Text('📊 मास्टर लेज़र (ERP Spreadsheet)'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_text_rounded),
            tooltip: 'Export & Share Excel Sheet',
            onPressed: _exportToExcelAndShare,
          )
        ],
      ),
      body: Column(
        children: [
          // 🏛️ प्रीमियम टॉप फ़िल्टर बार
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Column(
                children: [
                  // सोसाइटी ड्रॉपडाउन सेलेक्टर
                  Row(
                    children: [
                      Icon(Icons.account_balance_rounded, color: Colors.green.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedSocietyId,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black8Set, fontSize: 15),
                            items: _societies.map((s) => DropdownMenuItem<int>(
                              value: s['id'] as int, 
                              child: Text(s['name'])
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() { _selectedSocietyId = val; });
                                _loadLedgerData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 8),
                  
                  // 🔍 लाइव टेक्स्ट सर्च बार कंपोनेंट
                  TextField(
                    controller: _searchController,
                    onChanged: _filterLedger,
                    decoration: InputDecoration(
                      hintText: "विवरण या अकाउंट हेड से खोजें (Live Search)...",
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      border: InputBorder.none,
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _filterLedger(''); })
                        : null
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // 📄 स्प्रेडशीट डेटा ग्रिड व्यू
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _filteredLedgerData.isEmpty
                    ? const Center(
                        child: Text(
                          "कोई प्रविष्टि या मैचिंग रिकॉर्ड नहीं मिला।", 
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 15)
                        )
                      )
                    : InteractiveViewer( 
                        constrained: false,
                        scrollDirection: Axis.both,
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll(Colors.green.shade100), 
                          headingRowHeight: 45,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          border: TableBorder.all(color: Colors.grey.shade200, width: 1),
                          columns: const [
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                            DataColumn(label: Text('Particulars (मद विवरण)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                            DataColumn(label: Text('Account Head (वैधानिक खाता)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                            DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                          ],
                          rows: _filteredLedgerData.map((row) {
                            String headKey = row['account_head'] ?? 'none';
                            String headDisplayName = _headNamesHindi[headKey] ?? 'General Entry';
                            bool isManual = (row['is_manual'] ?? 0) == 1;

                            return DataRow(
                              cells: [
                                DataCell(Text(row['date'] ?? '', style: const TextStyle(fontSize: 13))),
                                DataCell(
                                  Row(
                                    children: [
                                      Text(row['particulars'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      if (isManual) const SizedBox(width: 6),
                                      if (isManual)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                          child: Text("MANUAL", style: TextStyle(fontSize: 8, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  )
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: headKey == 'none' ? Colors.grey.shade100 : Colors.green.shade50 / 1.5,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      headDisplayName, 
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: headKey == 'none' ? Colors.black54 : Colors.green.shade900)
                                    ),
                                  )
                                ),
                                DataCell(Text('₹${row['amount']}', style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace', fontSize: 13))),
                                DataCell(Text(
                                  row['type'] ?? '',
                                  style: TextStyle(
                                    color: row['type'] == 'CREDIT' ? Colors.green.shade700 : Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12
                                  )
                                )),
                                DataCell(Text(row['category'] ?? '', style: const TextStyle(fontSize: 12))),
                                DataCell(Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
                                      tooltip: 'संपादित करें',
                                      onPressed: () => _showEditDialog(row),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 22),
                                      tooltip: 'हटाएं',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportToExcelAndShare,
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.share_text_rounded),
        label: const Text("Share Excel Grid", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
