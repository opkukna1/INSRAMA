// lib/screens/bill_upload_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart'; // आपका मौजूदा डेटाबेस हेल्पर
import '../services/ai_service.dart';

class BillUploadScreen extends StatefulWidget {
  const BillUploadScreen({super.key});

  @override
  State<BillUploadScreen> createState() => _BillUploadScreenState();
}

class _BillUploadScreenState extends State<BillUploadScreen> {
  final _apiKeyController = TextEditingController();
  
  // 🚀 यहाँ डिफ़ॉल्ट रूप से नया 3.1 Flash Lite मॉडल सेट कर दिया है
  String _selectedModel = "gemini-3.1-flash-lite-preview"; 
  
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  
  // बैच प्रोसेसिंग का स्टेट (Progress Tracking)
  bool _isLoading = false;
  int _totalFiles = 0;
  int _processedFiles = 0;
  String _currentFileName = "";
  
  // इस बार एक नहीं, बल्कि पूरी लिस्ट सेव करेंगे ताकि स्क्रीन पर दिखा सकें
  List<Map<String, dynamic>> _processedBatchData = [];

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  void _loadSocieties() async {
    // आपके मौजूदा कोड के अनुसार
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
      }
    });
  }

  // 🔥 नया बैच प्रोसेसिंग फंक्शन
  void _pickAndProcessMultipleBills() async {
    if (_selectedSocietyId == null) {
      _showSnackBar("कृपया पहले 'समिति प्रबंधन' स्क्रीन पर जाकर एक समिति जोड़ें।");
      return;
    }
    if (_apiKeyController.text.isEmpty) {
      _showSnackBar("कृपया प्रोसेसिंग के लिए Gemini API Key दर्ज करें।");
      return;
    }

    try {
      // 1. allowMultiple: true के साथ एक साथ कई PDF चुनना
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true, 
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() { 
          _isLoading = true; 
          _totalFiles = result.files.length;
          _processedFiles = 0;
          _processedBatchData.clear();
        });
        
        // 2. एक-एक करके फाइल को लूप में प्रोसेस करना
        for (int i = 0; i < result.files.length; i++) {
          PlatformFile file = result.files[i];
          
          if (file.path != null) {
            setState(() {
              _currentFileName = file.name;
              _processedFiles = i + 1;
            });

            try {
              // a) टेक्स्ट निकालें
              String extractedText = await AIService.extractTextFromPdf(file.path!);
              
              // b) AI से प्रोसेस कराएं
              Map<String, dynamic> aiResult = await AIService.processBillWithGemini(
                pdfText: extractedText,
                apiKey: _apiKeyController.text,
                modelName: _selectedModel,
              );

              // c) डेटा तैयार करें (आपके existing DB schema के अनुसार)
              Map<String, dynamic> billRow = {
                'society_id': _selectedSocietyId,
                'bill_no': aiResult['bill_no'],
                'start_date': aiResult['start_date'],
                'end_date': aiResult['end_date'],
                'total_milk': aiResult['total_milk'],
                'milk_payment': aiResult['milk_payment'],
                'head_load': aiResult['head_load'],
                'overhead': aiResult['overhead'],
                'ghee_deduction': aiResult['ghee_deduction'],
                'cattle_feed_deduction': aiResult['cattle_feed_deduction'] ?? 0.0,
              };

              // d) SQLite में सेव करें
              await DatabaseHelper.instance.insertMilkBill(billRow);

              // e) UI में दिखाने के लिए लिस्ट में जोड़ें
              setState(() {
                _processedBatchData.add(aiResult);
              });

              // ⚠️ रेट लिमिटिंग से बचने के लिए 3 सेकंड का ब्रेक (Google API क्रैश नहीं होगा)
              if (i < result.files.length - 1) {
                await Future.delayed(const Duration(seconds: 3));
              }

            } catch (e) {
              // अगर कोई 1 बिल खराब है, तो पूरा लूप नहीं टूटेगा
              print("\$file.name में एरर: \$e");
              _showSnackBar("त्रुटि: \${file.name} प्रोसेस नहीं हो सका।");
            }
          }
        }

        setState(() {
          _isLoading = false;
        });

        _showSnackBar("🎉 कुल \$_totalFiles में से \${_processedBatchData.length} बिल सफलतापूर्वक प्रोसेस और सेव हो गए!");
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _showSnackBar("त्रुटि: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📂 मल्टीपल बिल AI प्रोसेसिंग'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.green),
                  const SizedBox(height: 24),
                  // 🔥 डायनामिक प्रोग्रेस टेक्स्ट
                  Text(
                    "प्रोसेसिंग चल रही है... ($_processedFiles/$_totalFiles)", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "वर्तमान फ़ाइल: $_currentFileName", 
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔑 एआई कॉन्फ़िगरेशन (Admin Setup):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Gemini API Key दर्ज करें', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedModel,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Model Name"),
                    // 🚀 यहाँ नए मॉडल्स की लिस्ट अपडेट कर दी गई है
                    items: [
                      "gemini-3.1-flash-lite-preview",
                      "gemini-1.5-flash", 
                      "gemini-1.5-pro"
                    ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) => setState(() { _selectedModel = val!; }),
                  ),
                  const Divider(height: 32),

                  const Text('🏢 समिति चुनें:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _societies.isEmpty
                      ? const Text("कोई समिति नहीं मिली। कृपया पहले समिति जोड़ें।", style: TextStyle(color: Colors.red))
                      : DropdownButtonFormField<int>(
                          value: _selectedSocietyId,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
                          onChanged: (val) => setState(() { _selectedSocietyId = val; }),
                        ),
                  const SizedBox(height: 24),

                  // 🔥 अपडेटेड बटन: अब यह कई फाइल्स सेलेक्ट करवाएगा
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _pickAndProcessMultipleBills,
                      icon: const Icon(Icons.library_add),
                      label: const Text('मल्टीपल बिल (PDF) एक साथ चुनें', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    ),
                  ),

                  // 🔥 अब एक नहीं, जितने बिल प्रोसेस हुए हैं, सबकी लिस्ट दिखाएंगे
                  if (_processedBatchData.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('📊 सफलतापूर्वक सेव हुए बिल (${_processedBatchData.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _processedBatchData.length,
                      itemBuilder: (context, index) {
                        final data = _processedBatchData[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("बिल नं: ${data['bill_no']} (${data['start_date']} से ${data['end_date']})", style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("कुल दूध: ${data['total_milk']} Ltrs"),
                                    Text("पेमेंट: ₹${data['milk_payment']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
    _apiKeyController.dispose();
    super.dispose();
  }
}
