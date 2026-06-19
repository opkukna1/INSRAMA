// lib/services/ai_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiAnalysisService {
  
  // 1. AI Analysis Service (INS Rama Edition)
  static Future<String> generateFinancialAnalysis({
    required String societyName,
    required double totalMilk,
    required double totalPayment,
    required double totalDeductions,
    required String period,
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "Error: AI Service is not configured. (API Key missing)";
      }

      // 'gemini-1.5-flash' सबसे स्टेबल और फास्ट है
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', 
        apiKey: apiKey,
      );

      final prompt = """
      You are an expert Milk Accounting Auditor and Business Mentor for "INS Rama".
      Your job is to analyze the milk collection data for a society and provide sharp, practical financial insights.

      Data for Analysis:
      - Society Name: $societyName
      - Period: $period
      - Total Milk Collected: ${totalMilk.toStringAsFixed(2)} Liters
      - Total Payment: ₹${totalPayment.toStringAsFixed(2)}
      - Total Deductions (Ghee, Feed, etc.): ₹${totalDeductions.toStringAsFixed(2)}

      Instructions:
      1. Start with a professional observation of the society's performance.
      2. Analyze the net income (Payment - Deductions).
      3. Identify if deductions are high compared to the milk volume.
      4. Give 3 practical tips to improve profit or efficiency for the society.
      5. Sound like an experienced Financial Consultant/Accountant.
      
      Rules:
      - Use Markdown formatting.
      - Keep response under 150 words.
      - Write in a professional yet friendly Hinglish tone.
      - Do not use generic advice. Focus on milk accounting data.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Analysis currently unavailable.";
      
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "🚨 AI Analysis Error: Could not generate insight at the moment.";
    }
  }

  // PDF Text Extraction (जो आपके पुराने काम में था)
  static Future<String> extractTextFromPdf(String path) async {
    // यहाँ अपना PDF एक्सट्रैक्शन कोड रखें (जो आप पहले इस्तेमाल कर रहे थे)
    return "Dummy extracted text"; 
  }
}
