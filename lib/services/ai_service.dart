// lib/services/ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // इमेज और पीडीएफ बाइट्स हैंडल करने के लिए
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:crypto/crypto.dart'; 

class AIService {
  
  // ==========================================
  // 1. PDF से टेक्स्ट निकालने का कोड (नॉर्मल टेक्स्ट पीडीएफ के लिए)
  // ==========================================
  static Future<String> extractTextFromPdf(String path) async {
    try {
      final File file = File(path);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();
      return extractedText;
    } catch (e) {
      debugPrint("PDF Extraction Error: $e");
      return ""; 
    }
  }

  // ==========================================
  // 2. फाइल का SHA-256 हैश निकालना (डुप्लीकेट रोकने के लिए)
  // ==========================================
  static Future<String> getFileHash(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ==========================================
  // 🚀 3. अपग्रेडेड मास्टर AI मुनीम (🌟 हेड लोड, ओवरहेड, लीटर और घी कटौती ब्रेकडाउन फिक्स)
  // ==========================================
  static Future<Map<String, dynamic>> processDocumentWithAuditorAI({
    String? documentText,     // नॉर्मल एक्सट्रैक्टेड टेक्स्ट (यदि उपलब्ध हो)
    Uint8List? fileBytes,     // 📸 इमेज पीडीएफ या डायरेक्ट फोटो के बाइट्स
    String? mimeType,         // 'application/pdf', 'image/jpeg', 'image/png' आदि
    required String apiKey,
  }) async {
    
    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // जेमिनी सिर्फ शुद्ध JSON आउटपुट करेगा
      ),
    );

    // 🌟 अपग्रेडेड प्रॉम्ट: इसमें प्रत्येक कंपोनेंट का अलग-अलग ब्रेकडाउन नियम शामिल है
    final prompt = """
    You are an Elite Forensic Accountant and Chartered Auditor for a rural cooperative dairy society ERP system called "INS Rama".
    Analyze the provided document (text, scanned image PDF, or a photo of a Milk Bill, Bank Statement, Cash/Expense Voucher, or Stock Register).

    CRITICAL MANDATORY REQUIREMENT:
    - Extract financial figures into the "ledger_entries" array. Do not leave it empty if data is present.
    - Write strict audit findings in "suspicious_notes" in clear HINDI language.

    🚨 STRICT MILK BILL BREAKDOWN RULES (दुग्ध बिल का संपूर्ण वर्गीकरण):
    When analyzing a "Milk Bill" covering a supply period, DO NOT create a single aggregated total entry. You MUST identify and split individual items into separate distinct ledger rows inside the "ledger_entries" array:
    1. Gross Milk Sales: Create a separate row. Calculate total liters/quantity and mention it clearly in the 'particulars' field (e.g., 'Milk Sale Collection - 1450.5 Liters').
    2. Head Load Earnings (हेड लोड आय): Create a separate row. This is an INCOME for the society.
    3. Overhead Earnings (ओवरहेड आय): Create a separate row. This is also an INCOME for the society.
    4. Ghee Katoti Deduction (घी कटौती खरीद): If any amount is deducted for Ghee under 'घी कटौती', create a separate row treating it as Ghee Purchase (DEBIT / Expense).

    The JSON object MUST have exactly these two keys:
    1. "ledger_entries": A JSON array of transaction objects.
    2. "suspicious_notes": A JSON array of strings containing audit doubts or structural flags written in HINDI.

    --- Rules for "ledger_entries" ---
    Each transaction object inside the array must have exactly these keys:
    - date (String: Strictly YYYY-MM-DD format. If a period is given, use the last date of that period).
    - particulars (String: Clear description in English or Hinglish including quantity like 'Milk Sale Collection - [Liters] Ltr' or 'Head Load Recovery Income').
    - amount (double: absolute numeric value, no commas or currency symbols).
    - type (String: strictly "DEBIT" or "CREDIT").
    - category (String: strictly one of "Income", "Expense", "Asset", "Liability").
    - doc_type (String: strictly one of "Milk Bill", "Voucher", "Bank Statement", "Other").
    - account_head (String: You MUST map the transaction strictly to one of these exact string values based on context):
      * "milk_purchase" -> For raw milk bought/collected from members (Debit, Expense, goes to Trading Account)
      * "milk_sales" -> For gross milk sold to the Dairy Union (Credit, Income, goes to Trading Account)
      * "head_load" -> For transport/handling income recovered on the bill (Credit, Income, goes to P&L Account)
      * "overhead_load" -> For overhead charges income recovered on the bill (Credit, Income, goes to P&L Account)
      * "ghee_katoti" -> For ghee deduction representing ghee purchase stock (Debit, Expense, goes to Trading Account)
      * "feed_purchase" -> For purchasing cattle feed/dana stock for society (Debit, Expense, goes to Trading Account)
      * "feed_sales" -> For selling cattle feed/dana to members (Credit, Income, goes to Trading Account)
      * "establishment_expense" -> For salaries, secretary honorarium, stationery, refreshments (Debit, Expense, goes to P&L Account)
      * "audit_fee_provision" -> For audit fees or audit provisions mentioned (Debit, Expense, goes to P&L Account)
      * "miscellaneous_income" -> For any other small income or penalties collected (Credit, Income, goes to P&L Account)
      * "share_capital" -> For member share capital deposits or increases (Credit, Liability, goes to Balance Sheet)
      * "dairy_debtors" -> For outstanding dues receivable from the main dairy union (Debit, Asset, goes to Balance Sheet)

    Accounting Logic Reference:
    - Money coming IN / Sales / Head Load & Overhead Revenue -> CREDIT (Income)
    - Money going OUT / Purchases / Ghee Deduction Stock -> DEBIT (Expense)
    """;

