// lib/services/ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // 🚀 नया: इमेज और पीडीएफ बाइट्स हैंडल करने के लिए
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
  // 🚀 3. अपग्रेडेड मास्टर AI मुनीम + ऑडिटर (विज़न और डबल-काउंटिंग फिक्स के साथ)
  // ==========================================
  static Future<Map<String, dynamic>> processDocumentWithAuditorAI({
    String? documentText,     // नॉर्मल एक्सट्रैक्टेड टेक्स्ट (यदि उपलब्ध हो)
    Uint8List? fileBytes,     // 📸 नया: इमेज पीडीएफ या डायरेक्ट फोटो के बाइट्स
    String? mimeType,         // 🚀 नया: 'application/pdf', 'image/jpeg', 'image/png' आदि
    required String apiKey,
  }) async {
    
    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // जेमिनी सिर्फ शुद्ध JSON आउटपुट करेगा
      ),
    );

    // 🌟 सुपर प्रॉम्ट: डबल-काउंटिंग रोकने के लिए कड़े नियम
    final prompt = """
    You are an Elite Forensic Accountant and Chartered Auditor for a rural cooperative dairy society ERP system called "INS Rama".
    Analyze the provided document (which could be text, a scanned image PDF, or a photo of a Milk Bill, Bank Statement, Cash/Expense Voucher, or Stock Register).

    CRITICAL MANDATORY REQUIREMENT:
    - If the document contains ANY numbers, bill items, or financial figures, you MUST extract them into the "ledger_entries" array.
    - DO NOT leave "ledger_entries" empty if financial data is present.

    🚨 STRICT RULES TO PREVENT DOUBLE/TRIPLE COUNTING (मिल्क बिल फिक्स):
    1. If the document is a "Milk Bill" covering a period (e.g., 10 or 15 days), DO NOT create individual entries for each day/line item AND a separate entry for the "Total" or "Grand Total". This inflates the ledger.
    2. PREFERRED APPROACH FOR MILK BILLS: Create ONE single, consolidated transaction entry for the entire period's net business (e.g., Particulars: "15 दिनों की कुल दुग्ध बिक्री" or "दुग्ध खरीद Summary").
    3. IGNORE summary phrases like "Paid to Current Account", "Bank Transfer", "Net Payable", or "कुल देय राशि" as separate entries. They are settlement modes of the same bill, NOT a new income or expense transaction. 
    4. Never duplicate the same amount under different entry names.

    The JSON object MUST have exactly these two keys:
    1. "ledger_entries": A JSON array of transaction objects.
    2. "suspicious_notes": A JSON array of strings containing audit doubts or structural flags written in CLEAR HINDI language.

    --- Rules for "ledger_entries" ---
    Each transaction object inside the array must have:
    - date (String: Strictly YYYY-MM-DD format. If a period is given like 01 to 15, use the last date of that period. If missing, use current date)
    - particulars (String: Clear description in English or Hinglish specifying what the transaction represents)
    - amount (double: absolute numeric value, no commas or symbols)
    - type (String: strictly "DEBIT" or "CREDIT")
    - category (String: strictly one of "Income", "Expense", "Asset", "Liability")
    - doc_type (String: strictly one of "Milk Bill", "Voucher", "Bank Statement", "Minutes of Meeting", "Stock Register", "Other")

    Accounting Logic:
    - Revenues / Milk Sales / Money coming IN -> CREDIT, Income
    - Purchases / Cattle Feed / Deductions / Expenses / Money going OUT -> DEBIT, Expense

    --- Rules for "suspicious_notes" ---
    Analyze for mismatches, missing signatures, or abnormally high expenses. Write findings strictly in HINDI. If clean, return [].
    """;

    // 🚀 मल्टीमॉडल सपोर्ट: यदि फाइल बाइट्स उपलब्ध हैं, तो जेमिनी विज़न का उपयोग करें (इमेज/स्कैन्ड पीडीएफ के लिए)
    final List<Part> parts = [TextPart(prompt)];
    
    if (fileBytes != null && mimeType != null) {
      // जेमिनी सीधे इमेज या स्कैन्ड पीडीएफ फाइल को विजुअली देखकर प्रोसेस कर लेगा!
      parts.add(DataPart(mimeType, fileBytes));
    } else if (documentText != null && documentText.isNotEmpty) {
      // केवल टेक्स्ट होने पर टेक्स्ट पार्ट जोड़ें
      parts.add(TextPart("Document Text to Analyze:\n$documentText"));
    } else {
      throw Exception("क्रैश: जेमिनी को भेजने के लिए न तो टेक्स्ट मिला और न ही फ़ाइल बाइट्स!");
    }

    // जेमिनी को कॉल करें
    final response = await model.generateContent([Content.multi(parts)]);
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
  // 4. ACCOUNTING INSIGHT 
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
