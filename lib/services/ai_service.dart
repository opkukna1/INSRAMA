import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; // PDF रीड करने के लिए

class AIService {
  
  // ==========================================
  // 1. PDF से टेक्स्ट निकालने का असली कोड
  // ==========================================
  static Future<String> extractTextFromPdf(String path) async {
    try {
      // PDF फाइल को लोड करें
      final File file = File(path);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // टेक्स्ट एक्सट्रेक्ट करें
      String extractedText = PdfTextExtractor(document).extractText();
      
      // मेमोरी फ्री करने के लिए डॉक्यूमेंट क्लोज करें
      document.dispose();

      return extractedText;
    } catch (e) {
      debugPrint("PDF Extraction Error: $e");
      return ""; // अगर कोई दिक्कत आए तो खाली स्ट्रिंग भेजेगा
    }
  }

  // ==========================================
  // 2. बिल प्रोसेसिंग (Gemini AI से JSON निकालना)
  // ==========================================
  static Future<Map<String, dynamic>> processBillWithGemini({
    required String pdfText,
    required String apiKey,
    // पुराने कोड को सपोर्ट करने के लिए पैरामीटर रखा है, पर इस्तेमाल अपना फिक्स मॉडल ही होगा
    String? modelName, 
  }) async {
    
    // 🔥 यहाँ आपका बताया हुआ मॉडल 'gemini-3.1-flash-lite-preview' फिक्स कर दिया है
    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview', 
      apiKey: apiKey,
    );

    // AI को सख्त निर्देश कि सिर्फ JSON दे
    final prompt = """
    You are an expert data extraction AI. Analyze the following milk society bill text in Hindi/English and extract the data into a strict JSON format.
    Return ONLY valid JSON. Do not include markdown formatting like ```json.

    Required fields in JSON:
    - bill_no (String)
    - start_date (String: DD-MM-YYYY format)
    - end_date (String: DD-MM-YYYY format)
    - total_milk (double: total milk volume)
    - milk_payment (double: main payment amount)
    - head_load (double, default 0.0)
    - overhead (double, default 0.0)
    - ghee_deduction (double, default 0.0)
    - cattle_feed_deduction (double, default 0.0)

    Bill Text:
    $pdfText
    """;

    final response = await model.generateContent([Content.text(prompt)]);
    String responseText = response.text ?? "{}";

    // अगर AI गलती से ```json लगा दे, तो उसे साफ़ करना
    responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

    // JSON को Map में बदलकर रिटर्न करना
    try {
      return jsonDecode(responseText);
    } catch (e) {
      throw Exception("AI ने सही JSON डेटा नहीं दिया: $e");
    }
  }

  // ==========================================
  // 3. ACCOUNTING INSIGHT (हमारा नया AI मेंटर कोड)
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

      // 🔥 यहाँ भी आपका बताया हुआ 'gemini-3.1-flash-lite-preview' फिक्स कर दिया है
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', 
        apiKey: apiKey,
      );

      final prompt = """
      You are an elite Milk Accounting Auditor and Business Mentor for a society accounting platform called "INS Rama".

      Your job is to analyze the society's financial data and provide a sharp, practical accounting insight.

      Society Performance Data:
      - Society Name: $societyName
      - Period: $period
      - Total Milk Collected: ${totalMilk.toStringAsFixed(2)} Liters
      - Total Payment Earned: ₹${milkPayment.toStringAsFixed(2)}
      - Total Deductions (Ghee, Feed, etc.): ₹${totalDeductions.toStringAsFixed(2)}

      Instructions:
      1. Start with a short professional headline.
      2. Calculate the Net Income (Payment - Deductions).
      3. Identify if deductions are high.
      4. Provide a **3-step practical improvement strategy**.
      5. Give one **smart accounting tip**.
      6. End with a short motivating line.

      Rules:
      - Use Markdown formatting.
      - Keep response under 180 words.
      - Write in natural Hinglish.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "We couldn't analyze the data right now.";
      
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "🚨 AI Analysis Error: Could not generate insight at the moment.";
    }
  }
}
