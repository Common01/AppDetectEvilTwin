import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:temp_wifi_app/page/StatPage.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';
import 'package:temp_wifi_app/page/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import CommonDrawer
import 'CommonDrawer.dart';

class LogPage extends StatefulWidget {
  final String email;
  final String username;

  const LogPage({super.key, required this.username, required this.email});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<Map<String, String>> wifiLogs = [];
  List<Map<String, String>> filteredLogs = [];
  final Map<String, String> _vendorCache = {}; // Cache for vendor lookups
  String searchSSID = '';
  DateTime? selectedDate;
  bool isLoading = false;
  bool isLoadingVendors = false;
  String? error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchHistryLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _fetchVendorFromBSSID(String bssid) async {
    if (bssid.isEmpty) return "-";
    
    final prefix = bssid.toUpperCase().replaceAll(":", "").substring(0, 6);
    
    // Check cache first
    if (_vendorCache.containsKey(prefix)) {
      return _vendorCache[prefix]!;
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://api.macvendors.com/$prefix'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final vendor = response.body.trim();
        _vendorCache[prefix] = vendor; // Cache the result
        return vendor;
      } else {
        _vendorCache[prefix] = "-";
        return "-";
      }
    } catch (e) {
      debugPrint('Error fetching vendor for $prefix: $e');
      _vendorCache[prefix] = "-";
      return "-";
    }
  }

  Future<void> fetchHistryLogs() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      error = null;
    });

    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) {
      if (mounted) {
        setState(() {
          error = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้';
          isLoading = false;
        });
      }
      return;
    }

    try {
      debugPrint('Fetching logs from: $apiUrl/histry?email=${widget.email}');
      
      final response = await http.get(
        Uri.parse('$apiUrl/histry?email=${widget.email}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> logs = data['logs'] ?? [];

        // First, create logs without vendor info (fast)
        if (mounted) {
          setState(() {
            wifiLogs = logs.map<Map<String, String>>((log) => {
              'ssid': log['essid']?.toString() ?? '',
              'bssid': log['bssid']?.toString() ?? '',
              'date': log['date_time']?.toString() ?? '',
              'classification': log['classification']?.toString() ?? '',
              'equipment_name': 'กำลังโหลด...', // Placeholder
            }).toList();
            
            filteredLogs = List.from(wifiLogs);
            isLoading = false;
            isLoadingVendors = true;
          });
        }

        // Then fetch vendor info in background (slow)
        _loadVendorInfo();
        
      } else {
        String errorMessage = 'โหลดข้อมูลล้มเหลว';
        
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorBody['error'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        switch (response.statusCode) {
          case 401:
            errorMessage = 'ไม่มีสิทธิ์เข้าถึงข้อมูล';
            break;
          case 404:
            errorMessage = 'ไม่พบข้อมูล';
            break;
          case 500:
            errorMessage = 'เกิดข้อผิดพลาดในระบบ';
            break;
        }

        if (mounted) {
          setState(() {
            error = errorMessage;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      
      if (mounted) {
        String errorMessage = 'เกิดข้อผิดพลาด: ';
        
        if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
          errorMessage += 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
        } else if (e.toString().contains('TimeoutException') || e.toString().contains('ใช้เวลานานเกินไป')) {
          errorMessage += 'การเชื่อมต่อใช้เวลานานเกินไป';
        } else {
          errorMessage += 'กรุณาลองใหม่อีกครั้ง';
        }
        
        setState(() {
          error = errorMessage;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVendorInfo() async {
    if (!mounted) return;
    
    try {
      // Process in batches to avoid overwhelming the API
      const batchSize = 5;
      final batches = <List<int>>[];
      
      for (int i = 0; i < wifiLogs.length; i += batchSize) {
        batches.add(List.generate(
          (i + batchSize <= wifiLogs.length) ? batchSize : wifiLogs.length - i,
          (index) => i + index,
        ));
      }

      for (final batch in batches) {
        if (!mounted) break;
        
        await Future.wait(batch.map((index) async {
          final bssid = wifiLogs[index]['bssid'] ?? '';
          final vendor = await _fetchVendorFromBSSID(bssid);
          
          if (mounted) {
            setState(() {
              wifiLogs[index]['equipment_name'] = vendor;
            });
          }
        }));
        
        // Small delay between batches to be nice to the API
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Update filtered logs
        if (mounted) {
          _filterLogs();
        }
      }
    } catch (e) {
      debugPrint('Error loading vendor info: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingVendors = false;
        });
      }
    }
  }

  void _filterLogs() {
    if (!mounted) return;
    
    setState(() {
      filteredLogs = wifiLogs.where((log) {
        final matchesSSID = searchSSID.isEmpty || 
            (log['ssid']?.toLowerCase() ?? '').contains(searchSSID.toLowerCase());
        final matchesDate = selectedDate == null ||
            log['date']?.startsWith(DateFormat('yyyy-MM-dd').format(selectedDate!)) == true;
        return matchesSSID && matchesDate;
      }).toList();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF4F46E5),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
      });
      _filterLogs();
    }
  }

  void _clearFilters() {
    if (!mounted) return;
    
    setState(() {
      searchSSID = '';
      selectedDate = null;
      _searchController.clear();
    });
    _filterLogs();
  }

  Future<void> _exportCSV() async {
    try {
      List<List<String>> csvData = [
        ['SSID', 'BSSID', 'Equipment Name', 'Date', 'Classification'],
        ...filteredLogs.map((log) => [
              log['ssid'] ?? '',
              log['bssid'] ?? '',
              log['equipment_name'] ?? '-',
              log['date'] ?? '',
              log['classification'] ?? '',
            ]),
      ];
      
      final csvString = const ListToCsvConverter().convert(csvData);
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/wifi_logs_$timestamp.csv');
      await file.writeAsString(csvString);
      
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Wi-Fi Logs Exported - ${filteredLogs.length} records',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งออกข้อมูล ${filteredLogs.length} รายการสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งออกข้อมูล'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy HH:mm', 'th').format(dateTime);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getClassificationColor(String classification) {
    switch (classification.toLowerCase()) {
      case 'high':
      case 'สูง':
        return Colors.red;
      case 'medium':
      case 'ปานกลาง':
        return Colors.orange;
      case 'low':
      case 'ต่ำ':
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
          hintText: 'ค้นหา SSID...',
          prefixIcon: Icon(Icons.search, color: Color(0xFF4F46E5)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: Color(0xFF6B7280)),
        ),
        onChanged: (value) {
          searchSSID = value;
          _filterLogs();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wi-Fi Log Detector',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : fetchHistryLogs,
            tooltip: 'โหลดใหม่',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: filteredLogs.isEmpty ? null : _exportCSV,
            tooltip: 'ส่งออก CSV',
          ),
        ],
      ),
      
      // ใช้ CommonDrawer แทน Drawer เดิม
      drawer: CommonDrawer(
        username: widget.username,
        email: widget.email,
        currentPage: 'log',
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
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    SizedBox(height: 16),
                    Text(
                      'กำลังโหลดข้อมูล...',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              )
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: fetchHistryLogs,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Search Bar
                        _buildSearchBar(),
                        const SizedBox(height: 12),

                        // Filter Row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.date_range, color: Color(0xFF4F46E5)),
                                label: Text(
                                  selectedDate != null
                                      ? DateFormat('dd MMM yyyy', 'th').format(selectedDate!)
                                      : 'เลือกวันที่',
                                  style: const TextStyle(color: Color(0xFF4F46E5)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF4F46E5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (selectedDate != null || searchSSID.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                onPressed: _clearFilters,
                                tooltip: 'ล้างตัวกรอง',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Status Bar
                        if (isLoadingVendors)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'กำลังโหลดข้อมูลอุปกรณ์...',
                                  style: TextStyle(color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ),
                        
                        if (isLoadingVendors) const SizedBox(height: 12),

                        // Results Count
                        Row(
                          children: [
                            Text(
                              'ผลลัพธ์: ${filteredLogs.length} รายการ',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // List
                        Expanded(
                          child: filteredLogs.isEmpty
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
                                        'ไม่พบข้อมูลที่ตรงกับเงื่อนไข',
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = filteredLogs[index];
                                    final classification = log['classification'] ?? '';
                                    
                                    return Card(
                                      elevation: 3,
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getClassificationColor(classification).withOpacity(0.3),
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
                                                    color: _getClassificationColor(classification),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      log['ssid']?.isNotEmpty == true 
                                                          ? log['ssid']!
                                                          : '<ไม่มีชื่อ>',
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
                                                      color: _getClassificationColor(classification)
                                                          .withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      classification.isNotEmpty ? classification : 'ไม่ระบุ',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: _getClassificationColor(classification),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              _buildInfoRow(
                                                Icons.router,
                                                'อุปกรณ์',
                                                log['equipment_name'] ?? '-',
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                Icons.settings_ethernet,
                                                'BSSID',
                                                log['bssid'] ?? '-',
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                Icons.access_time,
                                                'เวลา',
                                                _formatDate(log['date']),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF6B7280),
        ),
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
              color: Color(0xFF4F46E5), // เปลี่ยนเป็นสีม่วง
            ),
          ),
        ),
      ],
    );
  }
}