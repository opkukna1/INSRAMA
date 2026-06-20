// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'society_management_screen.dart';
import 'bill_upload_screen.dart';
import 'accounts_screen.dart';
import 'audit_report_screen.dart'; 
import 'master_ledger_screen.dart'; 
import 'manual_ledger_screen.dart'; // 🌟 नया: मैन्युअल लेज़र स्क्रीन इंपोर्ट की गई

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _societyCount = 0;
  int _totalAlertsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  // 🧮 डैशबोर्ड के आंकड़े डेटाबेस से लाइव लोड करना
  void _loadDashboardStats() async {
    final societies = await DatabaseHelper.instance.queryAllSocieties();
    
    int tempAlerts = 0;
    // सभी समितियों में AI द्वारा पकड़े गए कुल लाइव डाउट्स की गणना
    for (var society in societies) {
      final doubts = await DatabaseHelper.instance.getDoubtsBySociety(society['id']);
      tempAlerts += doubts.length;
    }

    setState(() {
      _societyCount = societies.length;
      _totalAlertsCount = tempAlerts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, 
      appBar: AppBar(
        title: const Text(
          'INS RAMA ERP',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            onPressed: _loadDashboardStats,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. स्टेट्स बैनर (Operational Overview)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade800, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPERATIONAL OVERVIEW',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'सक्रिय दुग्ध समितियां',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_societyCount Active',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              
              const Text(
                'SYSTEM CORE MODULES',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 14),

              // 2. कोर मॉड्युल्स ग्रिड लेआउट
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  _buildPremiumMenuCard(
                    context,
                    title: 'समिति प्रबंधन',
                    subtitle: 'Societies Registry',
                    icon: Icons.business_center_rounded,
                    gradientColors: [Colors.indigo.shade700, Colors.indigo.shade500],
                    targetScreen: const SocietyManagementScreen(),
                  ),
                  _buildPremiumMenuCard(
                    context,
                    title: 'मैन्युअल लेज़र', // 🌟 नया: मैन्युअल लेज़र बटन
                    subtitle: 'Custom Accounts',
                    icon: Icons.library_books_rounded,
                    gradientColors: [Colors.blue.shade700, Colors.lightBlue.shade500],
                    targetScreen: ManualLedgerScreen(), // अपनी स्क्रीन का सही क्लास नाम यहाँ दें
                  ),
                  _buildPremiumMenuCard(
                    context,
                    title: 'AI डाक्यूमेंट्स',
                    subtitle: 'Smart File Audit',
                    icon: Icons.auto_awesome_rounded,
                    gradientColors: [Colors.amber.shade900, Colors.orange.shade600],
                    targetScreen: const BillUploadScreen(),
                  ),
                  _buildPremiumMenuCard(
                    context,
                    title: 'मास्टर लेज़र ग्रिड',
                    subtitle: 'In-App Excel Sheet',
                    icon: Icons.table_chart_rounded,
                    gradientColors: [Colors.teal.shade700, Colors.teal.shade500],
                    targetScreen: const MasterLedgerScreen(),
                  ),
                  _buildPremiumMenuCard(
                    context,
                    title: 'ऑटोमेटेड फाइनल खाते',
                    subtitle: 'Dynamic P&L & BS',
                    icon: Icons.analytics_rounded,
                    gradientColors: [Colors.purple.shade700, Colors.purple.shade500],
                    targetScreen: const AccountsScreen(),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 3. फॉरेंसिक ऑडिट रिपोर्ट्स
              _buildPremiumMenuCard(
                context,
                title: 'फॉरेंसिक ऑडिट रिपोर्ट्स (AI Alerts)',
                subtitle: _totalAlertsCount > 0 
                    ? '⚠️ सिस्टम में $_totalAlertsCount वित्तीय विसंगतियां जांची जानी शेष हैं'
                    : '✅ सभी वित्तीय दस्तावेज सहकारी मानकों के अनुसार सुरक्षित हैं',
                icon: Icons.gavel_rounded,
                gradientColors: [Colors.red.shade800, Colors.red.shade600],
                targetScreen: const AuditReportScreen(),
                isFullWidth: true,
                badgeValue: _totalAlertsCount > 0 ? _totalAlertsCount : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // प्रीमियम मेनू कार्ड बिल्डर विज़ेट
  Widget _buildPremiumMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Widget targetScreen,
    bool isFullWidth = false,
    int? badgeValue,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => targetScreen)
        ).then((_) => _loadDashboardStats());
      },
      splashColor: gradientColors[0].withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: isFullWidth ? 100 : null,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: isFullWidth
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (badgeValue != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$badgeValue Alerts',
                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 22, color: Colors.white),
                      ),
                      const Icon(Icons.north_east_rounded, color: Colors.white60, size: 16),
                    ],
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
