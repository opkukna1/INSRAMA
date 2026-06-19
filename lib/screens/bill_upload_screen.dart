// lib/screens/bill_upload_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../database/db_helper.dart'; 
import '../services/ai_service.dart';

class BillUploadScreen extends StatefulWidget {
  const BillUploadScreen({super.key});

  @override
  State<BillUploadScreen> createState() => _BillUploadScreenState();
}

class _BillUploadScreenState extends State<BillUploadScreen> {
  // AI सर्विस में मॉडल 'gemini-3.1-flash-lite-preview' को परमानेंट लॉक कर दिया गया है
  final String _selectedModel = "gemini-3.1-flash-lite-preview"; 
  
  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  
  bool _isLoading = false;
  int _totalFiles = 0;
  int _processedFiles = 0;
  String _currentFileName = "";
  
  // प्रोसेस हुई फाइल्स की समरी दिखाने के लिए नया बैच डेटा लिस्ट
  List<Map<String, dynamic>> _processedBatchData = [];

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
      }
    });
  }

  void _pickAndProcessMultipleDocuments() async {
    if (_selectedSocietyId == null) {
      _showSnackBar("कृपया पहले 'समिति प्रबंधन' स्क्रीन पर जाकर एक समिति जोड़ें।");
      return;
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      _showSnackBar("त्रुटि: .env फ़ाइल में GEMINI_API_KEY नहीं मिली।");
      return;
    }

    try {
      // वित्तीय दस्तावेज (PDF) चुनने के लिए फाइल पिकर
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
        
        for (int i = 0; i < result.files.length; i++) {
          PlatformFile file = result.files[i];
          
          if (file.path != null) {
            setState(() {
              _currentFileName = file.name;
              _processedFiles = i + 1;
            });

            try {
              // 🚀 मास्टर स्ट्रोक 1: फाइल का DNA (SHA-256 Hash) चेक करना ताकि डुप्लीकेट एंट्री न हो
              String fileHash = await AIService.getFileHash(file.path!);
              bool isDuplicate = await DatabaseHelper.instance.isFileAlreadyProcessed(fileHash);
              
              if (isDuplicate) {
                print("${file.name} पहले ही अपलोड हो चुकी है! इसे स्किप कर रहे हैं।");
                _showSnackBar("स्किप किया: ${file.name} पहले ही प्रोसेस हो चुकी है।");
                continue; // लूप में अगली फाइल पर बढ़ें
              }

              // PDF से टेक्स्ट निकालना
              String extractedText = await AIService.extractTextFromPdf(file.path!);
              
              if (extractedText.trim().isEmpty) {
                throw Exception("PDF में कोई टेक्स्ट नहीं मिला! (शायद यह बिना स्कैन किया इमेज PDF है)");
              }
              
              // 🚀 मास्टर स्ट्रोक 2: नए AI ऑडिटर को कॉल करना जो लेज़र एंट्री और संदिग्ध नोट्स दोनों देगा
              Map<String, dynamic> auditResult = await AIService.processDocumentWithAuditorAI(
                documentText: extractedText,
                apiKey: apiKey,
              );

              List<dynamic> ledgerEntries = auditResult['ledger_entries'] ?? [];
              List<dynamic> suspiciousNotes = auditResult['suspicious_notes'] ?? [];

              // 🚀 मास्टर स्ट्रोक 3: सभी एकाउंटिंग एंट्रीज को मास्टर लेज़र टेबल में सेव करना
              for (var entry in ledgerEntries) {
                Map<String, dynamic> ledgerRow = {
                  'society_id': _selectedSocietyId,
                  'date': entry['date'],
                  'particulars': entry['particulars'],
                  'amount': entry['amount'],
                  'type': entry['type'], // DEBIT या CREDIT
                  'category': entry['category'], // Income, Expense, Asset, Liability
                  'doc_type': entry['doc_type'], // Voucher, Bill, etc.
                  'reference_no': entry['reference_no'] ?? '',
                };
                await DatabaseHelper.instance.insertLedgerEntry(ledgerRow);
              }

              // 🚀 मास्टर स्ट्रोक 4: खोजी गई संदिग्ध गड़बड़ियों (हिंदी नोट्स) को 'document_doubts' टेबल में सेव करना
              for (var note in suspiciousNotes) {
                Map<String, dynamic> doubtRow = {
                  'society_id': _selectedSocietyId,
                  'file_name': file.name,
                  'doubt_text': note.toString(), // शुद्ध हिंदी अलर्ट
                  'created_at': DateTime.now().toIso8601String(),
                };
                await DatabaseHelper.instance.insertDocumentDoubt(doubtRow);
              }

              // 🚀 मास्टर स्ट्रोक 5: फाइल को 'Processed' मार्क करना ताकि भविष्य में दोबारा अपलोड न हो सके
              await DatabaseHelper.instance.markFileAsProcessed(_selectedSocietyId!, fileHash, file.name);

              // स्क्रीन पर समरी दिखाने के लिए स्टेट अपडेट करना
              setState(() {
                _processedBatchData.add({
                  'file_name': file.name,
                  'entries_count': ledgerEntries.length,
                  'doubts': suspiciousNotes,
                });
              });

              // API Rate-limiting से बचने के लिए छोटा सा डिले
              if (i < result.files.length - 1) {
                await Future.delayed(const Duration(seconds: 2));
              }

            } catch (e) {
              print("${file.name} में एरer: $e");
              _showSnackBar("त्रुटि (${file.name}): $e"); 
            }
          }
        }

        setState(() { _isLoading = false; });

        if (_processedBatchData.isNotEmpty) {
           _showSnackBar("🎉 दस्तावेज सफलतापूर्वक प्रोसेस और मास्टर लेज़र में सेव कर दिए गए हैं!");
        }
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      _showSnackBar("सिस्टम त्रुटि: $e");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📂 एडवांस ERP डाक्यूमेंट्स प्रोसेसिंग'),
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
                  Text("ऑडिटिंग और प्रोसेसिंग जारी है... ($_processedFiles/$_totalFiles)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text("वर्तमान फ़ाइल: $_currentFileName", style: const TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚙️ एक्टिव एआई मॉडल:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: Text(_selectedModel, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey)),
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

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _pickAndProcessMultipleDocuments,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('फाइल्स (Bills, Vouchers, Statements) अपलोड करें', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),

                  if (_processedBatchData.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('📊 हाल ही में प्रोसेस हुई फाइल्स की रिपोर्ट:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _processedBatchData.length,
                      itemBuilder: (context, index) {
                        final data = _processedBatchData[index];
                        final List<dynamic> doubts = data['doubts'] ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(data['file_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text("📈 कुल जनरेटेड खाते एंट्रीज: ${data['entries_count']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                                
                                if (doubts.isNotEmpty) ...[
                                  const Divider(),
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 6),
                                      Text("⚠️ संदिग्ध ऑडिटर अलर्ट (${doubts.length}):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: doubts.map((doubt) => Padding(
                                      padding: const EdgeInsets.only(left: 8.0, top: 4),
                                      child: Text("• $doubt", style: TextStyle(color: Colors.red.shade900, fontSize: 13, height: 1.3)),
                                    )).toList(),
                                  )
                                ]
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
}
