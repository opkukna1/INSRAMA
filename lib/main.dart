// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env फ़ाइल लोड करने के लिए इम्पोर्ट
import 'package:hive_flutter/hive_flutter.dart'; // Local storage ke liye Hive
import 'models/mapping_model.dart';
import 'screens/home_screen.dart';
import 'services/dispatch_service.dart';

void main() async {
  // यह सुनिश्चित करता है कि ऐप शुरू होने से पहले प्लगइन्स ठीक से इनिशियलाइज़ हो जाएँ
  WidgetsFlutterBinding.ensureInitialized();

  // Screen Crash Catching - Release APK mein errors console par log karne ke liye
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // 1. .env फ़ाइल को Safely लोड करना (अगर .env फाइल ना मिले तो ऐप क्रैश नहीं होगा)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(".env file not found or failed to load: $e");
  }

  // 2. Local Storage (Hive DB) को Safely इनिशियलाइज़ करना
  try {
    await Hive.initFlutter();
    
    // Adapter pehle se registered na ho tabhi register karein
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MappingModelAdapter());
    }
    
    await Hive.openBox<MappingModel>('mappings_box');
  } catch (e) {
    debugPrint("Hive Initialization Error: $e");
  }

  runApp(const InsRamaApp());
}

class InsRamaApp extends StatelessWidget {
  const InsRamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // .env se Gemini API Key fetch karna
    final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    // DispatchService ka instance create karna
    final dispatchService = DispatchService(geminiApiKey: apiKey);

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

      // अगर ऐप में कोई अनहैंडल्ड रनटाइम एरर आये तो रेड स्क्रीन की जगह साफ टेक्स्ट दिखेगा
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "App Initialization Error:\n${details.exception}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          );
        };
        return child!;
      },
      
      // dispatchService parameter ke saath HomeScreen load karna
      home: HomeScreen(dispatchService: dispatchService),
      
      // ऊपर से लाल रंग का डिबग बैनर हटाने के लिए
      debugShowCheckedModeBanner: false,
    );
  }
}
