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
  // Files State
  Uint8List? _excelBytes;
  String? _excelFileName;
  Uint8List? _docxBytes;
  String? _docxFileName;

  // Dropdown Selections
  String _selectedYear = '2026-2027';
  String? _selectedDistrict;
  String? _selectedPS;
  String? _selectedGP;

  // Lists for Dropdowns
  List<String> _districtsList = [];
  List<String> _psList = [];
  List<String> _gpList = [];

  final List<String> _yearsList = ['2024-2025', '2025-2026', '2026-2027', '2027-2028'];
  final TextEditingController _apiKeyController = TextEditingController();
  final DispatchService _dispatchService = DispatchService(geminiApiKey: '');

  bool _isProcessing = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadMappingDropdowns();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('gemini_api_key') ?? '';
    });
  }

  Future<void> _saveApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', value);
  }

  // Load Mapping Data into Dropdowns
  void _loadMappingDropdowns() {
    setState(() {
      _districtsList = _dispatchService.getAvailableDistricts();
      if (_districtsList.isNotEmpty) {
        _selectedDistrict = _districtsList.first;
        _updatePanchayatSamitis(_selectedDistrict!);
      } else {
        _selectedDistrict = null;
        _psList = [];
        _gpList = [];
      }
    });
  }

  void _updatePanchayatSamitis(String district) {
    setState(() {
      _selectedDistrict = district;
      _psList = _dispatchService.getPanchayatSamitisForDistrict(district);
      _selectedPS = _psList.isNotEmpty ? _psList.first : null;
      if (_selectedPS != null) {
        _updateGramPanchayats(district, _selectedPS!);
      } else {
        _gpList = [];
        _selectedGP = null;
      }
    });
  }

  void _updateGramPanchayats(String district, String ps) {
    setState(() {
      _selectedPS = ps;
      _gpList = _dispatchService.getGramPanchayatsForPS(district, ps);
      _selectedGP = _gpList.isNotEmpty ? _gpList.first : null;
    });
  }

  // File Pickers
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

  Future<void> _startProcessing() async {
    if (_excelBytes == null || _docxBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kripya Excel aur DOCX Template dono select karein.")),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Dispatch process shuru ho raha hai...";
    });

    try {
      final service = DispatchService(geminiApiKey: _apiKeyController.text.trim());
      String resultPath = await service.processDispatchLocal(
        excelBytes: _excelBytes!,
        docxBytes: _docxBytes!,
        selectedYear: _selectedYear,
        onProgress: (status) {
          setState(() {
            _statusMessage = status;
          });
        },
      );

      // Processing ke baad nayi mappings se dropdowns update karein
      _loadMappingDropdowns();

      setState(() {
        _statusMessage = "✓ $resultPath";
      });
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
        title: const Text("INS Rama - Dispatch Portal"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Dynamic Dropdowns Filter Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Master Filter & Local Mappings",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade800)),
                    const SizedBox(height: 12),

                    // Year Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedYear,
                      decoration: const InputDecoration(labelText: "Audit Year Select Karein", border: OutlineInputBorder()),
                      items: _yearsList.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (val) => setState(() => _selectedYear = val!),
                    ),
                    const SizedBox(height: 12),

                    // District Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: const InputDecoration(labelText: "District Select Karein", border: OutlineInputBorder()),
                      items: _districtsList.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) {
                        if (val != null) _updatePanchayatSamitis(val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dependent Panchayat Samiti Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPS,
                      decoration: const InputDecoration(
                          labelText: "Panchayat Samiti (Filtered)", border: OutlineInputBorder()),
                      items: _psList.map((ps) => DropdownMenuItem(value: ps, child: Text(ps))).toList(),
                      onChanged: (val) {
                        if (val != null && _selectedDistrict != null) {
                          _updateGramPanchayats(_selectedDistrict!, val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dependent Gram Panchayat Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedGP,
                      decoration: const InputDecoration(
                          labelText: "Gram Panchayat (Filtered)", border: OutlineInputBorder()),
                      items: _gpList.map((gp) => DropdownMenuItem(value: gp, child: Text(gp))).toList(),
                      onChanged: (val) => setState(() => _selectedGP = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Upload Files Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickExcel,
                      icon: const Icon(Icons.table_chart, color: Colors.green),
                      label: Text(_excelFileName ?? "1. Dispatch Excel Upload (.xlsx)"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickDocx,
                      icon: const Icon(Icons.description, color: Colors.blue),
                      label: Text(_docxFileName ?? "2. DOCX Template Upload (.docx)"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Gemini API Key Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: "Gemini API Key (Auto Transliteration)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.auto_awesome),
                  ),
                  onChanged: _saveApiKey,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Process Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _startProcessing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Process Dispatch & Generate Documents",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            // Status Message Display
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }
}
