// lib/services/pdf_report_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  
  static Future<void> downloadAuditReportPdf({
    required String societyName,
    required Map<String, double> data, // DatabaseHelper.instance.calculateFourAccounts से आया डेटा
  }) async {
    final pdf = pw.Document();

    // देवनागरी (हिंदी) लिखावट सपोर्ट के लिए सुंदर फॉन्ट लोड करना
    final hindiFont = await PdfGoogleFonts.hindRegular();
    final hindiBold = await PdfGoogleFonts.hindBold();
    final styleNormal = pw.TextStyle(font: hindiFont, fontSize: 11);
    final styleBold = pw.TextStyle(font: hindiBold, fontSize: 11, bold: true);

    // साझा हेडर विज़ेट (पल्ला रिपोर्ट पैटर्न)
    pw.Widget buildHeader(String title) {
      return pw.Column(
        children: [
          pw.Center(
            child: pw.Text(
              "प्राइमरी $societyName दुग्ध उत्पादक सहकारी समिति लि०",
              style: pw.TextStyle(font: hindiBold, fontSize: 15, bold: true),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: pw.Text("ऑडिट वर्ष: 2024-25 | अंतिम खाते (Final Accounts)", style: styleNormal),
          ),
          pw.SizedBox(height: 5),
          pw.Center(child: pw.Text(title, style: pw.TextStyle(font: hindiBold, fontSize: 13, color: PdfColors.blue900))),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 10),
        ]
      );
    }

    // =========================================================
    // 1. खाता पेज: आय-व्यय खाता (RECEIPTS & PAYMENTS ACCOUNT)
    // =========================================================
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        cross: pw.CrossAxisAlignment.start,
        children: [
          buildHeader("1. आय-व्यय खाता / रोकड़ बही सारांश (Receipts & Payments)"),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("प्राप्तियां (Receipts Side)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("भुगतान (Payments Side)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("प्रारम्भिक रोकड़ शेष (Opening Cash)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['openingCash']!.toStringAsFixed(2), style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("सदस्यों को दुग्ध खरीद भुगतान", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['milkPurchase']!.toStringAsFixed(2), style: styleNormal)), // 846640.00
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("डेयरी संघ से प्राप्त दूध बिल राशि", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['milkSales']!.toStringAsFixed(2), style: styleNormal)), // 857528.45
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("संस्थापन/ऑडिट खर्च भुगतान", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['establishmentExpense']!.toStringAsFixed(2), style: styleNormal)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("विविध नकद प्राप्तियां", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['miscIncome']!.toStringAsFixed(2), style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("अंतिम रोकड़ बाकी (Closing Cash) [खेप]", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['closingCash']!.toStringAsFixed(2), style: styleBold)), // 7538.18
                ]
              ),
            ]
          )
        ]
      )
    ));

    // =========================================================
    // 2. खाता पेज: व्यापार खाता (TRADING ACCOUNT)
    // =========================================================
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        cross: pw.CrossAxisAlignment.start,
        children: [
          buildHeader("2. व्यापार खाता (Trading Account)"),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("नाम पक्ष (Debit / खर्चे)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("जमा पक्ष (Credit / व्यापार आय)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("कुल दुग्ध खरीद (Milk Purchase)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['milkPurchase']!.toStringAsFixed(2), style: styleNormal)), // 846640.00
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("कुल दुग्ध बिक्री (Milk Sales)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['milkSales']!.toStringAsFixed(2), style: styleNormal)), // 857528.45
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("पशु आहार/दाना खरीद", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['feedPurchase']!.toStringAsFixed(2), style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("पशु आहार/दाना बिक्री", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['feedSales']!.toStringAsFixed(2), style: styleNormal)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("सकल लाभ (Gross Profit) c/o", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['grossProfit']!.toStringAsFixed(2), style: styleBold)), // 39070.18
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-")),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-")),
                ]
              ),
            ]
          )
        ]
      )
    ));

    // =========================================================
    // 3. खाता पेज: लाभ-हानि खाता (PROFIT & LOSS ACCOUNT)
    // =========================================================
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        cross: pw.CrossAxisAlignment.start,
        children: [
          buildHeader("3. लाभ-हानि खाता (Profit & Loss Account)"),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("व्यय / हानियां (Expenses)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("आय / लाभ (Incomes)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("संस्थापन व्यय (Establishment Expenses)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['establishmentExpense']!.toStringAsFixed(2), style: styleNormal)), // 5756.00
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("सकल लाभ (Gross Profit) b/f", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['grossProfit']!.toStringAsFixed(2), style: styleNormal)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ऑडिट फीस प्रावधान (Audit Fee Provision)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['auditFee']!.toStringAsFixed(2), style: styleNormal)), // 3240.00
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("विविध/अन्य प्रत्यक्ष आय (Misc Income)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['miscIncome']!.toStringAsFixed(2), style: styleNormal)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("शुद्ध लाभ (Net Profit) [बचत]", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['netProfit']!.toStringAsFixed(2), style: styleBold)), // 30244.18
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-")),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-")),
                ]
              ),
            ]
          )
        ]
      )
    ));

    // =========================================================
    // 4. खाता पेज: संतुलन चित्र (BALANCE SHEET)
    // =========================================================
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        cross: pw.CrossAxisAlignment.start,
        children: [
          buildHeader("4. संतुलन चित्र (Balance Sheet)"),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("दायित्व पक्ष (Liabilities)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("सम्पत्तियां पक्ष (Assets)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("राशि (₹)", style: styleBold)),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("सहकारी हिस्सा पूंजी (Share Capital)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['shareCapital']!.toStringAsFixed(2), style: styleNormal)), // 2000.00
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("अंतिम रोकड़ बाकी (Closing Cash in Hand)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['closingCash']!.toStringAsFixed(2), style: styleNormal)), // 7538.18
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ऑडिट फीस देय (Audit Fee Payable)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['auditFee']!.toStringAsFixed(2), style: styleNormal)), // 3240.00
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("डेयरी संघ से दूध की बकाया राशि (Debtors)", style: styleNormal)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['dairyDebtors']!.toStringAsFixed(2), style: styleNormal)), // 48994.00
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("चालू वर्ष का शुद्ध लाभ (Current Net Profit)", style: styleBold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['netProfit']!.toStringAsFixed(2), style: styleBold)), // 30244.18
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-")),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-")),
                ]
              ),
            ]
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            main: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("हस्ताक्षर: व्यवस्थापक / सचिव", style: styleNormal),
              pw.Text("जांचकर्ता: निरीक्षक / ऑडिटर सहकारी समितियां", style: styleNormal),
            ]
          )
        ]
      )
    ));

    // फोन स्क्रीन पर प्रिंटर/डाउनलोड शीट खोलें
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
