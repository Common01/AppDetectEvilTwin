import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'CommonDrawer.dart';

class LogPage extends StatefulWidget {
  final String email;
  final String username;

  const LogPage({super.key, required this.username, required this.email});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> with AutomaticKeepAliveClientMixin {
  List<Map<String, String>> wifiLogs = [];
  List<Map<String, String>> filteredLogs = [];
  
  String searchSSID = '';
  DateTime? selectedDate;
  bool isLoading = false;
  bool isLoadingVendors = false;
  String? error;

  // Performance optimizations
  static final Map<String, String> _vendorCache = {};
  static final Map<String, List<Map<String, String>>> _logsCache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchHistoryLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _shouldUseCache {
    return _logsCache.containsKey(widget.email) &&
           _lastCacheUpdate != null &&
           DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
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
      }
    } catch (e) {
      debugPrint('Error fetching vendor for $prefix: $e');
    }
    
    _vendorCache[prefix] = "-";
    return "-";
  }

  Future<void> fetchHistoryLogs() async {
    if (!mounted) return;

    // Check cache first
    if (_shouldUseCache) {
      setState(() {
        wifiLogs = List.from(_logsCache[widget.email]!);
        filteredLogs = List.from(wifiLogs);
        isLoading = false;
      });
      _loadVendorInfoBatch();
      return;
    }
    
    setState(() {
      isLoading = true;
      error = null;
    });

    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl?.isEmpty ?? true) {
      if (mounted) {
        setState(() {
          error = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้';
          isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/histry?email=${widget.email}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> logs = data['logs'] ?? [];

        final processedLogs = logs.map<Map<String, String>>((log) => {
          'ssid': log['essid']?.toString() ?? '',
          'bssid': log['bssid']?.toString() ?? '',
          'date': log['date_time']?.toString() ?? '',
          'classification': log['classification']?.toString() ?? '',
          'equipment_name': 'กำลังโหลด...',
        }).toList();

        if (mounted) {
          setState(() {
            wifiLogs = processedLogs;
            filteredLogs = List.from(processedLogs);
            isLoading = false;
            isLoadingVendors = true;
          });
          
          // Cache the logs
          _logsCache[widget.email] = List.from(processedLogs);
          _lastCacheUpdate = DateTime.now();
        }

        // Load vendor info in background
        _loadVendorInfoBatch();
        
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) {
        _showErrorMessage(e);
      }
    }
  }

  void _handleErrorResponse(http.Response response) {
    String errorMessage = 'โหลดข้อมูลล้มเหลว';
    
    try {
      final errorBody = jsonDecode(response.body);
      errorMessage = errorBody['message'] ?? errorBody['error'] ?? errorMessage;
    } catch (_) {}

    switch (response.statusCode) {
      case 401: errorMessage = 'ไม่มีสิทธิ์เข้าถึงข้อมูล'; break;
      case 404: errorMessage = 'ไม่พบข้อมูล'; break;
      case 500: errorMessage = 'เกิดข้อผิดพลาดในระบบ'; break;
    }

    setState(() {
      error = errorMessage;
      isLoading = false;
    });
  }

  void _showErrorMessage(dynamic e) {
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

  Future<void> _loadVendorInfoBatch() async {
    if (!mounted || wifiLogs.isEmpty) return;
    
    try {
      const batchSize = 5;
      final totalBatches = (wifiLogs.length / batchSize).ceil();
      
      for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
        if (!mounted) break;
        
        final startIndex = batchIndex * batchSize;
        final endIndex = (startIndex + batchSize).clamp(0, wifiLogs.length);
        final batch = wifiLogs.sublist(startIndex, endIndex);
        
        await Future.wait(
          batch.asMap().entries.map((entry) async {
            final realIndex = startIndex + entry.key;
            final log = entry.value;
            final bssid = log['bssid'] ?? '';
            final vendor = await _fetchVendorFromBSSID(bssid);
            
            if (mounted && realIndex < wifiLogs.length) {
              setState(() {
                wifiLogs[realIndex]['equipment_name'] = vendor;
              });
            }
          }),
        );
        
        // Update filtered logs and add small delay
        if (mounted) {
          _filterLogs();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      debugPrint('Error loading vendor info: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingVendors = false);
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
      setState(() => selectedDate = picked);
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
    if (filteredLogs.isEmpty) return;

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
            behavior: SnackBarBehavior.floating,
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr?.isEmpty ?? true) return '';
    try {
      final dateTime = DateTime.parse(dateStr!);
      return DateFormat('dd MMM yyyy HH:mm', 'th').format(dateTime);
    } catch (_) {
      return dateStr!;
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wi-Fi Log Detector',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : fetchHistoryLogs,
            tooltip: 'โหลดใหม่',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: filteredLogs.isEmpty ? null : _exportCSV,
            tooltip: 'ส่งออก CSV',
          ),
        ],
      ),
      
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
                    Text('กำลังโหลดข้อมูล...', style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              )
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.withOpacity(0.7)),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: fetchHistoryLogs,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth > 600;
                      final padding = isTablet ? 24.0 : 16.0;
                      
                      return Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          children: [
                            // Search and Filters
                            _buildSearchBar(),
                            SizedBox(height: padding * 0.75),

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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            SizedBox(height: padding),

                            // Status and Results Count
                            Row(
                              children: [
                                Text(
                                  'ผลลัพธ์: ${filteredLogs.length} รายการ',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                if (isLoadingVendors)
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'กำลังโหลดข้อมูลอุปกรณ์...',
                                        style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            SizedBox(height: padding * 0.75),

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
                                  : RefreshIndicator(
                                      onRefresh: fetchHistoryLogs,
                                      child: ListView.builder(
                                        itemCount: filteredLogs.length,
                                        itemBuilder: (context, index) {
                                          final log = filteredLogs[index];
                                          final classification = log['classification'] ?? '';
                                          
                                          return Card(
                                            elevation: 3,
                                            margin: EdgeInsets.symmetric(
                                              vertical: isTablet ? 8 : 6,
                                            ),
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
                                                padding: EdgeInsets.all(isTablet ? 20 : 16),
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
                                                    SizedBox(height: isTablet ? 16 : 12),
                                                    _buildInfoRow(
                                                      Icons.router,
                                                      'อุปกรณ์',
                                                      log['equipment_name'] ?? '-',
                                                    ),
                                                    _buildInfoRow(
                                                      Icons.settings_ethernet,
                                                      'BSSID',
                                                      log['bssid'] ?? '-',
                                                    ),
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
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}