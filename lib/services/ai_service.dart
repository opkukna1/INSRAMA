// lib/services/ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:crypto/crypto.dart'; // 🚀 नया: फाइल का यूनीक Hash (DNA) निकालने के लिए

class AIService {
  
  // ==========================================
  // 1. PDF से टेक्स्ट निकालने का कोड
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
  // 🚀 2. फाइल का SHA-256 हैश निकालना (डुप्लीकेट रोकने के लिए)
  // ==========================================
  static Future<String> getFileHash(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ==========================================
  // 🚀 3. मास्टर AI मुनीम + ऑडिटर (डेटा एक्सट्रैक्शन और संदिग्ध गड़बड़ियां)
  // ==========================================
  static Future<Map<String, dynamic>> processDocumentWithAuditorAI({
    required String documentText,
    required String apiKey,
  }) async {
    
    // 🔥 मॉडल को 'gemini-3.1-flash-lite-preview' पर फिक्स किया गया है
    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview', 
      apiKey: apiKey,
    );

    // AI को सख्त निर्देश कि वो मुनीम और ऑडिटर दोनों का रोल निभाए
    final prompt = """
    You are an Elite Forensic Accountant and Chartered Auditor for a rural cooperative society ERP system called "INS Rama".
    Analyze the given text which can be a Milk Bill, Bank Statement, Cash/Expense Voucher, Stock Register, or Minutes of Meeting (मीटिंग की कार्यवाही).

    Extract financial entries and simultaneously audit the text for any anomalies, doubts, discrepancies, missing information, or suspicious patterns.

    Return ONLY a single valid JSON object. Do NOT wrap the response in markdown like ```json or ```. 

    The JSON object MUST have exactly these two keys:
    1. "ledger_entries": A JSON array of transaction objects.
    2. "suspicious_notes": A JSON array of strings containing audit doubts or suspicious flags written in CLEAR HINDI language.

    --- Rules for "ledger_entries" ---
    Each transaction object inside the array must have:
    - date (String: DD-MM-YYYY format. If date is missing, use current date or best estimate)
    - particulars (String: Clear description in English or Hinglish)
    - amount (double: absolute numeric value)
    - type (String: strictly "DEBIT" or "CREDIT")
    - category (String: strictly one of "Income", "Expense", "Asset", "Liability")
    - doc_type (String: strictly one of "Milk Bill", "Voucher", "Bank Statement", "Minutes of Meeting", "Stock Register", "Other")

    Accounting Guide:
    - Money coming IN / Revenues / Incomes -> CREDIT, Income
    - Money going OUT / Expenses / Purchases / Deductions -> DEBIT, Expense
    - Cash withdrawals from bank -> DEBIT Cash (Asset), CREDIT Bank (Asset)
    - For Minutes of Meeting: If financial resolutions/grants/penalties are passed, create a ledger entry for estimated value.

    --- Rules for "suspicious_notes" ---
    Analyze the document for internal contradictions, high-risk items, or structural doubts. Write your findings as a list of strings strictly in HINDI.
    Look for:
    - Missing signatures or invoice numbers mentioned in text.
    - Large cash transactions mentioned instead of bank transfers.
    - Mathematical mismatch in totals or deductions.
    - In Minutes of Meetings, note down if any member raised a protest, or if any expenditure was approved without proper quotation or look unusual.
    - If everything looks perfectly fine, return an empty array [].

    Document Text to Analyze:
    $documentText
    """;

    final response = await model.generateContent([Content.text(prompt)]);
    String responseText = response.text ?? "{}";

    // क्लीनिंग
    responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

    try {
      Map<String, dynamic> parsedResult = jsonDecode(responseText);
      return parsedResult;
    } catch (e) {
      throw Exception("AI ने सही ऑडिटिंग फॉर्मेट (JSON) में रिपॉन्स नहीं दिया: $e");
    }
  }

  // ==========================================
  // 4. ACCOUNTING INSIGHT (वही पुराना कोड)
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
