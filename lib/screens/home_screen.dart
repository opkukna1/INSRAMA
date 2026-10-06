import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/dispatch_service.dart';

class HomeScreen extends StatefulWidget {
  final DispatchService dispatchService;

  const HomeScreen({Key? key, required this.dispatchService}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Uint8List? excelBytes;
  Uint8List? docxTemplateBytes;
  String excelFileName = "";
  String templateFileName = "";

  String statusText = "Ready";

  // Dropdown Selections
  String? selectedDistrict;
  String? selectedPS;
  List<String> availableDistricts = [];
  List<String> availablePS = [];
  List<String> availableGPs = [];

  List<String> selectedGPs = [];
  bool isAllGPSelected = false;
  String selectedYear = "2025-26";

  List<String> generatedFiles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMasterData();
  }

  void _loadMasterData() {
    setState(() {
      availableDistricts = widget.dispatchService.getAvailableDistricts();
      if (availableDistricts.isNotEmpty && selectedDistrict == null) {
        selectedDistrict = availableDistricts.first;
        _updatePSList();
      }
    });
  }

  void _updatePSList() {
    if (selectedDistrict == null) return;
    setState(() {
      availablePS = widget.dispatchService.getPanchayatSamitisForDistrict(selectedDistrict!);
      selectedPS = availablePS.isNotEmpty ? availablePS.first : null;
      _updateGPList();
    });
  }

  void _updateGPList() {
    if (selectedDistrict == null || selectedPS == null) return;
    setState(() {
      availableGPs = widget.dispatchService.getGramPanchayatsForPS(selectedDistrict!, selectedPS!);
      selectedGPs = [];
      isAllGPSelected = false;
    });
  }

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        excelBytes = result.files.single.bytes;
        excelFileName = result.files.single.name;
        statusText = "Excel Loaded: $excelFileName";
      });
    }
  }

  Future<void> _pickTemplateFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx']);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        docxTemplateBytes = result.files.single.bytes;
        templateFileName = result.files.single.name;
        statusText = "Template Loaded: $templateFileName";
      });
    }
  }

  Future<void> _syncAIMapping() async {
    if (excelBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Excel file upload karein!")));
      return;
    }
    await widget.dispatchService.syncUnmappedWithAI(
      excelBytes: excelBytes!,
      onProgress: (status) => setState(() => statusText = status),
    );
    _loadMasterData();
  }

  Future<void> _generateDocuments() async {
    if (excelBytes == null || docxTemplateBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Excel aur Template Word file upload hona zaroori hai!")));
      return;
    }

    List<String> files = await widget.dispatchService.generateCoveringLetters(
      excelBytes: excelBytes!,
      docxBytes: docxTemplateBytes!,
      selectedDistrict: selectedDistrict ?? "",
      selectedPS: selectedPS ?? "",
      selectedGPs: selectedGPs,
      isAllSelected: isAllGPSelected,
      selectedYear: selectedYear,
      onProgress: (status) => setState(() => statusText = status),
    );

    setState(() {
      generatedFiles = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("INS RAMA Portal"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: "Covering Letter", icon: Icon(Icons.description)),
            Tab(text: "ATS", icon: Icon(Icons.assignment)),
            Tab(text: "Reports", icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_special, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text("Files & AI Mapping", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: Text(excelFileName.isEmpty ? "Upload Excel Dispatch File" : excelFileName),
              onTap: _pickExcelFile,
            ),
            ListTile(
              leading: const Icon(Icons.article, color: Colors.blue),
              title: Text(templateFileName.isEmpty ? "Upload Template (.docx)" : templateFileName),
              onTap: _pickTemplateFile,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.purple),
              title: const Text("Sync & AI Mapping Check"),
              subtitle: const Text("Unmapped entries 50-50 batches me process hongi"),
              onTap: () {
                Navigator.pop(context);
                _syncAIMapping();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.indigo.shade50,
            width: double.infinity,
            child: Text("Status: $statusText", style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCoveringLetterTab(),
                const Center(child: Text("ATS Module Coming Soon")),
                const Center(child: Text("Reports Module Coming Soon")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoveringLetterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDistrict,
                    decoration: const InputDecoration(labelText: "Select District", border: OutlineInputBorder()),
                    items: availableDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      selectedDistrict = val;
                      _updatePSList();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPS,
                    decoration: const InputDecoration(labelText: "Select Panchayat Samiti", border: OutlineInputBorder()),
                    items: availablePS.map((ps) => DropdownMenuItem(value: ps, child: Text(ps))).toList(),
                    onChanged: (val) {
                      selectedPS = val;
                      _updateGPList();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: selectedYear,
                    decoration: const InputDecoration(labelText: "Financial Year", border: OutlineInputBorder()),
                    onChanged: (val) => selectedYear = val,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text("Select All Gram Panchayats", style: TextStyle(fontWeight: FontWeight.bold)),
                    value: isAllGPSelected,
                    onChanged: (val) {
                      setState(() {
                        isAllGPSelected = val ?? false;
                        if (isAllGPSelected) {
                          selectedGPs = List.from(availableGPs);
                        } else {
                          selectedGPs.clear();
                        }
                      });
                    },
                  ),
                  const Divider(),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      itemCount: availableGPs.length,
                      itemBuilder: (context, index) {
                        final gp = availableGPs[index];
                        final isChecked = selectedGPs.contains(gp);
                        return CheckboxListTile(
                          title: Text(gp),
                          value: isChecked,
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                selectedGPs.add(gp);
                              } else {
                                selectedGPs.remove(gp);
                                isAllGPSelected = false;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.file_download),
            label: const Text("Generate Word Documents (.docx)", style: TextStyle(fontSize: 16)),
            onPressed: _generateDocuments,
          ),
          if (generatedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.share, color: Colors.green),
                    label: const Text("Share to WhatsApp"),
                    onPressed: () => widget.dispatchService.shareToWhatsApp(generatedFiles),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
