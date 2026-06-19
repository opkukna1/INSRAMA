// lib/screens/accounts_screen.dart
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

  // 📊 1. Trading Account (व्यापारिक खाता - दुग्ध एवं फीड व्यापार)
  List<Map<String, dynamic>> _tradingIncome = [];
  List<Map<String, dynamic>> _tradingExpense = [];
  double _grossProfit = 0.0;
  double _totalTradingIncome = 0.0;
  double _totalTradingExpense = 0.0;

  // 📊 2. Profit & Loss / Income & Expenditure (लाभ-हानि खाता)
  List<Map<String, dynamic>> _pnlIncome = [];
  List<Map<String, dynamic>> _pnlExpense = [];
  double _netProfit = 0.0;
  double _totalPnlIncome = 0.0;
  double _totalPnlExpense = 0.0;

  // 📊 3. Balance Sheet (तुलन पत्र - संपत्ति और दायित्व)
  List<Map<String, dynamic>> _assetItems = [];
  List<Map<String, dynamic>> _liabilityItems = [];
  double _totalAssets = 0.0;
  double _totalLiabilities = 0.0;

  // खातों के नाम हिंदी रूपांतरण मैपिंग डिक्शनरी
  final Map<String, String> _headNamesHindi = {
    "none": "सामान्य प्रविष्टि / कोई नहीं", // 🚀 सुरक्षा के लिए 'none' फॉलबैक जोड़ा
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
        _selectedSocietyName = _societies.first['name'];
        _calculateFinancials(_selectedSocietyId!);
      }
    });
  }

  // 🚀 मास्टर कैलकुलेशन इंजन: Strict Account Head के आधार पर वर्गीकरण
  void _calculateFinancials(int societyId) async {
    setState(() { _isLoading = true; });
    
    final ledgerData = await DatabaseHelper.instance.getMasterLedger(societyId);
    
    List<Map<String, dynamic>> tInc = [], tExp = [], pInc = [], pExp = [], ast = [], lib = [];
    double sumTInc = 0, sumTExp = 0, sumPInc = 0, sumPExp = 0, sumAst = 0, sumLib = 0;

    for (var entry in ledgerData) {
      double amount = entry['amount'] ?? 0.0;
      String category = entry['category'] ?? '';
      String accountHead = entry['account_head'] ?? '';
      String particulars = (entry['particulars'] ?? '').toString().toLowerCase();

      // 🎯 एआई आधारित एकाउंट्स हेड फ़िल्टरिंग (100% सटीक)
      if (accountHead == 'milk_sales' || accountHead == 'feed_sales') {
        tInc.add(entry);
        sumTInc += amount;
      } 
      else if (accountHead == 'milk_purchase' || accountHead == 'feed_purchase') {
        tExp.add(entry);
        sumTExp += amount;
      } 
      else if (accountHead == 'miscellaneous_income') {
        pInc.add(entry);
        sumPInc += amount;
      } 
      else if (accountHead == 'establishment_expense' || accountHead == 'audit_fee_provision') {
        pExp.add(entry);
        sumPExp += amount;
      } 
      else if (accountHead == 'dairy_debtors' || category == 'Asset') {
        ast.add(entry);
        sumAst += amount;
      } 
      else if (accountHead == 'share_capital' || category == 'Liability') {
        lib.add(entry);
        sumLib += amount;
      }
      // 🛡️ फॉलबैक सुरक्षा (यदि पुरानी या मैन्युअल एंट्री में एकाउंट हेड मिसिंग हो)
      else {
        bool isTradingFallback = particulars.contains('milk') || particulars.contains('दूध') || particulars.contains('feed') || particulars.contains('पशु');
        if (category == 'Income') {
          if (isTradingFallback) { tInc.add(entry); sumTInc += amount; } 
          else { pInc.add(entry); sumPInc += amount; }
        } else if (category == 'Expense') {
          if (isTradingFallback) { tExp.add(entry); sumTExp += amount; } 
          else { pExp.add(entry); sumPExp += amount; }
        } else if (category == 'Asset') {
          ast.add(entry); sumAst += amount;
        } else if (category == 'Liability') {
          lib.add(entry); sumLib += amount;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _tradingIncome = tInc; _tradingExpense = tExp;
      _totalTradingIncome = sumTInc; _totalTradingExpense = sumTExp;
      _grossProfit = _totalTradingIncome - _totalTradingExpense;

      _pnlIncome = pInc; _pnlExpense = pExp;
      _totalPnlIncome = sumPInc; _totalPnlExpense = sumPExp;
      _netProfit = _grossProfit + _totalPnlIncome - _totalPnlExpense;

      _assetItems = ast; _liabilityItems = lib;
      _totalAssets = sumAst; _totalLiabilities = sumLib;
      
      _isLoading = false;
    });
  }

  // ==========================================
  // 🚀 अपग्रेडेड PDF जनरेशन रिपोर्ट लॉजिक
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
              child: pw.UrlLink(
                destination: '',
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(_selectedSocietyName.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("AUTOMATED FINAL FINANCIAL STATEMENT", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)), // 🔥 फिक्स: 'grey: true' को 'color: PdfColors.grey' में बदला
                    pw.SizedBox(height: 15),
                  ],
                ),
              ),
            ),
            
            // 1. Trading Account Summary
            pw.Text("1. TRADING ACCOUNT (Milk & Feed Operations)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Direct Trading Revenues (Sales):"), pw.Text("INR ${_totalTradingIncome.toStringAsFixed(2)}")]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Direct Operating Cost (Purchases):"), pw.Text("INR ${_totalTradingExpense.toStringAsFixed(2)}")]),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("GROWS PROFIT / SURPLUS:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("INR ${_grossProfit.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
            pw.SizedBox(height: 20),

            // 2. Profit & Loss Summary
            pw.Text("2. PROFIT & LOSS ACCOUNT (Income & Expenditure)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Gross Trading Profit Transferred:"), pw.Text("INR ${_grossProfit.toStringAsFixed(2)}")]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Indirect Miscellaneous Receipts:"), pw.Text("INR ${_totalPnlIncome.toStringAsFixed(2)}")]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Establishment & Administrative Provisions:"), pw.Text("INR ${_totalPnlExpense.toStringAsFixed(2)}")]),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("NET AUDITED PROFIT (Net Surplus):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)), pw.Text("INR ${_netProfit.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green))]),
            pw.SizedBox(height: 20),

            // 3. Balance Sheet Summary
            pw.Text("3. BALANCE SHEET (Financial Standing)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Assets (Receivables & Liquid Cash):"), pw.Text("INR ${_totalAssets.toStringAsFixed(2)}")]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Liabilities (Share Capital & Capital Fund):"), pw.Text("INR ${_totalLiabilities.toStringAsFixed(2)}")]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Retained Period Surplus (Net Profit):"), pw.Text("INR ${_netProfit.toStringAsFixed(2)}")]),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TOTAL LIABILITIES & CAPITAL EQUITY BALANCE:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("INR ${(_totalLiabilities + _netProfit).toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Audited_Report_${_selectedSocietyName.replaceAll(' ', '_')}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 ऑटोमेटेड फाइनल खाते', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, size: 24),
              tooltip: 'Download Audited PDF Report',
              onPressed: _generateAndSharePDF,
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            isScrollable: false,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.storefront_rounded), text: "Trading A/c"),
              Tab(icon: Icon(Icons.insights_rounded), text: "P&L Account"),
              Tab(icon: Icon(Icons.account_balance_rounded), text: "Balance Sheet"),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              // प्रीमियम सोसाइटी सेलेक्टर कार्ड
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.business_rounded, color: Colors.green.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedSocietyId,
                            isExpanded: true,
                            hint: const Text("सक्रिय सहकारी समिति चुनें"),
                            items: _societies.map((s) {
                              return DropdownMenuItem<int>(
                                value: s['id'] as int, 
                                child: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
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
                        _buildAccountTab(_tradingIncome, _tradingExpense, "जमा पक्ष / क्रेडिट आय (Revenues)", "नाम पक्ष / डेबिट खर्चे (Direct Costs)", _grossProfit, "सकल लाभ (Gross Profit)"),
                        _buildAccountTab(_pnlIncome, _pnlExpense, "अप्रत्यक्ष आय (Indirect Receipts)", "प्रशासनिक एवं स्थापना व्यय (Admin Cost)", _netProfit, "शुद्ध लाभ (Net Profit)"),
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
  // 🛠️ जेनेरिक टैब कंपोनेंट (Trading और P&L हेतु)
  // ==========================================
  Widget _buildAccountTab(List incomeList, List expenseList, String incomeTitle, String expTitle, double profitObj, String profitTitle) {
    double tInc = incomeList.fold(0, (sum, item) => sum + (item['amount'] ?? 0));
    double tExp = expenseList.fold(0, (sum, item) => sum + (item['amount'] ?? 0));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade200, width: 1, style: BorderStyle.solid),
            columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1)},
            children: [
              _tableSectionHeader(incomeTitle),
              if (incomeList.isEmpty) _tableEmptyRow() else ...incomeList.map((item) => _tableDataRow(item)),
              _tableSubTotalRow("कुल क्रेडिट योग", tInc, Colors.green.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 12)), TableCell(child: SizedBox(height: 12))]),

              _tableSectionHeader(expTitle),
              if (expenseList.isEmpty) _tableEmptyRow() else ...expenseList.map((item) => _tableDataRow(item)),
              _tableSubTotalRow("कुल डेबिट योग", tExp, Colors.red.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 12)), TableCell(child: SizedBox(height: 12))]),

              _tableFinalTotalRow(
                profitObj >= 0 ? profitTitle : "शुद्ध घाटा/हानि (Net Loss)", 
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
  // 🛠️ बैलेंस्ड बैलेंस शीट कंपोनेंट
  // ==========================================
  Widget _buildBalanceSheetTab() {
    double totalLiabilitiesSide = _totalLiabilities + _netProfit;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade200, width: 1),
            columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1)},
            children: [
              _tableSectionHeader("दायित्व एवं पूंजी (Liabilities & Capital)"),
              if (_liabilityItems.isEmpty && _netProfit == 0) _tableEmptyRow() else ..._liabilityItems.map((item) => _tableDataRow(item)),
              _tableCustomRow("इस अवधि का शुद्ध लाभ (Net Profit)", _netProfit, isBold: true, txtColor: Colors.green.shade900),
              _tableSubTotalRow("कुल दायित्व पक्ष (Total Liabilities)", totalLiabilitiesSide, Colors.blue.shade50),

              const TableRow(children: [TableCell(child: SizedBox(height: 14)), TableCell(child: SizedBox(height: 14))]),

              _tableSectionHeader("सम्पत्तियां एवं लेनदारियां (Assets & Receivables)"),
              if (_assetItems.isEmpty) _tableEmptyRow() else ..._assetItems.map((item) => _tableDataRow(item)),
              _tableSubTotalRow("कुल संपत्ति पक्ष (Total Assets)", _totalAssets, Colors.blue.shade50),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🎨 एडवांस यूआई रो कंपोनेंट्स ---
  TableRow _tableSectionHeader(String title) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
      children: [
        Padding(padding: const EdgeInsets.all(10.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))),
        const Padding(padding: EdgeInsets.all(10.0), child: Text("राशि (₹)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13), textAlign: TextAlign.right)),
      ],
    );
  }

  TableRow _tableDataRow(Map<String, dynamic> item) {
    String headKey = item['account_head'] ?? '';
    // यदि एआई हेड उपलब्ध है तो हिंदी नाम दिखाएं अन्यथा पर्टिकुलर्स
    String displayName = _headNamesHindi[headKey] ?? (item['particulars'] ?? 'अज्ञात मद');
    double val = item['amount'] ?? 0.0;
    bool isManual = (item['is_manual'] ?? 0) == 1;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0), 
          child: Row(
            children: [
              Expanded(child: Text(displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              // यदि मैन्युअल एंट्री है तो छोटा सा इंडिकेटर बैज दिखाएं
              if (isManual)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text("MANUAL", style: TextStyle(fontSize: 8, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
      ],
    );
  }

  TableRow _tableCustomRow(String title, double val, {bool isBold = false, Color? txtColor}) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(10.0), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: txtColor))),
        Padding(padding: const EdgeInsets.all(10.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: txtColor, fontFamily: 'monospace'))),
      ],
    );
  }

  TableRow _tableEmptyRow() {
    return const TableRow(
      children: [
        Padding(
          padding: EdgeInsets.all(10.0), 
          child: Text(
            "कोई प्रविष्टि दर्ज नहीं है", 
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic) // 🔥 फिक्स: 'style' की जगह 'fontStyle' किया
          )
        ),
        Padding(padding: EdgeInsets.all(10.0), child: Text("₹ 0.00", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey))),
      ],
    );
  }

  TableRow _tableSubTotalRow(String title, double val, Color bgColor) {
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(padding: const EdgeInsets.all(10.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Padding(padding: const EdgeInsets.all(10.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'))),
      ],
    );
  }

  TableRow _tableFinalTotalRow(String title, double val, Color textColor) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade100),
      children: [
        Padding(padding: const EdgeInsets.all(12.0), child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor))),
        Padding(padding: const EdgeInsets.all(12.0), child: Text("₹ ${val.toStringAsFixed(2)}", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor, fontFamily: 'monospace'))),
      ],
    );
  }
}
