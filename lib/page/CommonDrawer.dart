import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_wifi_app/page/UserManagePage.dart';
import 'package:temp_wifi_app/page/admin.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';
import 'package:temp_wifi_app/page/LogPage.dart';
import 'package:temp_wifi_app/page/StatPage.dart';
import 'package:temp_wifi_app/page/login.dart';

class CommonDrawer extends StatefulWidget {
  final String username;
  final String email;
  final String currentPage;

  const CommonDrawer({
    super.key,
    required this.username,
    required this.email,
    required this.currentPage,
  });

  @override
  State<CommonDrawer> createState() => _CommonDrawerState();
}

class _CommonDrawerState extends State<CommonDrawer> {
  String? userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userRole = prefs.getString('role');
      });
    } catch (e) {
      debugPrint('Error loading user role: $e');
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = userRole?.toLowerCase() == 'admin';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person, 
                size: 40, 
                color: isAdmin ? const Color(0xFFDC2626) : const Color(0xFF4F46E5)
              ),
            ),
            accountName: Text(
              widget.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: Text(widget.email),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAdmin
                    ? [
                        const Color(0xFFDC2626),
                        const Color(0xFFB91C1C),
                      ]
                    : [
                        const Color(0xFF667eea),
                        const Color(0xFF764ba2),
                      ],
              ),
            ),
          ),
          
          // Admin-only menu items
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.dashboard, color: Color(0xFFDC2626)),
              title: const Text('Admin Dashboard'),
              selected: widget.currentPage == 'admin',
              selectedTileColor: const Color(0xFFDC2626).withOpacity(0.1),
              onTap: () {
                if (widget.currentPage != 'admin') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPage()),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
          
          // Common menu items for both Admin and User
          ListTile(
            leading: const Icon(Icons.wifi, color: Color(0xFF4F46E5)),
            title: const Text('สแกน Wi-Fi'),
            selected: widget.currentPage == 'scan',
            selectedTileColor: const Color(0xFF4F46E5).withOpacity(0.1),
            onTap: () {
              if (widget.currentPage != 'scan') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanPage(username: widget.username, email: widget.email),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF4F46E5)),
            title: const Text('Log Wi-Fi'),
            selected: widget.currentPage == 'log',
            selectedTileColor: const Color(0xFF4F46E5).withOpacity(0.1),
            onTap: () {
              if (widget.currentPage != 'log') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LogPage(username: widget.username, email: widget.email),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Color(0xFF4F46E5)),
            title: const Text('Stat Wi-Fi'),
            selected: widget.currentPage == 'stat',
            selectedTileColor: const Color(0xFF4F46E5).withOpacity(0.1),
            onTap: () {
              if (widget.currentPage != 'stat') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Statpage(username: widget.username, email: widget.email),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          
          // Admin-only menu items
          if (isAdmin) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts, color: Color(0xFFDC2626)),
              title: const Text('จัดการผู้ใช้งาน'),
              selected: widget.currentPage == 'user_manage',
              selectedTileColor: const Color(0xFFDC2626).withOpacity(0.1),
              onTap: () {
                if (widget.currentPage != 'user_manage') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Usermanagepage()),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
          
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
}