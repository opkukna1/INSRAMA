// lib/services/pdf_export_service.dart
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../engine/accounting_engine.dart';

class PdfExportService {
  static Future<void> generateAndShareManualAccounts(AccountingEngine engine, String societyName, String year) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // हैडर
            pw.Center(child: pw.Text(societyName.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text("Final Accounts | Audit Year: $year", style: const pw.TextStyle(fontSize: 12))),
            pw.SizedBox(height: 20),

            // 1. Receipts & Payments
            pw.Text("1. Receipts & Payments Account", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            _buildTShapeTable(
              leftHeader: "Receipts", rightHeader: "Payments",
              leftItems: engine.receipts, rightItems: engine.payments,
              leftTotal: engine.totalReceipts, rightTotal: engine.totalPayments,
              balancingLabelRight: "Closing Balance (Difference)", balancingAmountRight: engine.closingCashBal
            ),
            pw.SizedBox(height: 20),

            // 2. Trading Account
            pw.Text("2. Trading Account", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            _buildTShapeTable(
              leftHeader: "Particulars (Dr.)", rightHeader: "Particulars (Cr.)",
              leftItems: engine.tradingDr, rightItems: engine.tradingCr,
              leftTotal: max(engine.tradingDr.fold(0, (s, i) => s + i.amount) + engine.grossProfit, engine.tradingCr.fold(0, (s, i) => s + i.amount)),
              rightTotal: max(engine.tradingDr.fold(0, (s, i) => s + i.amount) + engine.grossProfit, engine.tradingCr.fold(0, (s, i) => s + i.amount)),
              balancingLabelLeft: engine.grossProfit >= 0 ? "Gross Profit (c/d)" : null,
              balancingAmountLeft: engine.grossProfit >= 0 ? engine.grossProfit : null,
              balancingLabelRight: engine.grossProfit < 0 ? "Gross Loss (c/d)" : null,
              balancingAmountRight: engine.grossProfit < 0 ? engine.grossProfit.abs() : null,
            ),
            pw.SizedBox(height: 20),

            // 3. Profit & Loss Account
            pw.Text("3. Profit & Loss Account", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            _buildTShapeTable(
              leftHeader: "Particulars (Dr.)", rightHeader: "Particulars (Cr.)",
              leftItems: engine.pnlDr, 
              rightItems: [LedgerItem(name: "Gross Profit (b/d)", amount: engine.grossProfit, category: "")]..addAll(engine.pnlCr),
              leftTotal: engine.pnlDr.fold(0, (s, i) => s + i.amount) + (engine.netProfit > 0 ? engine.netProfit : 0),
              rightTotal: engine.pnlDr.fold(0, (s, i) => s + i.amount) + (engine.netProfit > 0 ? engine.netProfit : 0), // Both sides equal
              balancingLabelLeft: engine.netProfit >= 0 ? "Net Profit" : null,
              balancingAmountLeft: engine.netProfit >= 0 ? engine.netProfit : null,
            ),
            pw.SizedBox(height: 20),

            // 4. Balance Sheet
            pw.Text("4. Balance Sheet", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            _buildTShapeTable(
              leftHeader: "Liabilities", rightHeader: "Assets",
              leftItems: engine.liabilities, rightItems: engine.assets,
              leftTotal: engine.balanceSheetTotals['Total Liabilities']!, 
              rightTotal: engine.balanceSheetTotals['Total Assets']!,
              balancingLabelLeft: "Add: Net Profit", balancingAmountLeft: engine.netProfit,
            ),
          ];
        },
      ),
    );

    // PDF शेयर/डाउनलोड करें
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Manual_Accounts_$year.pdf');
  }

  // 🚀 T-Shape (दोहरा लेखा) टेबल बनाने का जादुई विज़ेट
  static pw.Widget _buildTShapeTable({
    required String leftHeader, required String rightHeader,
    required List<LedgerItem> leftItems, required List<LedgerItem> rightItems,
    required double leftTotal, required double rightTotal,
    String? balancingLabelLeft, double? balancingAmountLeft,
    String? balancingLabelRight, double? balancingAmountRight,
  }) {
    int maxRows = max(leftItems.length + (balancingLabelLeft != null ? 1 : 0), 
                      rightItems.length + (balancingLabelRight != null ? 1 : 0));
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(1),
      },
      children: [
        // Headers
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(leftHeader, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(rightHeader, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          ]
        ),
        // Data Rows
        for (int i = 0; i < maxRows; i++)
          pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_getItemName(leftItems, i, balancingLabelLeft))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_getItemAmt(leftItems, i, balancingAmountLeft), textAlign: pw.TextAlign.right)),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_getItemName(rightItems, i, balancingLabelRight))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_getItemAmt(rightItems, i, balancingAmountRight), textAlign: pw.TextAlign.right)),
            ]
          ),
        // Total Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(leftTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(rightTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          ]
        ),
      ]
    );
  }

  static String _getItemName(List<LedgerItem> list, int index, String? balancingLabel) {
    if (index < list.length) return list[index].name;
    if (index == list.length && balancingLabel != null) return balancingLabel;
    return "";
  }

  static String _getItemAmt(List<LedgerItem> list, int index, double? balancingAmt) {
    if (index < list.length) return list[index].amount.toStringAsFixed(2);
    if (index == list.length && balancingAmt != null) return balancingAmt.toStringAsFixed(2);
    return "";
  }
}
