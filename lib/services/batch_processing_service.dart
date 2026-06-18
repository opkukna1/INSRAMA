// lib/services/batch_processing_service.dart

import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import 'ai_service.dart';

class BatchProcessingService {
  
  // यह फंक्शन मल्टीपल फाइल्स लेगा, AI से प्रोसेस कराएगा और डेटाबेस में सेव करेगा
  static Future<void> pickAndProcessMultiplePdfs({
    required String apiKey,
    // UI में प्रोग्रेस बार (Progress Bar) दिखाने के लिए कॉलबैक
    Function(int current, int total, String fileName)? onProgress, 
  }) async {
    try {
      // 1. यूज़र से एक साथ कई PDF सेलेक्ट करवाना
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true, // 👈 यही वो जादू है जिससे एक साथ कई फाइलें सेलेक्ट होंगी
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        int totalFiles = result.files.length;
        DBHelper dbHelper = DBHelper();

        // 2. लूप चलाकर एक-एक फाइल को प्रोसेस करना
        for (int i = 0; i < totalFiles; i++) {
          PlatformFile file = result.files[i];
          
          if (file.path != null) {
            // UI को अपडेट करने के लिए प्रोग्रेस भेजें (जैसे: 1/10 प्रोसेस हो रहा है...)
            if (onProgress != null) {
              onProgress(i + 1, totalFiles, file.name);
            }

            try {
              // a) PDF से टेक्स्ट निकालें
              String extractedText = await AIService.extractTextFromPdf(file.path!);

              // b) AI से JSON डेटा निकालें
              Map<String, dynamic> billData = await AIService.processBillWithGemini(
                pdfText: extractedText,
                apiKey: apiKey,
              );

              // c) डेटाबेस में सेव करें
              await dbHelper.insertBill(billData);

              // ⚠️ रेट लिमिटिंग (429 Error) से बचने के लिए 3 सेकंड का ब्रेक
              // ताकि Google API ब्लॉक न करे
              if (i < totalFiles - 1) {
                await Future.delayed(const Duration(seconds: 3));
              }
            } catch (e) {
              // अगर कोई एक फाइल फेल होती है, तो पूरा ऐप क्रैश ना हो, बस अगली फाइल पर चला जाए
              print("❌ फाइल \${file.name} में एरर: \$e");
            }
          }
        }
      }
    } catch (e) {
      throw Exception("बैच प्रोसेसिंग शुरू करने में एरर: \$e");
    }
  }
}