    final List<Part> parts = [TextPart(prompt)];
    
    if (fileBytes != null && mimeType != null) {
      parts.add(DataPart(mimeType, fileBytes));
    } else if (documentText != null && documentText.isNotEmpty) {
      parts.add(TextPart("Document Text to Analyze:\n$documentText"));
    } else {
      throw Exception("क्रैश: जेमिनी को भेजने के लिए न तो टेक्स्ट मिला और न ही फ़ाइल बाइट्स!");
    }

    final response = await model.generateContent([Content.multi(parts)]);
    String responseText = response.text ?? "{}";

    // क्लीनिंग (मार्कडाउन रिमूवल)
    responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

    try {
      Map<String, dynamic> parsedResult = jsonDecode(responseText);
      return parsedResult;
    } catch (e) {
      throw Exception("AI ने सही ऑडिटिंग फॉर्मेट (JSON) में रिपॉन्स नहीं दिया: $e");
    }
  }

  // ==========================================
  // 4. ACCOUNTING INSIGHT (डैशबोर्ड विश्लेषण)
  // ==========================================
  static Future<String> generateAccountingInsight({
    required String societyName,
    required double totalMilk,
    required double milkPayment,
    required double totalDeductions,
    required String period,
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "Error: AI Auditor is currently sleeping. (API Key missing)";
      }

      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', 
        apiKey: apiKey,
      );

      final prompt = """
      You are an elite Milk Accounting Auditor and Business Mentor for a society accounting platform called "INS Rama".
      Analyze the society's financial data and provide a sharp, practical accounting insight.

      Society Performance Data:
      - Society Name: $societyName
      - Period: $period
      - Total Milk Collected: ${totalMilk.toStringAsFixed(2)} Liters
      - Total Payment Earned: ₹${milkPayment.toStringAsFixed(2)}
      - Total Deductions (Ghee, Feed, etc.): ₹${totalDeductions.toStringAsFixed(2)}

      Instructions: Use Markdown formatting. Keep under 180 words. Write in natural Hinglish.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "We couldn't analyze the data right now.";
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "🚨 AI Analysis Error: Could not generate insight at the moment.";
    }
  }
}
