// lib/screens/outstanding_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class OutstandingScreen extends StatefulWidget {
  const OutstandingScreen({super.key});

  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fatherController = TextEditingController();
  final _shareController = TextEditingController();
  final _outstandingController = TextEditingController();

  List<Map<String, dynamic>> _societies = [];
  int? _selectedSocietyId;
  List<Map<String, dynamic>> _membersList = [];

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  // समितियों की लिस्ट लोड करना
  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
        _loadMembers(_selectedSocietyId!);
      }
    });
  }

  // चयनित समिति के सदस्यों की बकाया सूची लोड करना
  void _loadMembers(int societyId) async {
    final data = await DatabaseHelper.instance.queryOutstandingBySociety(societyId);
    setState(() {
      _membersList = data;
    });
  }

  // नए सदस्य की एंट्री सुरक्षित करना
  void _saveMemberRow() async {
    if (_selectedSocietyId == null) return;
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> row = {
        'society_id': _selectedSocietyId,
        'member_name': _nameController.text,
        'father_name': _fatherController.text,
        'share_capital': double.tryParse(_shareController.text) ?? 0.0,
        'outstanding_amount': double.tryParse(_outstandingController.text) ?? 0.0,
      };

      await DatabaseHelper.instance.insertMemberOutstanding(row);

      _nameController.clear();
      _fatherController.clear();
      _shareController.clear();
      _outstandingController.clear();

      _loadMembers(_selectedSocietyId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सदस्य का रिकॉर्ड सुरक्षित कर दिया गया है!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 सदस्य हिस्सा राशि एवं बकाया सूची'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 फ़िक्स: यहाँ 'value' को बदलकर 'initialValue' कर दिया है ताकि नए फ्लटर में वॉर्निंग या एरर न आए
            DropdownButtonFormField<int>(
              initialValue: _selectedSocietyId,
              decoration: const InputDecoration(labelText: "समिति चुनें", border: OutlineInputBorder()),
              items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name']))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() { _selectedSocietyId = val; });
                  _loadMembers(val);
                }
              },
            ),
            const SizedBox(height: 16),

            // नया सदस्य जोड़ने का फॉर्म (Expander में बंद)
            Card(
              child: ExpansionTile(
                title: const Text("🆕 नए सदस्य की बकाया/हिस्सा राशि दर्ज करें", style: TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'सदस्य का नाम', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'नाम दर्ज करना अनिवार्य है' : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fatherController,
                            decoration: const InputDecoration(labelText: 'पिता का नाम', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _shareController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'हिस्सा राशि (₹)', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _outstandingController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'बकाया राशि (₹)', border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveMemberRow,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                              child: const Text('रिकॉर्ड जोड़ें'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text('📋 वर्तमान सदस्य सूची (Outstanding Ledger):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            // सदस्यों की डेटा टेबल
            Expanded(
              child: _membersList.isEmpty
                  ? const Center(child: Text('इस समिति में अभी कोई सदस्य रिकॉर्ड नहीं है।'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columns: const [
                            DataColumn(label: Text('सदस्य का नाम', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('पिता का नाम', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('हिस्सा राशि (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('बकाया राशि (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _membersList.map((member) {
                            return DataRow(cells: [
                              DataCell(Text(member['member_name'].toString())),
                              DataCell(Text((member['father_name'] ?? '-').toString())),
                              DataCell(Text("₹ ${member['share_capital'] ?? '0.0'}")),
                              DataCell(Text(
                                "₹ ${member['outstanding_amount'] ?? '0.0'}",
                                style: TextStyle(
                                  color: (member['outstanding_amount'] ?? 0) > 0 ? Colors.red : Colors.black,
                                  fontWeight: (member['outstanding_amount'] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherController.dispose();
    _shareController.dispose();
    _outstandingController.dispose();
    super.dispose();
  }
}
