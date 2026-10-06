// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env फ़ाइल लोड करने के लिए इम्पोर्ट
import 'package:hive_flutter/hive_flutter.dart'; // Local storage ke liye Hive
import 'models/mapping_model.dart';
import 'screens/home_screen.dart';

void main() async {
  // यह सुनिश्चित करता है कि ऐप शुरू होने से पहले प्लगइन्स ठीक से इनिशियलाइज़ हो जाएँ
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. .env फ़ाइल लोड करना
  await dotenv.load(fileName: ".env");

  // 2. Local Storage (Hive DB) को इनिशियलाइज़ करना
  await Hive.initFlutter();
  Hive.registerAdapter(MappingModelAdapter());
  await Hive.openBox<MappingModel>('mappings_box');

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
        
        // पूरे ऐप के कार्ड्स के लिए 'CardThemeData' का उपयोग
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        ),
        useMaterial3: true,
      ),
      
      // होम स्क्रीन को डिफ़ॉल्ट स्क्रीन सेट करना
      home: const HomeScreen(),
      
      // ऊपर से लाल रंग का डिबग बैनर हटाने के लिए
      debugShowCheckedModeBanner: false,
    );
  }
}
