import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import '../services/ai_service.dart';

class BillUploadScreen extends StatefulWidget {
  const BillUploadScreen({super.key});

  @override
  State<BillUploadScreen> createState() => _BillUploadScreenState();
}

class _BillUploadScreenState extends State<BillUploadScreen> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = "gemini-1.5-pro";
  
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  bool _isLoading = false;
  Map<String, dynamic>? _extractedData;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  // डेटाबेस से समितियों की लिस्ट लोड करना
  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
      }
    });
  }

  // फोन से पीडीएफ फाइल चुनना और एआई से प्रोसेस करना
  void _pickAndProcessBill() async {
    if (_selectedSocietyId == null) {
      _showSnackBar("कृपया पहले 'समिति प्रबंधन' स्क्रीन पर जाकर एक समिति जोड़ें।");
      return;
    }
    if (_apiKeyController.text.isEmpty) {
      _showSnackBar("कृपया प्रोसेसिंग के लिए Gemini API Key दर्ज करें।");
      return;
    }

    try {
      // 1. फोन स्टोरेज से पीडीएफ फाइल पिक करना
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() { _isLoading = true; _extractedData = null; });
        
        String filePath = result.files.single.path!;
        
        // 2. पीडीएफ से टेक्स्ट निकालना
        String extractedText = await AIService.extractTextFromPdf(filePath);
        
        // 3. जेमिनी एआई मॉडल से डेटा पार्स करना
        Map<String, dynamic> aiResult = await AIService.processBillWithGemini(
          pdfText: extractedText,
          apiKey: _apiKeyController.text,
          modelName: _selectedModel,
        );

        // 4. लोकल SQLite डेटाबेस में सेव करने के लिए डेटा तैयार करना
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

        // 5. डेटाबेस में इन्सर्ट करना
        await DatabaseHelper.instance.insertMilkBill(billRow);

        setState(() {
          _extractedData = aiResult;
          _isLoading = false;
        });

        _showSnackBar("बिल सफलतापूर्वक प्रोसेस और लोकल डेटाबेस में सेव हो गया!");
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
        title: const Text('📂 बिल अपलोड एवं AI प्रोसेसिंग'),
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
                  Text("एआई पीडीएफ बिल को पढ़ रहा है और खाते तैयार कर रहा है...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // एडमिन सेटिंग्स (API Key & Model Selection)
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
                    items: ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-2.5-pro"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) => setState(() { _selectedModel = val!; }),
                  ),
                  const Divider(height: 32),

                  // समिति का चयन
                  const Text('🏢 समिति चुनें जिसके लिए बिल अपलोड करना है:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

                  // बिल सेलेक्ट करने का बटन
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _pickAndProcessBill,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('पाक्षिक दुग्ध बिल (PDF) चुनें', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    ),
                  ),

                  // एक्सट्रैक्टेड डेटा का डिस्प्ले कार्ड
                  if (_extractedData != null) ...[
                    const SizedBox(height: 24),
                    const Text('📊 एआई द्वारा निकाला गया डेटा (Saved in Phone):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _dataRow("बिल नंबर:", _extractedData!['bill_no'].toString()),
                            _dataRow("अवधि:", "${_extractedData!['start_date']} से ${_extractedData!['end_date']}"),
                            _dataRow("कुल दूध (Ltrs):", _extractedData!['total_milk'].toString()),
                            _dataRow("दुग्ध बिक्री राशि:", "₹ ${_extractedData!['milk_payment']}"),
                            _dataRow("कमीशन (Overhead):", "₹ ${_extractedData!['overhead']}"),
                            _dataRow("हेड लोड (Head Load):", "₹ ${_extractedData!['head_load']}"),
                            _dataRow("घी कटौती:", "₹ ${_extractedData!['ghee_deduction']}"),
                          ],
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      key: ValueKey(label),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
