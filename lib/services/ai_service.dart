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

  // 2. जेमिनी एआई से बिल डेटा को स्ट्रक्चर्ड JSON में बदलने का फंक्शन (v2 Method)
  static Future<Map<String, dynamic>> processBillWithGemini({
    required String pdfText,
    required String apiKey,
    // यहाँ डिफ़ॉल्ट रूप से Gemini 3.1 Flash Lite Preview सेट कर दिया है
    String modelName = 'gemini-3.1-flash-lite-preview', 
  }) async {
    try {
      // 🔥 v2 मेथड: Schema डिफाइन करना (Structured Outputs)
      // यह जेमिनी को सटीक JSON फॉर्मेट देने के लिए बाध्य करता है
      final responseSchema = Schema.object(
        properties: {
          "bill_no": Schema.string(description: "Extract bill number or unique id"),
          "start_date": Schema.string(description: "YYYY-MM-DD format"),
          "end_date": Schema.string(description: "YYYY-MM-DD format"),
          "total_milk": Schema.number(description: "Total quantity of milk supplied in liters. If missing, return 0.0"),
          "milk_payment": Schema.number(description: "Total milk sales value/payable. If missing, return 0.0"),
          "head_load": Schema.number(description: "Head load charges or subsidy received. If missing, return 0.0"),
          "overhead": Schema.number(description: "Overhead commission received. If missing, return 0.0"),
          "ghee_deduction": Schema.number(description: "Deductions for ghee purchase if any. If missing, return 0.0"),
          "cattle_feed_deduction": Schema.number(description: "Deductions for cattle feed/pashu aahar if any. If missing, return 0.0"),
        },
        requiredProperties: [
          "bill_no", "start_date", "end_date", "total_milk", 
          "milk_payment", "head_load", "overhead", 
          "ghee_deduction", "cattle_feed_deduction"
        ],
      );

      // जेमिनी मॉडल इनिशियलाइज़ करें
      final model = GenerativeModel(
        model: modelName, 
        apiKey: apiKey,
        // 🚀 Preview मॉडल्स के लिए API वर्शन को ओवरराइड करना ज़रूरी है
        // 'v1alpha' का इस्तेमाल सबसे नए preview मॉडल्स को एक्सेस करने के लिए होता है
        requestOptions: const RequestOptions(apiVersion: 'v1alpha'), 
        generationConfig: GenerationConfig(
          responseMimeType: "application/json",
          responseSchema: responseSchema, // नया v2 स्ट्रक्चर्ड आउटपुट तरीका
        ),
      );

      // अब प्रॉम्प्ट एकदम छोटा और साफ हो गया है
      final prompt = '''
      You are an expert accountant for Indian Dairy Cooperative Societies. 
      Analyze the following text extracted from a fortnightly milk bill and extract the exact accounting values.
      
      Text from PDF:
      $pdfText
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
