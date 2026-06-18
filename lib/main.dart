// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  // यह सुनिश्चित करता है कि ऐप शुरू होने से पहले SQLite डेटाबेस प्लगइन्स ठीक से इनिशियलाइज़ हो जाएँ
  WidgetsFlutterBinding.ensureInitialized();
  
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
        
        // 1. फ़िक्स: useMaterialDesign3 को यहाँ से हटा दिया है क्योंकि नए फ़्लटर में यह अब बाय-डिफ़ॉल्ट ट्रू (True) रहता है।

        // 2. फ़िक्स: पूरे ऐप के कार्ड्स के लिए 'CardTheme' की जगह 'CardThemeData' का उपयोग किया है ताकि टाइप एरर न आए।
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
