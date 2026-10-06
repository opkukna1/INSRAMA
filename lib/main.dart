import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/mapping_model.dart';
import 'screens/home_screen.dart';
import 'services/dispatch_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Console error logging for release builds
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // 1. Safe Load .env File
  String apiKey = "";
  try {
    await dotenv.load(fileName: ".env");
    apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  } catch (e) {
    debugPrint(".env asset not found or failed to load: $e");
  }

  // 2. Safe Local Storage Initialization
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MappingModelAdapter());
    }
    await Hive.openBox<MappingModel>('mappings_box');
  } catch (e) {
    debugPrint("Hive Initialization Error: $e");
  }

  runApp(InsRamaApp(apiKey: apiKey));
}

class InsRamaApp extends StatelessWidget {
  final String apiKey;

  const InsRamaApp({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final dispatchService = DispatchService(geminiApiKey: apiKey);

    return MaterialApp(
      title: 'INS Rama',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green.shade700,
          secondary: Colors.orange.shade700,
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "App Initialization Error:\n${details.exception}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
      home: HomeScreen(dispatchService: dispatchService),
      debugShowCheckedModeBanner: false,
    );
  }
}
