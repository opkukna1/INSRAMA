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
        useMaterialDesign3: true, // मॉडर्न लुक के लिए मटेरियल 3 का उपयोग
        
        // पूरे ऐप के कार्ड्स का डिफ़ॉल्ट डिज़ाइन
        cardTheme: const CardTheme(
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
