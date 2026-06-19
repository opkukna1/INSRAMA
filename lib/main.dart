// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 फिक्स 1: .env फ़ाइल लोड करने के लिए इम्पोर्ट जोड़ा
import 'screens/home_screen.dart';

void main() async { // 🚀 फिक्स 2: फंक्शन को async बनाया
  // यह सुनिश्चित करता है कि ऐप शुरू होने से पहले SQLite डेटाबेस प्लगइन्स ठीक से इनिशियलाइज़ हो जाएँ
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 फिक्स 3: ऐप स्टार्ट होने से ठीक पहले .env फ़ाइल लोड करना ज़रूरी है!
  await dotenv.load(fileName: ".env"); 
  
  runApp(const InsRamaApp());
}

class InsRamaApp extends StatelessWidget {
  const InsRamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INS Rama',
      
      // ऐप की मुख्य ग्रीन थीम (सहकारी समितियों के अनुकूल)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green.shade700,
          secondary: Colors.orange.shade700,
        ),
        
        // पूरे ऐप के कार्ड्स के लिए 'CardThemeData' का उपयोग किया है ताकि टाइप एरर न आए।
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        ),
      ),
      
      // होम स्क्रीन को डिफ़ॉल्ट स्क्रीन सेट करना
      home: const HomeScreen(),
      
      // ऊपर से लाल रंग का डिबग बैनर हटाने के लिए
      debugShowCheckedModeBanner: false,
    );
  }
}
