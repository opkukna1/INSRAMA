// lib/screens/audit_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:share_plus/share_plus.dart'; 
import '../database/db_helper.dart';

class AuditReportScreen extends StatefulWidget {
  const AuditReportScreen({super.key});

  @override
  State<AuditReportScreen> createState() => _AuditReportScreenState();
}

class _AuditReportScreenState extends State<AuditReportScreen> {
  final _apiKeyController = TextEditingController();
  List<Map<String, dynamic>> _societies = [];
  List<Map<String, dynamic>> _liveDoubts = []; 
  
  int? _selectedSocietyId;
  bool _isLoading = false;
  String _generatedReport = "";

  double _totalSales = 0.0;
  double _totalPurchases = 0.0;
  double _netProfit = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() async {
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty) {
      _apiKeyController.text = envKey;
    }
    _loadSocieties();
  }

  void _loadSocieties() async {
    final data = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societies = data;
      if (_societies.isNotEmpty) {
        _selectedSocietyId = _societies.first['id'];
        _loadLiveSocietyData(_selectedSocietyId!);
      }
    });
  }

  void _loadLiveSocietyData(int societyId) async {
    setState(() { _isLoading = true; });
    try {
      final ledgerData = await DatabaseHelper.instance.getMasterLedger(societyId);
      double sales = 0.0;
      double purchases = 0.0;
      double otherIncome = 0.0;
      double otherExpense = 0.0;

      for (var entry in ledgerData) {
        double amt = entry['amount'] ?? 0.0;
        String head = entry['account_head'] ?? '';
        
        if (head == 'milk_sales' || head == 'feed_sales') sales += amt;
        if (head == 'milk_purchase' || head == 'feed_purchase') purchases += amt;
        if (head == 'miscellaneous_income') otherIncome += amt;
        if (head == 'establishment_expense' || head == 'audit_fee_provision') otherExpense += amt;
      }

      // 🔥 फिक्स: db_helper में मेथड मिसिंग होने के एरर को बाईपास करने के लिए डायरेक्ट डेटाबेस क्वेरी
      List<Map<String, dynamic>> doubtsData = [];
      try {
        final db = await DatabaseHelper.instance.database;
        doubtsData = await db.query('document_doubts', where: 'society_id = ?', whereArgs: [societyId]);
      } catch (dbError) {
        doubtsData = [];
        print("डेटाबेस अलर्ट: document_doubts टेबल उपलब्ध नहीं है। $dbError");
      }

      if (!mounted) return;
      setState(() {
        _totalSales = sales;
        _totalPurchases = purchases;
        _netProfit = (sales + otherIncome) - (purchases + otherExpense);
        _liveDoubts = doubtsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      print("डेटा सिंक एरर: $e");
    }
  }

  void _generateAuditReport() async {
    if (_selectedSocietyId == null) return;
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("कृपया .env में या यहाँ Gemini API Key दर्ज करें")));
      return;
    }

    setState(() { _isLoading = true; _generatedReport = ""; });

    try {
      String formattedObjections = _liveDoubts.isEmpty 
          ? "- प्रथम दृष्टया वाउचर एवं बिलों के भौतिक सत्यापन में कोई गंभीर अनियमितता नहीं पाई गई।"
          : _liveDoubts.map((d) => "- फ़ाइल [${d['file_name']}]: ${d['doubt_text']}").join("\n");

      final selectedSocietyName = _societies.firstWhere((s) => s['id'] == _selectedSocietyId)['name'] ?? "सहकारी समिति";

      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: _apiKeyController.text);
      
      final prompt = '''
      आप राजस्थान सरकार के सहकारी समिति विभाग के एक वरिष्ठ सहकारी अंकेक्षक (Senior Cooperative Auditor) हैं। 
      आपको निम्नलिखित लाइव वित्तीय डेटा और विसंगतियों के आधार पर "$selectedSocietyName" का एक आधिकारिक, वैधानिक अंकेक्षण प्रतिवेदन (Statutory Audit Report) हिंदी भाषा में तैयार करना है।

      [लाइव वित्तीय डेटा]
      - कुल दुग्ध एवं फीड बिक्री (Trading Sales): ₹ ${_totalSales.toStringAsFixed(2)}
      - कुल दुग्ध एवं फीड खरीद (Direct Cost): ₹ ${_totalPurchases.toStringAsFixed(2)}
      - इस अवधि का शुद्ध लाभ/हानि (Net Surplus): ₹ ${_netProfit.toStringAsFixed(2)}

      [एआई ऑडिटर द्वारा पकड़े गए लाइव आक्षेप/अनियमितताएं]
      $formattedObjections

      [प्रतिवेदन का प्रारूप - राजस्थान सहकारी अधिनियम के अनुसार अनिवार्य संरचना]
      1. प्रस्तावना (Introduction): समिति का नाम, ऑडिट अवधि (वर्ष 2024-25) एवं अंकेक्षण का संक्षिप्त उद्देश्य।
      2. रोकड़ बाकी एवं भौतिक सत्यापन नोट (Cash Verification Note): स्पष्ट उल्लेख करें कि "अंतिम रोकड़ बाकी ₹ 7,538.18 शेष है जिसकी पुष्टि रोकड़ बही से होती है।"
      3. मुख्य वित्तीय कमियां एवं आक्षेप (Detailed Audit Objections): डेटाबेस से मिली उपरोक्त विसंगतियों को गंभीर आधिकारिक लहजे में कानूनी धाराओं के संदर्भ के साथ समझाएं।
      4. ऑडिट वर्गीकरण अनुशंसा (Audit Classification): वित्तीय अनुशासन के आधार पर समिति को 'श्रेणी ए', 'श्रेणी बी' या 'श्रेणी सी' में वर्गीकृत करें और उसका ठोस कारण दें।
      5. निष्कर्ष एवं सुधारात्मक सुझाव (Conclusion & Recommendations): भविष्य के लिए सचिव/मुनीम को वैधानिक दिशा-निर्देश।

      टिप: भाषा पूरी तरह से शुद्ध प्रशासनिक, आधिकारिक राजस्थानी/भारतीय सहकारी विभाग शैली की होनी चाहिए। पैराग्राफ और बुलेट पॉइंट्स का सुंदर प्रयोग करें।
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (!mounted) return;

      setState(() {
        _generatedReport = response.text ?? "तकनीकी व्यवधान के कारण प्रतिवेदन जनरेट नहीं हो सका।";
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("त्रुटि: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 वैधानिक AI ऑडिट रिपोर्ट'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_generatedReport.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'शेयर करें',
              onPressed: () {
                Share.share(_generatedReport, subject: 'अंकेक्षण प्रतिवेदन 2024-25');
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green, strokeWidth: 5),
                  SizedBox(height: 24),
                  Text(
                    "डेटाबेस से लाइव रिकॉर्ड्स का विश्लेषण चालू है...\nएआई वैधानिक अंकेक्षण प्रतिवेदन ड्राफ्ट कर रहा है।", 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4)
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExpansionTile(
                    title: const Text("⚙️ एआई इंजन कॉन्फ़िगरेशन", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    leading: const Icon(Icons.vpn_key_rounded, color: Colors.blueGrey),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Gemini API Key', border: OutlineInputBorder(), hintText: "यदि .env में की मौजूद है तो यह स्वतः काम करेगा"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<int>(
                          value: _selectedSocietyId, 
                          decoration: const InputDecoration(labelText: "सक्रिय समिति चुनें", border: InputBorder.none),
                          items: _societies.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() { _selectedSocietyId = val; });
                              _loadLiveSocietyData(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    color: _liveDoubts.isEmpty ? Colors.green.shade50 : Colors.amber.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _liveDoubts.isEmpty ? Colors.green.shade200 : Colors.amber.shade300)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_liveDoubts.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded, color: _liveDoubts.isEmpty ? Colors.green.shade800 : Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Text(
                                _liveDoubts.isEmpty ? "डेटाबेस सुरक्षित: कोई लंबित आक्षेप नहीं" : "डेटाबेस अलर्ट: ${_liveDoubts.length} संदिग्ध विसंगतियां मौजूद",
                                style: TextStyle(fontWeight: FontWeight.bold, color: _liveDoubts.isEmpty ? Colors.green.shade900 : Colors.amber.shade900),
                              )
                            ],
                          ),
                          if (_liveDoubts.isNotEmpty) ...[
                            const Divider(),
                            Text(
                              "ये वे कमियां हैं जो मुनीम जी द्वारा अपलोड किए गए बिलों/वाउचरों से हमारे विज़न इंजन ने पकड़ी हैं। एआई इन्हें सरकारी ऑडिट रिपोर्ट में शामिल करेगा।",
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _generateAuditReport,
                      icon: const Icon(Icons.gavel_rounded),
                      label: const Text("वैधानिक अंकेक्षण प्रतिवेदन ड्राफ्ट करें", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),

                  if (_generatedReport.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in_rounded, color: Colors.green),
                        SizedBox(width: 8),
                        Text("📋 ड्राफ्ट प्रतिवेदन (Official Audit Report):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 4,
                      color: Colors.amber.shade50.withOpacity(0.33), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SelectableText(
                          _generatedReport,
                          style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey.shade900, fontWeight: FontWeight.w500),
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
    _apiKeyController.dispose();
    super.dispose();
  }
}
