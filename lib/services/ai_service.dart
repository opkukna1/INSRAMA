import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiAnalysisService {
  
  // 1. THE BRAIN 🧠 (Powered by Gemini)
  static Future<String> generateAccountingInsight({
    required String societyName,
    required double totalMilk,
    required double milkPayment,
    required double totalDeductions,
    required String period,
  }) async {
    try {
      // API Key .env से उठाना
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "Error: AI Auditor is currently sleeping. (API Key missing)";
      }

      // 🔥 मॉडल का नाम EXACTLY आपके दूसरे ऐप वाला 🔥
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview', 
        apiKey: apiKey,
      );

      // 🔥 INS RAMA ELITE ACCOUNTANT PROMPT 🔥
      final prompt = """
      You are an elite Milk Accounting Auditor and Business Mentor for a society accounting platform called "INS Rama".

      Your job is to analyze the society's financial data and provide a sharp, practical accounting insight — not generic motivation.

      Society Performance Data:
      - Society Name: $societyName
      - Period: $period
      - Total Milk Collected: ${totalMilk.toStringAsFixed(2)} Liters
      - Total Payment Earned: ₹${milkPayment.toStringAsFixed(2)}
      - Total Deductions (Ghee, Feed, etc.): ₹${totalDeductions.toStringAsFixed(2)}

      Instructions:
      1. Start with a short professional headline.
      2. Calculate the Net Income (Payment - Deductions) and briefly interpret what this means for the society's profitability.
      3. Identify if deductions are high compared to the overall payment.
      4. Provide a **3-step practical improvement strategy** specifically to manage overheads or improve milk quality.
      5. Give one **smart accounting/business strategy tip** (like ledger maintenance, deduction tracking, etc).
      6. End with a short motivating line like an expert auditor encouraging the society manager.

      Rules:
      - Use Markdown formatting (headings, bullet points).
      - Keep response under 180 words.
      - Write in natural Hinglish like a friendly mentor.
      - Avoid generic advice.
      - Sound like a real financial coach analyzing performance.
      """;

      // AI से रिस्पॉन्स मांगना
      final response = await model.generateContent([Content.text(prompt)]);
      
      return response.text ?? "We couldn't analyze the data right now. Please try again!";
      
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      // अगर AI फेल हो जाए तो एक डिफॉल्ट फॉलबैक मैसेज
      return """
🚨 AI Error Details: $e

---

### 📊 Basic Analysis for $societyName
- **Net Profit:** ₹${(milkPayment - totalDeductions).toStringAsFixed(2)}
- **Total Milk:** ${totalMilk.toStringAsFixed(2)} L
- **Deductions:** ₹${totalDeductions.toStringAsFixed(2)}

*Note: Connect to the internet for a detailed AI Auditor analysis!*
""";
    }
  }

  // PDF Text Extraction (बिल अपलोड करने के लिए)
  static Future<String> extractTextFromPdf(String path) async {
    // यहाँ आपका मौजूदा PDF रीड करने वाला कोड आएगा 
    return ""; 
  }
}
