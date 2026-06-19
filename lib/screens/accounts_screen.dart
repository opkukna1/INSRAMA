// lib/screens/accounts_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  bool _isLoading = false;

  // 📊 डायनामिक एकाउंटिंग वेरिएबल्स
  List<Map<String, dynamic>> _incomeItems = [];
  List<Map<String, dynamic>> _expenseItems = [];
  List<Map<String, dynamic>> _assetItems = [];
  List<Map<String, dynamic>> _liabilityItems = [];

  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _netProfit = 0.0;

  double _totalAssets = 0.0;
  double _totalLiabilities = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  // 1. डेटाबेस से समितियों की सूची लाना
  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
        _calculateFinancials(_selectedSocietyId!);
      }
    });
  }

  // 2. 🚀 मास्टर लेज़र से सारा डेटा निकालकर P&L और Balance Sheet बनाना
  void _calculateFinancials(int societyId) async {
    setState(() { _isLoading = true; });
    
    // मास्टर लेज़र से सारा डेटा मँगवाना
    final ledgerData = await DatabaseHelper.instance.getMasterLedger(societyId);
    
    List<Map<String, dynamic>> tempIncome = [];
    List<Map<String, dynamic>> tempExpense = [];
    List<Map<String, dynamic>> tempAsset = [];
    List<Map<String, dynamic>> tempLiability = [];

    double tIncome = 0.0;
    double tExpense = 0.0;
    double tAsset = 0.0;
    double tLiability = 0.0;

    // हर एंट्री को उसकी कैटेगरी के हिसाब से अलग-अलग करना
    for (var entry in ledgerData) {
      double amount = entry['amount'] ?? 0.0;
      String category = entry['category'] ?? '';

      if (category == 'Income') {
        tempIncome.add(entry);
        tIncome += amount;
      } else if (category == 'Expense') {
        tempExpense.add(entry);
        tExpense += amount;
      } else if (category == 'Asset') {
        tempAsset.add(entry);
        tAsset += amount;
      } else if (category == 'Liability') {
        tempLiability.add(entry);
        tLiability += amount;
      }
    }

    setState(() {
      _incomeItems = tempIncome;
      _expenseItems = tempExpense;
      _assetItems = tempAsset;
      _liabilityItems = tempLiability;

      _totalIncome = tIncome;
      _totalExpense = tExpense;
      
      // शुद्ध लाभ (Net Profit) = कुल आय - कुल व्यय
      _netProfit = _totalIncome - _totalExpense;

      _totalAssets = tAsset;
      _totalLiabilities = tLiability;
      
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 वित्तीय खाते (AI Audited)'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: "आय-व्यय खाता (P&L)"),
              Tab(icon: Icon(Icons.account_balance), text: "तुलन पत्र (Balance Sheet)"),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // सोसाइटी ड्रॉपडाउन
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedSocietyId,
                            isExpanded: true,
                            hint: const Text("समिति चुनें"),
                            items: _societies.map((s) {
                              return DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() { _selectedSocietyId = val; });
                                _calculateFinancials(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              _isLoading 
                ? const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.green)))
                : Expanded(
                    child: TabBarView(
                      children: [
                        _buildIncomeExpenseTab(),
                        _buildBalanceSheetTab(),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. आय-व्यय खाता व्यू (P&L Tab)
  // ==========================================
  Widget _buildIncomeExpenseTab() {
    return SingleChildScrollView(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: [
              // --- आय (INCOME) ---
              _tableSectionHeader("आय / प्राप्तियां (Income)"),
              ..._incomeItems.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableSubTotalRow("कुल आय (Total Income)", _totalIncome, Colors.green.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 16)), TableCell(child: SizedBox(height: 16))]),

              // --- व्यय (EXPENSE) ---
              _tableSectionHeader("व्यय / भुगतान (Expenditure)"),
              ..._expenseItems.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableSubTotalRow("कुल व्यय (Total Expense)", _totalExpense, Colors.red.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 16)), TableCell(child: SizedBox(height: 16))]),

              // --- शुद्ध लाभ/हानि (NET PROFIT) ---
              _tableFinalTotalRow(
                _netProfit >= 0 ? "शुद्ध बचत / लाभ (Net Profit)" : "शुद्ध हानि (Net Loss)", 
                _netProfit.abs(),
                _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. तुलन पत्र व्यू (Balance Sheet Tab)
  // ==========================================
  Widget _buildBalanceSheetTab() {
    double totalLiabilitiesSide = _totalLiabilities + _netProfit;

    return SingleChildScrollView(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: [
              // --- दायित्व (LIABILITIES) ---
              _tableSectionHeader("दायित्व (Liabilities)"),
              ..._liabilityItems.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              // लाभ को दायित्व (Liabilities) साइड में जोड़ा जाता है (Retained Earnings)
              _tableDataRow("इस अवधि का शुद्ध लाभ (Net Profit)", _netProfit),
              _tableSubTotalRow("कुल देयताएं (Total Liabilities)", totalLiabilitiesSide, Colors.blue.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 16)), TableCell(child: SizedBox(height: 16))]),

              // --- सम्पत्तियां (ASSETS) ---
              _tableSectionHeader("सम्पत्तियां (Assets)"),
              ..._assetItems.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableSubTotalRow("कुल सम्पत्तियां (Total Assets)", _totalAssets, Colors.blue.shade50),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Table UI Helpers (UI डिज़ाइन के लिए)
  // ==========================================
  
  TableRow _tableSectionHeader(String title) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade800),
      children: [
        Padding(padding: const EdgeInsets.all(10.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15))),
        const Padding(padding: EdgeInsets.all(10.0), child: Text("राशि (₹)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15), textAlign: TextAlign.right)),
      ],
    );
  }

  TableRow _tableDataRow(String title, double val) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0), child: Text(title, style: const TextStyle(fontSize: 14))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  TableRow _tableSubTotalRow(String title, double val, Color bgColor) {
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(padding: const EdgeInsets.all(10.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        Padding(padding: const EdgeInsets.all(10.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
      ],
    );
  }

  TableRow _tableFinalTotalRow(String title, double val, Color textColor) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        Padding(padding: const EdgeInsets.all(12.0), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
        Padding(padding: const EdgeInsets.all(12.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
      ],
    );
  }
}
