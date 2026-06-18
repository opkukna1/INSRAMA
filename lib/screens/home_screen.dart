import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'society_management_screen.dart';
import 'bill_upload_screen.dart';
import 'accounts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _societyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  // ऐप खुलते ही डेटाबेस से रजिस्टर्ड समितियों की संख्या गिनना
  void _loadDashboardStats() async {
    final societies = await DatabaseHelper.instance.queryAllSocieties();
    setState(() {
      _societyCount = societies.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🥛 INS Rama - मुख्य डैशबोर्ड'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats, // डेटा रीफ्रेश करने के लिए
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. स्वागत संदेश और क्विक स्टेट्स कार्ड
            Card(
              color: Colors.green.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.green.shade700,
                      child: const Icon(Icons.analytics, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'राम राम सा 🙏',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'लोकल डेटाबेस में कुल पंजीकृत समितियां: $_societyCount',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              '🛠️ मुख्य टूल्स और फीचर्स:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 2. ग्रिड मेनू नेविगेशन के लिए
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'समिति प्रबंधन\n(Manage)',
                    icon: Icons.business,
                    color: Colors.blue.shade700,
                    targetScreen: const SocietyManagementScreen(),
                  ),
                  _buildMenuCard(
                    context,
                    title: 'AI बिल प्रोसेसिंग\n(Upload PDFs)',
                    icon: Icons.picture_as_pdf,
                    color: Colors.orange.shade800,
                    targetScreen: const BillUploadScreen(),
                  ),
                  _buildMenuCard(
                    context,
                    title: 'लेजर एवं खाते\n(Accounts)',
                    icon: Icons.calculate,
                    color: Colors.purple.shade700,
                    targetScreen: const AccountsScreen(),
                  ),
                  _buildMenuCard(
                    context,
                    title: 'ऑडिट रिपोर्ट्स\n(GSS/Upcoming)',
                    icon: Icons.assignment_turned_in,
                    color: Colors.grey.shade600,
                    targetScreen: null, // आगामी फीचर के लिए
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // मेनू कार्ड बनाने का कस्टमाइज्ड विजेट
  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget? targetScreen,
  }) {
    return InkWell(
      onTap: () {
        if (targetScreen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen)).then((_) {
            // जब यूजर स्क्रीन से वापस आए, तो होम स्क्रीन के आंकड़े रीफ्रेश करें
            _loadDashboardStats();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('यह मॉड्यूल आगामी चरण में सक्रिय किया जाएगा।')),
          );
        }
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.85), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
