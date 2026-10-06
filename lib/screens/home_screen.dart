import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dispatch_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? _excelBytes;
  String? _excelFileName;

  Uint8List? _docxBytes;
  String? _docxFileName;

  final TextEditingController _apiKeyController = TextEditingController();
  bool _isProcessing = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  // Load saved Gemini API Key
  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('gemini_api_key') ?? '';
    });
  }

  // Save Gemini API Key locally
  Future<void> _saveApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', value);
  }

  // Pick Excel Dispatch File
  Future<void> _pickExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _excelBytes = result.files.single.bytes;
        _excelFileName = result.files.single.name;
      });
    }
  }

  // Pick DOCX Template File
  Future<void> _pickDocx() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _docxBytes = result.files.single.bytes;
        _docxFileName = result.files.single.name;
      });
    }
  }

  // Process Dispatch Files Locally
  Future<void> _startProcessing() async {
    if (_excelBytes == null || _docxBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kripya Excel aur DOCX Template dono select karein.")),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Processing shuru ho rahi hai...";
    });

    try {
      final service = DispatchService(geminiApiKey: _apiKeyController.text.trim());
      String resultPath = await service.processDispatchLocal(
        excelBytes: _excelBytes!,
        docxBytes: _docxBytes!,
        onProgress: (status) {
          setState(() {
            _statusMessage = status;
          });
        },
      );

      setState(() {
        _statusMessage = "✓ $resultPath";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Covering Letters successfully generate ho gaye!")),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audit Dispatch Portal"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Key Settings Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: "Gemini API Key (Local Auto-Save)",
                    hintText: "Enter Gemini API Key",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                  onChanged: _saveApiKey,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload Dispatch Excel Button
            ElevatedButton.icon(
              onPressed: _pickExcel,
              icon: const Icon(Icons.table_chart, color: Colors.green),
              label: Text(_excelFileName ?? "1. Upload Dispatch Excel (.xlsx)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 12),

            // Upload DOCX Template Button
            ElevatedButton.icon(
              onPressed: _pickDocx,
              icon: const Icon(Icons.description, color: Colors.blue),
              label: Text(_docxFileName ?? "2. Upload Covering Letter Template (.docx)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 24),

            // Start Process Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _startProcessing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text("Processing in Progress..."),
                      ],
                    )
                  : const Text("Process & Generate Covering Letters", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            // Status Progress Message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.startsWith("Error") ? Colors.red : Colors.indigo.shade900,
                    fontWeight: FontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
