// lib/screens/society_management_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class SocietyManagementScreen extends StatefulWidget {
  const SocietyManagementScreen({super.key});

  @override
  State<SocietyManagementScreen> createState() => _SocietyManagementScreenState();
}

class _SocietyManagementScreenState extends State<SocietyManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _bankController = TextEditingController();
  final _ifscController = TextEditingController();
  
  String _selectedType = "Dugdh Utpadak Samiti (दुग्ध समिति)";
  List<Map<String, dynamic>> _societies = [];

  @override
  void initState() {
    super.initState();
    _refreshSocietiesList();
  }

  // डेटाबेस से सभी रजिस्टर्ड समितियों की लिस्ट लोड करना
  void _refreshSocietiesList() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
    });
  }

  // नई समिति को डेटाबेस में सेव करने का फंक्शन
  void _saveSociety() async {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> row = {
        'name': _nameController.text,
        'type': _selectedType,
        'code': _codeController.text,
        'bank_account': _bankController.text,
        'ifsc': _ifscController.text,
      };

      await DatabaseHelper.instance.insertSociety(row);
      
      // फॉर्म क्लियर करना और लिस्ट रीफ्रेश करना
      _nameController.clear();
      _codeController.clear();
      _bankController.clear();
      _ifscController.clear();
      
      _refreshSocietiesList();
      
      // 🔥 फ़िक्स: एसिंक्रोनस ऑपरेशन (await) के बाद context का उपयोग सुरक्षित करने के लिए mounted चेक लगाया
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('समिति सफलतापूर्वक सुरक्षित कर दी गई है!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏢 समिति प्रबंधन (INS Rama)'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. नई समिति जोड़ने का फॉर्म
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🆕 नई समिति का पंजीकरण करें', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      
                      // फ़िक्स: नए फ़्लटर नियमों के अनुसार 'value' को 'initialValue' में बदल दिया गया है
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: const InputDecoration(labelText: 'समिति का प्रकार', border: OutlineInputBorder()),
                        items: [
                          "Dugdh Utpadak Samiti (दुग्ध समिति)",
                          "GSS - ग्राम सेवा सहकारी समिति",
                          "Mahila Multipurpose Samiti (महिला समिति)"
                        ].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) {
                          setState(() { _selectedType = val!; });
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'समिति का पूरा नाम', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'कृपया नाम दर्ज करें' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'समिति कोड / रजिस्ट्रेशन नंबर', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'कृपया कोड दर्ज करें' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bankController,
                              decoration: const InputDecoration(labelText: 'बैंक खाता संख्या', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _ifscController,
                              decoration: const InputDecoration(labelText: 'IFSC कोड', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _saveSociety,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                          child: const Text('समिति सुरक्षित करें', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const Divider(height: 32),
            
            // 2. पहले से जुड़ी समितियों की लिस्ट
            const Text('📋 पंजीकृत समितियां (Registered Societies)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: _societies.isEmpty
                  ? const Center(child: Text('अभी तक कोई समिति नहीं जोड़ी गई है।'))
                  : ListView.builder(
                      itemCount: _societies.length,
                      itemBuilder: (context, index) {
                        final society = _societies[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(Icons.business, color: Colors.green.shade800),
                            ),
                            title: Text(society['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('कोड: ${society['code']} | ${society['type']}'),
                          ),
                        );
                      },
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
    _codeController.dispose();
    _bankController.dispose();
    _ifscController.dispose();
    super.dispose();
  }
}
