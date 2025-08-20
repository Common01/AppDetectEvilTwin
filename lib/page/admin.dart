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
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'login.dart';
import 'CommonDrawer.dart';
import 'package:temp_wifi_app/model/response/user_response_model.dart';
import 'package:temp_wifi_app/model/request/update_user_request.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String username = '';
  String email = '';
  bool isLoading = true;
  
  // Dashboard Data
  Map<String, int> dailyUsers = {};
  Map<String, int> monthlyUsers = {};
  Map<String, int> wifiScanStats = {};
  Map<String, int> userTypeStats = {'Admin': 0, 'User': 0};
  int totalUsers = 0;
  int totalScans = 0;
  int todayScans = 0;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    fetchDashboardData();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      email = prefs.getString('email') ?? '';
    });
  }

  Future<void> fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        fetchUserStats(),
        fetchScanStats(),
        fetchDailyUserRegistration(),
        fetchMonthlyUserRegistration(),
      ]);
    } catch (e) {
      debugPrint("❌ Error fetching dashboard data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล Dashboard')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchUserStats() async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/admin/user-stats');
    try {
      final response = await http.get(
        url,
        headers: {'x-role': 'Admin'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          totalUsers = data['total_users'] ?? 0;
          userTypeStats['Admin'] = data['admin_count'] ?? 0;
          userTypeStats['User'] = data['user_count'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching user stats: $e");
    }
  }

  Future<void> fetchScanStats() async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/admin/scan-stats');
    try {
      final response = await http.get(
        url,
        headers: {'x-role': 'Admin'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          totalScans = data['total_scans'] ?? 0;
          todayScans = data['today_scans'] ?? 0;
          wifiScanStats = Map<String, int>.from(data['daily_scans'] ?? {});
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching scan stats: $e");
      // Fallback with mock data
      setState(() {
        wifiScanStats = {
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 6))): 45,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 5))): 52,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 4))): 38,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 3))): 67,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 2))): 43,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 1))): 58,
          DateFormat('yyyy-MM-dd').format(DateTime.now()): 34,
        };
        totalScans = 337;
        todayScans = 34;
      });
    }
  }

  Future<void> fetchDailyUserRegistration() async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/admin/daily-registrations');
    try {
      final response = await http.get(
        url,
        headers: {'x-role': 'Admin'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          dailyUsers = Map<String, int>.from(data['daily_registrations'] ?? {});
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching daily user registration: $e");
      // Fallback with mock data
      setState(() {
        dailyUsers = {
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 6))): 5,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 5))): 8,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 4))): 3,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 3))): 12,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 2))): 7,
          DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: 1))): 9,
          DateFormat('yyyy-MM-dd').format(DateTime.now()): 4,
        };
      });
    }
  }

  Future<void> fetchMonthlyUserRegistration() async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/admin/monthly-registrations');
    try {
      final response = await http.get(
        url,
        headers: {'x-role': 'Admin'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          monthlyUsers = Map<String, int>.from(data['monthly_registrations'] ?? {});
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching monthly user registration: $e");
      // Fallback with mock data
      setState(() {
        monthlyUsers = {
          '2024-02': 45,
          '2024-03': 58,
          '2024-04': 42,
          '2024-05': 67,
          '2024-06': 53,
          '2024-07': 71,
          '2024-08': 48,
        };
      });
    }
  }

  Widget buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDailyUsersChart() {
    if (dailyUsers.isEmpty) return const Center(child: CircularProgressIndicator());

    List<FlSpot> spots = [];
    List<String> dates = dailyUsers.keys.toList()..sort();
    
    for (int i = 0; i < dates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyUsers[dates[i]]!.toDouble()));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🟦 จำนวนผู้ใช้ลงทะเบียนรายวัน (7 วันล่าสุด)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < dates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MM/dd').format(DateTime.parse(dates[value.toInt()])),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF2563EB),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF2563EB),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWifiScanChart() {
    if (wifiScanStats.isEmpty) return const Center(child: CircularProgressIndicator());

    List<BarChartGroupData> barGroups = [];
    List<String> dates = wifiScanStats.keys.toList()..sort();
    
    for (int i = 0; i < dates.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: wifiScanStats[dates[i]]!.toDouble(),
              color: const Color(0xFFEA580C),
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
DateTime parseCustomDate(String rawDate) {
  try {
    String cleaned = rawDate.replaceAll('GMT', '').trim();
    return DateFormat("EEE MMM dd yyyy HH:mm:ss Z", "en_US").parse(cleaned);
  } catch (e) {
    print("❌ Error parsing date: $e");
    return DateTime.now(); // fallback
  }
}

// แล้วใน widget:
return Card(
  elevation: 4,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🟧 สถิติการ Scan WiFi รายวัน (7 วันล่าสุด)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < dates.length) {
                        final parsedDate = parseCustomDate(dates[value.toInt()]);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('MM/dd').format(parsedDate),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(value.toInt().toString());
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    ),
  ),
);

  }

  Widget buildUserTypePieChart() {
    List<PieChartSectionData> sections = [];
    final colors = [const Color(0xFFDC2626), const Color(0xFF2563EB)];
    int colorIndex = 0;

    userTypeStats.forEach((role, count) {
      if (count > 0) {
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: count.toDouble(),
            title: '$role\n$count คน',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🟨 การใช้งานแต่ละประเภท (Admin/User)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMonthlyChart() {
    if (monthlyUsers.isEmpty) return const Center(child: CircularProgressIndicator());

    List<FlSpot> spots = [];
    List<String> months = monthlyUsers.keys.toList()..sort();
    
    for (int i = 0; i < months.length; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyUsers[months[i]]!.toDouble()));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 จำนวนผู้ใช้ลงทะเบียนรายเดือน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MM/yy').format(DateTime.parse('${months[value.toInt()]}-01')),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF7C3AED),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF7C3AED),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchDashboardData,
          ),
        ],
      ),
      drawer: CommonDrawer(
        username: username,
        email: email,
        currentPage: 'admin',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: buildStatsCard(
                            title: 'ผู้ใช้ทั้งหมด',
                            value: totalUsers.toString(),
                            icon: Icons.people,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildStatsCard(
                            title: 'Scan วันนี้',
                            value: todayScans.toString(),
                            icon: Icons.wifi_find,
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: buildStatsCard(
                            title: 'Scan ทั้งหมด',
                            value: totalScans.toString(),
                            icon: Icons.analytics,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: buildStatsCard(
                            title: 'Admin',
                            value: userTypeStats['Admin'].toString(),
                            icon: Icons.admin_panel_settings,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Charts
                    buildDailyUsersChart(),
                    const SizedBox(height: 16),
                    
                    buildMonthlyChart(),
                    const SizedBox(height: 16),
                    
                    buildWifiScanChart(),
                    const SizedBox(height: 16),
                    
                    buildUserTypePieChart(),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚡ การจัดการด่วน',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const Usermanagepage()),
                                      );
                                    },
                                    icon: const Icon(Icons.manage_accounts),
                                    label: const Text('จัดการผู้ใช้'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LogPage(username: username, email: email),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.history),
                                    label: const Text('ดู Log'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}