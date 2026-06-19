// lib/screens/accounts_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/db_helper.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  String _selectedSocietyName = "Society";
  bool _isLoading = false;

  // 📊 Trading Account (दूध का व्यापार)
  List<Map<String, dynamic>> _tradingIncome = [];
  List<Map<String, dynamic>> _tradingExpense = [];
  double _grossProfit = 0.0;
  double _totalTradingIncome = 0.0;
  double _totalTradingExpense = 0.0;

  // 📊 Income & Expenditure / P&L (अन्य आय और व्यय)
  List<Map<String, dynamic>> _pnlIncome = [];
  List<Map<String, dynamic>> _pnlExpense = [];
  double _netProfit = 0.0;
  double _totalPnlIncome = 0.0;
  double _totalPnlExpense = 0.0;

  // 📊 Balance Sheet (संपत्तियां और दायित्व)
  List<Map<String, dynamic>> _assetItems = [];
  List<Map<String, dynamic>> _liabilityItems = [];
  double _totalAssets = 0.0;
  double _totalLiabilities = 0.0;

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
        _selectedSocietyName = _societies.first['name'];
        _calculateFinancials(_selectedSocietyId!);
      }
    });
  }

  void _calculateFinancials(int societyId) async {
    setState(() { _isLoading = true; });
    
    final ledgerData = await DatabaseHelper.instance.getMasterLedger(societyId);
    
    // टेम्परेरी लिस्ट्स
    List<Map<String, dynamic>> tInc = [], tExp = [], pInc = [], pExp = [], ast = [], lib = [];
    double sumTInc = 0, sumTExp = 0, sumPInc = 0, sumPExp = 0, sumAst = 0, sumLib = 0;

    for (var entry in ledgerData) {
      double amount = entry['amount'] ?? 0.0;
      String category = entry['category'] ?? '';
      String docType = entry['doc_type'] ?? '';
      String particulars = (entry['particulars'] ?? '').toString().toLowerCase();

      // 🚀 स्मार्ट फ़िल्टरिंग: अगर बिल दूध का है, तो ट्रेडिंग अकाउंट में जाएगा, वरना P&L में
      bool isTradingItem = docType == 'Milk Bill' || particulars.contains('milk') || particulars.contains('दूध');

      if (category == 'Income') {
        if (isTradingItem) { tInc.add(entry); sumTInc += amount; } 
        else { pInc.add(entry); sumPInc += amount; }
      } 
      else if (category == 'Expense') {
        if (isTradingItem) { tExp.add(entry); sumTExp += amount; } 
        else { pExp.add(entry); sumPExp += amount; }
      } 
      else if (category == 'Asset') {
        ast.add(entry); sumAst += amount;
      } 
      else if (category == 'Liability') {
        lib.add(entry); sumLib += amount;
      }
    }

    if (!mounted) return;
    setState(() {
      // Trading
      _tradingIncome = tInc; _tradingExpense = tExp;
      _totalTradingIncome = sumTInc; _totalTradingExpense = sumTExp;
      _grossProfit = _totalTradingIncome - _totalTradingExpense;

      // P&L
      _pnlIncome = pInc; _pnlExpense = pExp;
      _totalPnlIncome = sumPInc; _totalPnlExpense = sumPExp;
      // शुद्ध लाभ = ग्रॉस प्रॉफिट + अन्य आय - अन्य व्यय
      _netProfit = _grossProfit + _totalPnlIncome - _totalPnlExpense;

      // Balance Sheet
      _assetItems = ast; _liabilityItems = lib;
      _totalAssets = sumAst; _totalLiabilities = sumLib;
      
      _isLoading = false;
    });
  }

  // ==========================================
  // 🚀 PDF जनरेशन लॉजिक
  // ==========================================
  Future<void> _generateAndSharePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(_selectedSocietyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Final Financial Reports (Audited)", style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 10),
                ],
              ),
            ),
            
            // 1. Trading Account
            pw.Text("1. TRADING ACCOUNT (Milk Business)", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total Milk Sales (Income):"),
                pw.Text("Rs. ${_totalTradingIncome.toStringAsFixed(2)}"),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total Milk Purchase (Expense):"),
                pw.Text("Rs. ${_totalTradingExpense.toStringAsFixed(2)}"),
              ]
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("GROSS PROFIT:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Rs. ${_grossProfit.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 20),

            // 2. Income & Expenditure / P&L
            pw.Text("2. INCOME & EXPENDITURE A/C (P&L)", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Gross Profit Transferred:"),
                pw.Text("Rs. ${_grossProfit.toStringAsFixed(2)}"),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Other Incomes:"),
                pw.Text("+ Rs. ${_totalPnlIncome.toStringAsFixed(2)}"),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Other Expenses (Operating):"),
                pw.Text("- Rs. ${_totalPnlExpense.toStringAsFixed(2)}"),
              ]
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("NET PROFIT (Surplus):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Rs. ${_netProfit.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 20),

            // 3. Balance Sheet
            pw.Text("3. BALANCE SHEET", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total Assets:"),
                pw.Text("Rs. ${_totalAssets.toStringAsFixed(2)}"),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Total Liabilities:"),
                pw.Text("Rs. ${_totalLiabilities.toStringAsFixed(2)}"),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Retained Earnings (Net Profit):"),
                pw.Text("Rs. ${_netProfit.toStringAsFixed(2)}"),
              ]
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("TOTAL LIABILITIES + EQUITY:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Rs. ${(_totalLiabilities + _netProfit).toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]
            ),
          ];
        },
      ),
    );

    // PDF शेयर/डाउनलोड करें
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Financial_Report_${_selectedSocietyName.replaceAll(' ', '_')}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 🚀 3 टैब्स: Trading, P&L, Balance Sheet
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 वित्तीय खाते (Final Reports)', style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf), // 🚀 PDF डाउनलोड बटन
              tooltip: 'Download PDF',
              onPressed: _generateAndSharePDF,
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.storefront), text: "Trading A/c"),
              Tab(icon: Icon(Icons.analytics), text: "P&L (I&E)"),
              Tab(icon: Icon(Icons.account_balance), text: "Balance Sheet"),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // सोसाइटी ड्रॉपडाउन
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
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
                              return DropdownMenuItem<int>(
                                value: s['id'] as int, 
                                child: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold))
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final soc = _societies.firstWhere((s) => s['id'] == val);
                                setState(() { 
                                  _selectedSocietyId = val; 
                                  _selectedSocietyName = soc['name'];
                                });
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
              const SizedBox(height: 8),
              
              _isLoading 
                ? const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.green)))
                : Expanded(
                    child: TabBarView(
                      children: [
                        _buildAccountTab(_tradingIncome, _tradingExpense, "दुग्ध बिक्री (Milk Sales)", "दुग्ध खरीद (Milk Purchase)", _grossProfit, "सकल लाभ (Gross Profit)"),
                        _buildAccountTab(_pnlIncome, _pnlExpense, "अन्य आय (Other Incomes)", "अन्य व्यय (Operating Exp.)", _netProfit, "शुद्ध लाभ (Net Profit)"),
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
  // Generic Tab Builder (Trading और P&L के लिए)
  // ==========================================
  Widget _buildAccountTab(List incomeList, List expenseList, String incomeTitle, String expTitle, double profitObj, String profitTitle) {
    double tInc = incomeList.fold(0, (sum, item) => sum + (item['amount'] ?? 0));
    double tExp = expenseList.fold(0, (sum, item) => sum + (item['amount'] ?? 0));

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
              _tableSectionHeader(incomeTitle),
              ...incomeList.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableSubTotalRow("Total Credit", tInc, Colors.green.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 16)), TableCell(child: SizedBox(height: 16))]),

              _tableSectionHeader(expTitle),
              ...expenseList.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableSubTotalRow("Total Debit", tExp, Colors.red.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 16)), TableCell(child: SizedBox(height: 16))]),

              _tableFinalTotalRow(
                profitObj >= 0 ? profitTitle : "हानि (Loss)", 
                profitObj.abs(),
                profitObj >= 0 ? Colors.green.shade800 : Colors.red.shade800
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Balance Sheet Tab
  // ==========================================
  Widget _buildBalanceSheetTab() {
    double totalLiabilitiesSide = _totalLiabilities + _netProfit;

    return SingleChildScrollView(
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 1),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
            children: [
              _tableSectionHeader("दायित्व (Liabilities)"),
              ..._liabilityItems.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableDataRow("इस अवधि का शुद्ध लाभ (Net Profit)", _netProfit),
              _tableSubTotalRow("कुल देयताएं (Total Liabilities)", totalLiabilitiesSide, Colors.blue.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 16)), TableCell(child: SizedBox(height: 16))]),

              _tableSectionHeader("सम्पत्तियां (Assets)"),
              ..._assetItems.map((item) => _tableDataRow(item['particulars'] ?? 'Unknown', item['amount'])),
              _tableSubTotalRow("कुल सम्पत्तियां (Total Assets)", _totalAssets, Colors.blue.shade50),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---
  TableRow _tableSectionHeader(String title) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade800),
      children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
        const Padding(padding: EdgeInsets.all(8.0), child: Text("राशि (₹)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.right)),
      ],
    );
  }

  TableRow _tableDataRow(String title, double val) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0), child: Text(title, style: const TextStyle(fontSize: 13))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  TableRow _tableSubTotalRow(String title, double val, Color bgColor) {
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Padding(padding: const EdgeInsets.all(8.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      ],
    );
  }

  TableRow _tableFinalTotalRow(String title, double val, Color textColor) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        Padding(padding: const EdgeInsets.all(10.0), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor))),
        Padding(padding: const EdgeInsets.all(10.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor))),
      ],
    );
  }
}
