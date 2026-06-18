// lib/screens/audit_report_screen.dart
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../database/db_helper.dart';

class AuditReportScreen extends StatefulWidget {
  const AuditReportScreen({super.key});

  @override
  State<AuditReportScreen> createState() => _AuditReportScreenState();
}

class _AuditReportScreenState extends State<AuditReportScreen> {
  final _apiKeyController = TextEditingController(); // 🔥 सुधार: API की के लिए कंट्रोलर का उपयोग
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  bool _isLoading = false;
  String _generatedReport = "";

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) _selectedSocietyId = _societies.first['id'];
    });
  }

  void _generateAuditReport() async {
    if (_selectedSocietyId == null) return;
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("कृपया पहले Gemini API Key दर्ज करें")));
      return;
    }

    setState(() { _isLoading = true; _generatedReport = ""; });

    try {
      final bills = await DatabaseHelper.instance.queryBillsBySociety(_selectedSocietyId!);
      
      double totalMilk = 0.0;
      double totalSales = 0.0;
      double totalOverhead = 0.0;

      for (var b in bills) {
        totalMilk += (b['total_milk'] ?? 0.0) as double;
        totalSales += (b['milk_payment'] ?? 0.0) as double;
        totalOverhead += (b['overhead'] ?? 0.0) as double;
      }

      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: _apiKeyController.text);
      
      final prompt = '''
      You are a Government Cooperative Auditor (सहकारी अंकेक्षक). 
      Generate a professional Audit Report (अंकेक्षण प्रतिवेदन) in clear HINDI language for a Milk Cooperative Society with the following annual financial summaries:
      - Total Milk Collected: $totalMilk Liters
      - Total Milk Sales to Sangh: ₹ $totalSales
      - Total Overhead Commission Received: ₹ $totalOverhead
      
      The report must include:
      1. प्रस्तावना (Introduction)
      2. मुख्य वित्तीय कमियां एवं आक्षेप (Audit Objections like missing dead-stock registers, cash verification note of ₹ 7,538.18 as per standards)
      3. ऑडिट वर्गीकरण (Audit Classification recommendation like Class A, B, or C)
      4. निष्कर्ष एवं सुझाव (Conclusion)
      
      Keep the tone strictly professional, official Rajasthani/Indian cooperative department style.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      // 🔥 फिक्स: एसिंक्रोनस ऑपरेशन के बाद स्टेट सेट करने और context का उपयोग करने से पहले mounted चेक अनिवार्य है
      if (!mounted) return;

      setState(() {
        _generatedReport = response.text ?? "रिपोर्ट जनरेट नहीं हो सकी।";
        _isLoading = false;
      });
    } catch (e) {
      // 🔥 फिक्स: कैच ब्लॉक के बाद भी स्क्रीन खुली है या नहीं, यह सुनिश्चित करना ज़रूरी है
      if (!mounted) return;
      
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("त्रुटि: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 AI ऑडिट रिपोर्ट जनरेटर'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text("एआई आपके खातों का विश्लेषण करके वैधानिक ऑडिट रिपोर्ट तैयार कर रहा है...", textAlign: TextAlign.center),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Gemini API Key दर्ज करें', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSocietyId, 
                    decoration: const InputDecoration(labelText: "समिति चुनें", border: OutlineInputBorder()),
                    items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
                    onChanged: (val) => setState(() { _selectedSocietyId = val; }),
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _generateAuditReport,
                      icon: const Icon(Icons.gavel),
                      label: const Text("वैधानिक ऑडिट रिपोर्ट ड्राफ्ट करें"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                    ),
                  ),
                  if (_generatedReport.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text("📋 ड्राफ्ट प्रतिवेदन (Draft Report):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SelectableText(
                          _generatedReport,
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace', height: 1.4),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose(); // 🔥 सुधार: कंट्रोलर को रिसोर्स फ्री करने के लिए डिस्पोज किया
    super.dispose();
  }
}
