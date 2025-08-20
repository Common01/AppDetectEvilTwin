import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'CommonDrawer.dart';

class ScanPage extends StatefulWidget {
  final String username;
  final String email;

  const ScanPage({super.key, required this.username, required this.email});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with AutomaticKeepAliveClientMixin {
  List<WiFiAccessPoint> wifiList = [];
  List<WiFiAccessPoint> filteredList = [];
  
  String searchSSID = '';
  bool isScanning = false;
  int currentPage = 0;
  static const int itemsPerPage = 15;

  // Performance optimizations
  static final Map<String, Set<String>> _knownAccessPoints = {};
  static final Map<String, String> _vendorCache = {};
  static DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(seconds: 10);
  
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialScan());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.locationWhenInUse,
      Permission.location,
      Permission.nearbyWifiDevices
    ];
    
    await permissions.request();
  }

  void _initialScan() {
    // Only scan if not recently scanned
    if (_lastScanTime == null || 
        DateTime.now().difference(_lastScanTime!) > _scanCooldown) {
      scanWifi();
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
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final vendor = response.body.trim();
        _vendorCache[prefix] = vendor;
        return vendor;
      }
    } catch (e) {
      // Silently handle errors for better performance
    }
    
    _vendorCache[prefix] = "-";
    return "-";
  }

  bool _isControllerManagedAp(WiFiAccessPoint ap, String? vendor) {
    final lowerSSID = ap.ssid.toLowerCase();
    final lowerVendor = vendor?.toLowerCase() ?? '';

    final knownControllerVendors = ['cisco', 'aruba', 'huawei', 'unifi', 'ruckus', 'tp-link'];
    final meshKeywords = ['mesh', 'ap-', 'wlc', 'controller', 'extender'];

    return knownControllerVendors.any((v) => lowerVendor.contains(v)) ||
           meshKeywords.any((keyword) => lowerSSID.contains(keyword));
  }

  Future<void> scanWifi() async {
    if (isScanning) return;

    // Respect scan cooldown
    if (_lastScanTime != null && 
        DateTime.now().difference(_lastScanTime!) < _scanCooldown) {
      return;
    }

    setState(() {
      isScanning = true;
      searchSSID = '';
      _searchController.clear();
    });

    try {
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        _showSnackBar('ไม่สามารถสแกน Wi-Fi ได้: $canScan', Colors.red);
        return;
      }

      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 2)); // Reduced scan time
      
      final results = await WiFiScan.instance.getScannedResults();
      final processedResults = _processWifiResults(results);

      if (mounted) {
        setState(() {
          wifiList = processedResults;
          filteredList = List.from(processedResults);
          currentPage = 0;
        });

        _lastScanTime = DateTime.now();
        _detectRogueEvilTwin(processedResults);
        _sendToService(processedResults);

        _showSnackBar('พบ Wi-Fi ${processedResults.length} รายการ', Colors.green);
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        _showSnackBar('เกิดข้อผิดพลาดในการสแกน', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => isScanning = false);
      }
    }
  }

  List<WiFiAccessPoint> _processWifiResults(List<WiFiAccessPoint> results) {
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

    return sortedResults;
  }

  void _filterList() {
    if (!mounted) return;
    
    setState(() {
      filteredList = wifiList
          .where((ap) => 
              ap.ssid.toLowerCase().contains(searchSSID.toLowerCase()) ||
              ap.bssid.toLowerCase().contains(searchSSID.toLowerCase()))
          .toList();
      currentPage = 0;
    });
  }

  Future<void> _detectRogueEvilTwin(List<WiFiAccessPoint> scannedAPs) async {
    for (final ap in scannedAPs) {
      final vendor = await _fetchVendorFromBSSID(ap.bssid);

      if (vendor == "-" || _isControllerManagedAp(ap, vendor)) {
        continue;
      }

      final knownBSSIDs = _knownAccessPoints[ap.ssid] ?? <String>{};
      if (knownBSSIDs.isNotEmpty && !knownBSSIDs.contains(ap.bssid)) {
        _showRogueAlert(ap);
        _sendAttackLog(
          bssid: ap.bssid,
          essid: ap.ssid,
          classification: "Evil twin",
        );
      }
      knownBSSIDs.add(ap.bssid);
      _knownAccessPoints[ap.ssid] = knownBSSIDs;
    }
  }

  void _showRogueAlert(WiFiAccessPoint ap) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            content: Text(
              '⚠️ พบ Wi-Fi ที่น่าสงสัย: "${ap.ssid}" BSSID ใหม่ ${ap.bssid}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'ดูรายละเอียด',
              textColor: Colors.white,
              onPressed: () => _showWifiDetailsDialog(ap),
            ),
          ),
        );
      }
    });
  }

  void _showWifiDetailsDialog(WiFiAccessPoint ap) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.wifi,
                    color: _getSignalColor(ap.level),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ap.ssid.isEmpty ? '<ไม่มีชื่อ>' : ap.ssid,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Details
              ...[
                _buildDetailRow(Icons.settings_ethernet, 'BSSID', ap.bssid),
                _buildDetailRow(
                  Icons.signal_cellular_alt, 
                  'Signal Strength', 
                  '${ap.level} dBm (${_getSignalQuality(ap.level)})'
                ),
                _buildDetailRow(Icons.radio, 'Frequency', '${ap.frequency} MHz'),
                _buildDetailRow(Icons.security, 'Security', _getSecurityLabel(ap.capabilities)),
                _buildDetailRow(Icons.router, 'Channel', _getChannelFromFreq(ap.frequency).toString()),
              ].expand((widget) => [widget, const SizedBox(height: 12)]).take(9).toList(),
              
              const SizedBox(height: 8),
              
              // Vendor info with FutureBuilder
              FutureBuilder<String>(
                future: _fetchVendorFromBSSID(ap.bssid),
                builder: (context, snapshot) {
                  final vendor = snapshot.data ?? 'กำลังโหลด...';
                  final isController = _isControllerManagedAp(ap, vendor);

                  return Column(
                    children: [
                      _buildDetailRow(Icons.business, 'Vendor', vendor),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.hub,
                        'Infrastructure',
                        isController ? 'Controller-Based / Mesh' : 'Standalone',
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
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
    if (apiUrl?.isEmpty ?? true) return;

    try {
      final url = Uri.parse('$apiUrl/service-logs');
      final logs = await Future.wait(
        aps.map((ap) async {
          final vendor = await _fetchVendorFromBSSID(ap.bssid);
          final isController = _isControllerManagedAp(ap, vendor);

          return {
            "bssid": ap.bssid,
            "essid": ap.ssid.isEmpty ? 'UNKNOWN' : ap.ssid,
            "signals": ap.level,
            "chanel": _getChannelFromFreq(ap.frequency),
            "frequency": ap.frequency,
            "secue": _getSecurityLabel(ap.capabilities),
            "assetCode": 'TEMP-${ap.bssid.substring(ap.bssid.length - 4)}',
            "deviceName": 'Auto-${ap.ssid.isNotEmpty ? ap.ssid : 'Unknown'}',
            "location": "Unknown",
            "standard": _getStandard(ap.capabilities),
            "vendor": vendor,
            "isController": isController,
          };
        }),
      );

      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'logs': logs}),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error sending to service: $e');
    }
  }

  String _getStandard(String capabilities) {
    if (capabilities.contains("WPA3")) return "802.11ax";
    if (capabilities.contains("WPA2")) return "802.11ac";
    return "802.11n";
  }

  Future<void> _sendAttackLog({
    required String bssid,
    required String essid,
    required String classification,
  }) async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl?.isEmpty ?? true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = int.tryParse(prefs.getString('uid') ?? '');
      if (uid == null) return;

      final url = Uri.parse('$apiUrl/histry');
      final now = DateTime.now().toIso8601String();

      await Future.delayed(Duration(milliseconds: Random().nextInt(200)));
      
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bssid': bssid,
          'essid': essid,
          'date_time': now,
          'email': widget.email,
          'uid': uid,
          'classification': classification,
        }),
      ).timeout(const Duration(seconds: 5));
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

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wi-Fi Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF4F46E5),
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
      
      drawer: CommonDrawer(
        username: widget.username,
        email: widget.email,
        currentPage: 'scan',
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4F46E5).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 600;
            final padding = isTablet ? 24.0 : 16.0;
            final paginatedList = filteredList
                .skip(currentPage * itemsPerPage)
                .take(itemsPerPage)
                .toList();

            return Column(
              children: [
                if (isScanning)
                  const LinearProgressIndicator(
                    color: Color(0xFF4F46E5),
                    backgroundColor: Colors.transparent,
                  ),
                
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      SizedBox(height: padding),
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
                          if (!isScanning && _lastScanTime != null)
                            Text(
                              'อัปเดตล่าสุด: ${DateFormat('HH:mm:ss').format(_lastScanTime!)}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: filteredList.isEmpty && !isScanning
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_off,
                                size: 64,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'ไม่พบ Wi-Fi ใด ๆ',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: scanWifi,
                                icon: const Icon(Icons.refresh),
                                label: const Text('สแกนใหม่'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: padding),
                                itemCount: paginatedList.length,
                                itemBuilder: (context, index) {
                                  final ap = paginatedList[index];
                                  final signalColor = _getSignalColor(ap.level);
                                  
                                  return Card(
                                    elevation: 3,
                                    margin: EdgeInsets.symmetric(
                                      vertical: isTablet ? 8 : 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showWifiDetailsDialog(ap),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: signalColor.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                                                      style: TextStyle(
                                                        fontSize: isTablet ? 18 : 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF4F46E5),
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
                                              SizedBox(height: isTablet ? 16 : 12),
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
                                              _buildDetailRow(
                                                Icons.radio,
                                                'Frequency',
                                                '${ap.frequency} MHz (Ch. ${_getChannelFromFreq(ap.frequency)})',
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
                                                  Text(
                                                    'แตะเพื่อดูรายละเอียดเพิ่มเติม',
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 13 : 12,
                                                      color: const Color(0xFF6B7280),
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
                                padding: EdgeInsets.all(padding),
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
                                    SizedBox(width: isTablet ? 20 : 16),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isTablet ? 20 : 16, 
                                        vertical: 8
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'หน้า ${currentPage + 1} จาก $totalPages',
                                        style: TextStyle(
                                          color: const Color(0xFF4F46E5),
                                          fontWeight: FontWeight.w600,
                                          fontSize: isTablet ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isTablet ? 20 : 16),
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
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}