import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AIService {
  // 1. पीडीएफ फाइल से टेक्स्ट निकालने का फंक्शन
  static Future<String> extractTextFromPdf(String filePath) async {
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      
      // पीडीएफ डॉक्यूमेंट लोड करें
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      
      document.dispose(); // मेमोरी फ्री करें
      return text;
    } catch (e) {
      throw Exception("PDF रीड करने में त्रुटि: $e");
    }
  }

  // 2. जेमिनी एआई से बिल डेटा को स्ट्रक्चर्ड JSON में बदलने का फंक्शन
  static Future<Map<String, dynamic>> processBillWithGemini({
    required String pdfText,
    required String apiKey,
    required String modelName,
  }) async {
    try {
      // जेमिनी मॉडल इनिशियलाइज़ करें
      final model = GenerativeModel(
        model: modelName, 
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: "application/json"),
      );

      // एआई को सख्त निर्देश देने के लिए प्रॉम्प्ट (Prompt)
      final prompt = '''
      You are an expert accountant for Indian Dairy Cooperative Societies. 
      Analyze the following text extracted from a fortnightly milk bill and extract the exact accounting values.
      
      Text from PDF:
      $pdfText

      Return ONLY a valid JSON object matching this schema exactly. Do not include markdown formatting or extra text.
      If a field is missing, set its value to 0.0.
      
      JSON Schema:
      {
        "bill_no": "String (Extract bill number or unique id)",
        "start_date": "String (YYYY-MM-DD format)",
        "end_date": "String (YYYY-MM-DD format)",
        "total_milk": double (Total quantity of milk supplied in liters),
        "milk_payment": double (Total milk sales value/payable),
        "head_load": double (Head load charges or subsidy received),
        "overhead": double (Overhead commission received),
        "ghee_deduction": double (Deductions for ghee purchase if any),
        "cattle_feed_deduction": double (Deductions for cattle feed/pashu aahar if any)
      }
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null) {
        // एआई से मिले JSON रिस्पॉन्स को डिक्शनरी में बदलें
        final Map<String, dynamic> data = jsonDecode(response.text!);
        return data;
      } else {
        throw Exception("एआई से कोई जवाब नहीं मिला।");
      }
    } catch (e) {
      throw Exception("एआई प्रोसेसिंग में त्रुटि: $e");
    }
  }
}
