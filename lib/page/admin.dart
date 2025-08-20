import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:temp_wifi_app/page/UserManagePage.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';
import 'package:temp_wifi_app/page/LogPage.dart';
import 'package:temp_wifi_app/page/StatPage.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'login.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<WiFiAccessPoint> wifiList = [];
  List<WiFiAccessPoint> filteredList = [];
  List<Map<String, dynamic>> recentActivity = [];
  String searchSSID = '';
  bool isScanning = false;
  int currentPage = 0;
  static const int itemsPerPage = 10;

  final Map<String, Set<String>> _knownAccessPoints = {};
  final Map<String, String> _vendorCache = {};
  final _searchController = TextEditingController();

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  String username = '';
  String email = '';
  String? role;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _checkAccess();
    _loadRecentActivity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('role');
      final name = prefs.getString('username');
      final mail = prefs.getString('email');

      if (userRole == null || userRole.toLowerCase() != 'admin') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } else {
        setState(() {
          username = name ?? 'Admin';
          email = mail ?? '';
          role = userRole;
        });
      }
    } catch (e) {
      debugPrint('Error checking access: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.locationWhenInUse,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
  }

  Future<void> _loadRecentActivity() async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/admin/recent-activity'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        List<dynamic> activities = data['activities'] ?? [];
        
        setState(() {
          recentActivity = activities.take(10).map<Map<String, dynamic>>((activity) => {
            'type': activity['type']?.toString() ?? '',
            'description': activity['description']?.toString() ?? '',
            'user': activity['user']?.toString() ?? '',
            'timestamp': activity['timestamp']?.toString() ?? '',
            'severity': activity['severity']?.toString() ?? 'info',
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
    }
  }

  void _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  Future<String> _fetchVendorFromBSSID(String bssid) async {
    if (bssid.isEmpty) return "-";
    
    final prefix = bssid.toUpperCase().replaceAll(":", "").substring(0, 6);
    
    if (_vendorCache.containsKey(prefix)) {
      return _vendorCache[prefix]!;
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://api.macvendors.com/$prefix'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final vendor = response.body.trim();
        _vendorCache[prefix] = vendor;
        return vendor;
      } else {
        _vendorCache[prefix] = "-";
        return "-";
      }
    } catch (e) {
      _vendorCache[prefix] = "-";
      return "-";
    }
  }

  Future<void> scanWifi() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      searchSSID = '';
      _searchController.clear();
    });

    try {
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        setState(() => isScanning = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ไม่สามารถสแกน Wi-Fi ได้: $canScan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 3));
      final results = await WiFiScan.instance.getScannedResults();

      // Remove duplicates and sort by signal strength
      final uniqueResults = <String, WiFiAccessPoint>{};
      for (final ap in results) {
        final key = '${ap.ssid}_${ap.bssid}';
        if (!uniqueResults.containsKey(key) || ap.level > uniqueResults[key]!.level) {
          uniqueResults[key] = ap;
        }
      }

      final sortedResults = uniqueResults.values.toList()
        ..sort((a, b) => b.level.compareTo(a.level));

      _detectRogueEvilTwin(sortedResults);

      if (mounted) {
        setState(() {
          wifiList = sortedResults;
          filteredList = List.from(sortedResults);
          currentPage = 0;
          isScanning = false;
        });
      }

      _sendToService(sortedResults);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('พบ Wi-Fi ${sortedResults.length} รายการ'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        setState(() => isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสแกน'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterList() {
    if (!mounted) return;
    
    setState(() {
      filteredList = wifiList
          .where((ap) => ap.ssid.toLowerCase().contains(searchSSID.toLowerCase()) ||
                        ap.bssid.toLowerCase().contains(searchSSID.toLowerCase()))
          .toList();
      currentPage = 0;
    });
  }

  void _detectRogueEvilTwin(List<WiFiAccessPoint> scannedAPs) {
    for (final ap in scannedAPs) {
      final knownBSSIDs = _knownAccessPoints[ap.ssid] ?? <String>{};
      if (knownBSSIDs.isNotEmpty && !knownBSSIDs.contains(ap.bssid)) {
        _showRogueAlert(ap);
        _sendAttackLog(
          bssid: ap.bssid,
          essid: ap.ssid,
          classification: "evil twin",
        );
      }
      knownBSSIDs.add(ap.bssid);
      _knownAccessPoints[ap.ssid] = knownBSSIDs;
    }
  }

  void _showRogueAlert(WiFiAccessPoint ap) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          content: Text(
            '⚠️ [ADMIN] พบ Wi-Fi ที่น่าสงสัย: "${ap.ssid}" BSSID ใหม่ ${ap.bssid}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'ดูรายละเอียด',
            textColor: Colors.white,
            onPressed: () => _showWifiDetailsDialog(context, ap),
          ),
        ));
      }
    });
  }

  void _showWifiDetailsDialog(BuildContext context, WiFiAccessPoint ap) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.wifi,
              color: _getSignalColor(ap.level),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ap.ssid.isEmpty ? '<ไม่มีชื่อ>' : ap.ssid,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(Icons.settings_ethernet, 'BSSID', ap.bssid),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.signal_cellular_alt, 
                'Signal Strength', 
                '${ap.level} dBm (${_getSignalQuality(ap.level)})'
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.radio, 'Frequency', '${ap.frequency} MHz'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.security, 'Security', _getSecurityLabel(ap.capabilities)),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.router, 'Channel', _getChannelFromFreq(ap.frequency).toString()),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: _fetchVendorFromBSSID(ap.bssid),
                builder: (context, snapshot) {
                  return _buildDetailRow(
                    Icons.business,
                    'Vendor',
                    snapshot.hasData ? snapshot.data! : 'กำลังโหลด...',
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'ปิด',
              style: TextStyle(color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
      ],
    );
  }

  int _getChannelFromFreq(int frequency) {
    if (frequency >= 2412 && frequency <= 2484) {
      return ((frequency - 2412) ~/ 5) + 1;
    } else if (frequency >= 5170 && frequency <= 5825) {
      return ((frequency - 5000) ~/ 5);
    }
    return 0;
  }

  Color _getSignalColor(int level) {
    if (level >= -50) return Colors.green;
    if (level >= -70) return Colors.orange;
    return Colors.red;
  }

  String _getSignalQuality(int level) {
    if (level >= -50) return 'แรงมาก';
    if (level >= -60) return 'แรง';
    if (level >= -70) return 'ปานกลาง';
    if (level >= -80) return 'อ่อน';
    return 'อ่อนมาก';
  }

  Future<void> _sendToService(List<WiFiAccessPoint> aps) async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null) return;

    final url = Uri.parse('$apiUrl/service-logs');

    final logs = aps.map((ap) {
      return {
        "bssid": ap.bssid,
        "essid": ap.ssid.isEmpty ? 'UNKNOWN' : ap.ssid,
        "signals": ap.level,
        "chanel": _getChannelFromFreq(ap.frequency),
        "frequency": ap.frequency,
        "secue": _getSecurityLabel(ap.capabilities),
        "assetCode": 'ADMIN-${ap.bssid.substring(ap.bssid.length - 4)}',
        "deviceName": 'Admin-${ap.ssid.isNotEmpty ? ap.ssid : 'Unknown'}',
        "location": "Admin Scan",
        "standard": ap.capabilities.contains("WPA3")
            ? "802.11ax"
            : ap.capabilities.contains("WPA2")
                ? "802.11ac"
                : "802.11n",
      };
    }).toList();

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'logs': logs}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error sending to service: $e');
    }
  }

  Future<void> _sendAttackLog({
    required String bssid,
    required String essid,
    required String classification,
  }) async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null) return;

    final url = Uri.parse('$apiUrl/histry');

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = int.tryParse(prefs.getString('uid') ?? '');
      if (uid == null) return;

      final now = DateTime.now().toIso8601String();

      await Future.delayed(Duration(milliseconds: Random().nextInt(300)));
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bssid': bssid,
          'essid': essid,
          'date_time': now,
          'email': email,
          'uid': uid,
          'classification': classification,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error sending attack log: $e');
    }
  }

  String _getSecurityLabel(String capabilities) {
    if (capabilities.contains("WPA3")) return "WPA3";
    if (capabilities.contains("WPA2")) return "WPA2";
    if (capabilities.contains("WPA")) return "WPA";
    if (capabilities.contains("WEP")) return "WEP";
    return "เปิด";
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateStr);
      return DateFormat('dd MMM HH:mm', 'th').format(dateTime);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'error':
        return Colors.red;
      case 'medium':
      case 'warning':
        return Colors.orange;
      case 'low':
      case 'info':
        return Colors.blue;
      case 'success':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4F46E5).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'ค้นหา SSID หรือ BSSID...',
          prefixIcon: Icon(Icons.search, color: Color(0xFF4F46E5)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: Color(0xFF6B7280)),
        ),
        onChanged: (value) {
          searchSSID = value;
          _filterList();
        },
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (recentActivity.isEmpty) return const SizedBox();

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFF4F46E5), size: 20),
                SizedBox(width: 8),
                Text(
                  'กิจกรรมล่าสุด',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recentActivity.take(5).map((activity) {
              final color = _getSeverityColor(activity['severity'] ?? 'info');
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.circle,
                        color: color,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['description'] ?? '-',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          Text(
                            activity['user'] ?? '-',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(activity['timestamp']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Admin Drawer Widget
  Widget _buildAdminDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.admin_panel_settings, 
                size: 40, 
                color: Color(0xFFDC2626)
              ),
            ),
            accountName: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: Text(email),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDC2626),
                  Color(0xFFB91C1C),
                ],
              ),
            ),
          ),
          // Admin Only Sections
          ListTile(
            leading: const Icon(Icons.dashboard, color: Color(0xFFDC2626)),
            title: const Text('Admin Dashboard'),
            selected: true,
            selectedTileColor: const Color(0xFFDC2626).withOpacity(0.1),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Color(0xFFDC2626)),
            title: const Text('จัดการผู้ใช้งาน'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Usermanagepage()),
              );
            },
          ),
          const Divider(),
          // Shared Sections (Same as User)
          ListTile(
            leading: const Icon(Icons.wifi, color: Color(0xFF4F46E5)),
            title: const Text('สแกน Wi-Fi'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanPage(username: username, email: email),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF4F46E5)),
            title: const Text('Log Wi-Fi'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogPage(username: username, email: email),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Color(0xFF4F46E5)),
            title: const Text('Stat Wi-Fi'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Statpage(username: username, email: email),
                ),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedList = filteredList
        .skip(currentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFDC2626), // Red for admin
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: isScanning 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: isScanning ? 'กำลังสแกน...' : 'สแกนใหม่',
            onPressed: isScanning ? null : scanWifi,
          ),
        ],
      ),

      drawer: _buildAdminDrawer(),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFDC2626).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Recent Activity Card (Moved up to replace System Stats)
              _buildRecentActivity(),

              // Wi-Fi Scanner Section
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi_find, color: Color(0xFF4F46E5), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Wi-Fi Scanner (Admin)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const Spacer(),
                          if (!isScanning)
                            ElevatedButton.icon(
                              onPressed: scanWifi,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('สแกน'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      if (isScanning)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          child: const Column(
                            children: [
                              LinearProgressIndicator(color: Color(0xFF4F46E5)),
                              SizedBox(height: 8),
                              Text(
                                'กำลังสแกน Wi-Fi...',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),

                      if (wifiList.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Text(
                              'ผลลัพธ์: ${filteredList.length} รายการ',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'อัปเดตล่าสุด: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Wi-Fi List
                        SizedBox(
                          height: 400,
                          child: filteredList.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wifi_off,
                                        size: 48,
                                        color: Color(0xFF6B7280),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'ไม่พบ Wi-Fi ที่ตรงกับเงื่อนไข',
                                        style: TextStyle(color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: paginatedList.length,
                                  itemBuilder: (context, index) {
                                    final ap = paginatedList[index];
                                    final signalColor = _getSignalColor(ap.level);
                                    
                                    return Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _showWifiDetailsDialog(context, ap),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: signalColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.wifi,
                                                      color: signalColor,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        ap.ssid.isEmpty ? '<ไม่มีชื่อ>' : ap.ssid,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF4F46E5),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: signalColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${ap.level} dBm',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: signalColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                _buildDetailRow(
                                                  Icons.settings_ethernet,
                                                  'BSSID',
                                                  ap.bssid,
                                                ),
                                                const SizedBox(height: 8),
                                                _buildDetailRow(
                                                  Icons.security,
                                                  'Security',
                                                  _getSecurityLabel(ap.capabilities),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.touch_app,
                                                      size: 14,
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Text(
                                                      'แตะเพื่อดูรายละเอียดเพิ่มเติม',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF6B7280),
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Pagination
                        if (totalPages > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                                  onPressed: currentPage > 0
                                      ? () => setState(() => currentPage--)
                                      : null,
                                  style: IconButton.styleFrom(
                                    backgroundColor: currentPage > 0 
                                        ? const Color(0xFF4F46E5) 
                                        : Colors.grey,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'หน้า ${currentPage + 1} จาก $totalPages',
                                    style: const TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                                  onPressed: currentPage < totalPages - 1
                                      ? () => setState(() => currentPage++)
                                      : null,
                                  style: IconButton.styleFrom(
                                    backgroundColor: currentPage < totalPages - 1 
                                        ? const Color(0xFF4F46E5) 
                                        : Colors.grey,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      
                      if (wifiList.isEmpty && !isScanning)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 32),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 48,
                                  color: Color(0xFF6B7280),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'ยังไม่มีการสแกน Wi-Fi',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'กดปุ่ม "สแกน" เพื่อเริ่มค้นหา Wi-Fi',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}