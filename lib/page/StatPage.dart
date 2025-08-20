import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';
import 'package:temp_wifi_app/page/LogPage.dart';
import 'package:temp_wifi_app/page/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import CommonDrawer
import 'CommonDrawer.dart';

class Statpage extends StatefulWidget {
  final String email;
  final String username;

  const Statpage({super.key, required this.username, required this.email});

  @override
  State<Statpage> createState() => _StatpageState();
}

class _StatpageState extends State<Statpage> with TickerProviderStateMixin {
  Map<String, dynamic> stats = {};
  Map<String, dynamic> chartData = {};
  List<Map<String, dynamic>> recentAttacks = [];
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    fetchStats();
    fetchRecentAttacks();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chartController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> fetchStats() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = null;
    });

    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) {
      if (mounted) {
        setState(() {
          errorMessage = 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้';
          isLoading = false;
          hasError = true;
        });
      }
      return;
    }

    try {
      final uri = Uri.parse("$apiUrl/histry/stats?email=${widget.email}");
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          stats = data['stats'] ?? {};
          _generateChartData();
          isLoading = false;
        });

        // Start animations
        _fadeController.forward();
        _scaleController.forward();
        _chartController.forward();
      } else {
        String errorMsg = 'โหลดข้อมูลล้มเหลว';
        
        try {
          final errorBody = jsonDecode(response.body);
          errorMsg = errorBody['message'] ?? errorBody['error'] ?? errorMsg;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        switch (response.statusCode) {
          case 401:
            errorMsg = 'ไม่มีสิทธิ์เข้าถึงข้อมูล';
            break;
          case 404:
            errorMsg = 'ไม่พบข้อมูลสถิติ';
            break;
          case 500:
            errorMsg = 'เกิดข้อผิดพลาดในระบบ';
            break;
        }

        if (mounted) {
          setState(() {
            errorMessage = errorMsg;
            isLoading = false;
            hasError = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      
      if (mounted) {
        String errorMsg = 'เกิดข้อผิดพลาด: ';
        
        if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
          errorMsg += 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
        } else if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
          errorMsg += 'การเชื่อมต่อใช้เวลานานเกินไป';
        } else {
          errorMsg += 'กรุณาลองใหม่อีกครั้ง';
        }
        
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
          hasError = true;
        });
      }
    }
  }

  Future<void> fetchRecentAttacks() async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/histry?email=${widget.email}&limit=5'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        List<dynamic> logs = data['logs'] ?? [];
        
        setState(() {
          recentAttacks = logs.take(5).map<Map<String, dynamic>>((log) => {
            'ssid': log['essid']?.toString() ?? '',
            'bssid': log['bssid']?.toString() ?? '',
            'date': log['date_time']?.toString() ?? '',
            'classification': log['classification']?.toString() ?? '',
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent attacks: $e');
    }
  }

  void _generateChartData() {
    chartData = {};
    stats.forEach((key, value) {
      if (value is Map && value.containsKey('count')) {
        chartData[key] = value['count'] ?? 0;
      }
    });
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

  String formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "-";
    try {
      final date = DateTime.parse(rawDate);
      return DateFormat("dd MMM yyyy HH:mm", 'th').format(date);
    } catch (_) {
      return rawDate;
    }
  }

  String safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  Color getAttackTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'evil twin':
      case 'eviltwin':
        return const Color(0xFFFF6B35);
      case 'rogue':
      case 'rogue ap':
        return const Color(0xFFDC2626);
      case 'unknown':
      case 'ไม่ทราบประเภท':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  IconData getAttackTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'evil twin':
      case 'eviltwin':
        return Icons.wifi_tethering_error_rounded;
      case 'rogue':
      case 'rogue ap':
        return Icons.warning_amber_rounded;
      case 'unknown':
      case 'ไม่ทราบประเภท':
        return Icons.help_outline;
      default:
        return Icons.security;
    }
  }

  Widget buildAnimatedStatCard({
    required String title,
    required int count,
    required String firstAttack,
    required String lastAttack,
    required Color color,
    required IconData icon,
    required int index,
  }) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.05),
                      color.withOpacity(0.02),
                    ],
                  ),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count ครั้ง',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.access_time, 'เริ่มต้น', formatDate(firstAttack)),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.schedule, 'ล่าสุด', formatDate(lastAttack)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
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

  Widget buildPieChart() {
    if (chartData.isEmpty) return const SizedBox();

    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'แผนภูมิสถิติการโจมตี',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    size: const Size.square(200),
                    painter: PieChartPainter(
                      data: chartData,
                      animation: _chartAnimation.value,
                      getColor: getAttackTypeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildChartLegend(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartLegend() {
    final total = chartData.values.fold<int>(0, (sum, value) => sum + (value as int));
    
    return Column(
      children: chartData.entries.map((entry) {
        final color = getAttackTypeColor(entry.key);
        final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.key == 'eviltwin' ? 'Evil Twin' : 
                  entry.key == 'rogue' ? 'Rogue AP' : 
                  'ไม่ทราบประเภท',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              Text(
                '${entry.value} ($percentage%)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildRecentAttacks() {
    if (recentAttacks.isEmpty) return const SizedBox();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Color(0xFF4F46E5), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'การโจมตีล่าสุด',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...recentAttacks.asMap().entries.map((entry) {
                final index = entry.key;
                final attack = entry.value;
                final color = getAttackTypeColor(attack['classification'] ?? '');
                
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          getAttackTypeIcon(attack['classification'] ?? ''),
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attack['ssid']?.isNotEmpty == true 
                                  ? attack['ssid']! 
                                  : '<ไม่มีชื่อ>',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            Text(
                              attack['bssid'] ?? '-',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatDate(attack['date']),
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
      ),
    );
  }

  Widget buildContent() {
    if (hasError) {
      return Center(
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
              errorMessage ?? 'เกิดข้อผิดพลาดในการโหลดข้อมูล',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                fetchStats();
                fetchRecentAttacks();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'ไม่มีข้อมูลการโจมตีในระบบ',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Summary Cards
        if (stats.containsKey('eviltwin'))
          buildAnimatedStatCard(
            title: "Evil Twin",
            count: stats["eviltwin"]["count"] ?? 0,
            firstAttack: safeString(stats["eviltwin"]["first_attack"]),
            lastAttack: safeString(stats["eviltwin"]["last_attack"]),
            color: const Color(0xFFFF6B35),
            icon: Icons.wifi_tethering_error_rounded,
            index: 0,
          ),
        if (stats.containsKey('rogue'))
          buildAnimatedStatCard(
            title: "Rogue AP",
            count: stats["rogue"]["count"] ?? 0,
            firstAttack: safeString(stats["rogue"]["first_attack"]),
            lastAttack: safeString(stats["rogue"]["last_attack"]),
            color: const Color(0xFFDC2626),
            icon: Icons.warning_amber_rounded,
            index: 1,
          ),
        if (stats.containsKey('unknown'))
          buildAnimatedStatCard(
            title: "ไม่ทราบประเภท",
            count: stats["unknown"]["count"] ?? 0,
            firstAttack: safeString(stats["unknown"]["first_attack"]),
            lastAttack: safeString(stats["unknown"]["last_attack"]),
            color: const Color(0xFF6B7280),
            icon: Icons.help_outline,
            index: 2,
          ),

        // Pie Chart
        buildPieChart(),

        // Recent Attacks
        buildRecentAttacks(),

        // Footer
        const SizedBox(height: 20),
        const Center(
          child: Text(
            "ข้อมูลอัปเดตจากระบบตรวจจับอัตโนมัติ",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'สถิติการโจมตี Wi-Fi',
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
            onPressed: isLoading 
                ? null 
                : () {
                    fetchStats();
                    fetchRecentAttacks();
                  },
            tooltip: 'โหลดใหม่',
          ),
        ],
      ),
      
      // ใช้ CommonDrawer แทน Drawer เดิม
      drawer: CommonDrawer(
        username: widget.username,
        email: widget.email,
        currentPage: 'stat',
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
                      'กำลังโหลดข้อมูลสถิติ...',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              )
            : buildContent(),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final double animation;
  final Color Function(String) getColor;

  PieChartPainter({
    required this.data,
    required this.animation,
    required this.getColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.8;
    final total = data.values.fold<int>(0, (sum, value) => sum + (value as int));

    if (total == 0) return;

    double startAngle = -pi / 2;
    
    data.forEach((key, value) {
      final sweepAngle = (value / total) * 2 * pi * animation;
      final paint = Paint()
        ..color = getColor(key)
        ..style = PaintingStyle.fill;

      // Draw pie slice
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.data != data;
  }
}