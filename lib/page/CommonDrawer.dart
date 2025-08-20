import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_wifi_app/page/UserManagePage.dart';
import 'package:temp_wifi_app/page/admin.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';
import 'package:temp_wifi_app/page/LogPage.dart';
import 'package:temp_wifi_app/page/StatPage.dart';
import 'package:temp_wifi_app/page/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert'; // สำหรับ Base64

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
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadUserRoleAndImage();
  }

  // ฟังก์ชันอัปโหลด + เซฟ Base64 ตาม email
  Future<void> _pickAndUploadImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);

  if (picked != null) {
    File image = File(picked.path);
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('${dotenv.env['API_URL']}/upload_profile');
    final request = http.MultipartRequest('POST', uri);
    request.fields['email'] = widget.email;
    request.files.add(await http.MultipartFile.fromPath('profile_image', image.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_base64_${widget.email}', base64Image);

      setState(() {
        profileImageUrl = base64Image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลดรูปสำเร็จ'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปโหลดรูปล้มเหลว: ${response.statusCode}\n$responseBody'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


//ฟังก์ชันโหลด role + รูปภาพแยกตาม email
  Future<void> _loadUserRoleAndImage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final email = widget.email;
    final base64Key = 'profile_image_base64_$email';
    setState(() {
      userRole = prefs.getString('role');
      profileImageUrl = prefs.getString(base64Key);
    });
  } catch (e) {
    debugPrint('❌ Error loading user data: $e');
  }
}


  // โหลด role และรูปภาพจาก SharedPreferences
  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userRole = prefs.getString('role');
        profileImageUrl = prefs.getString('profile_image_base64'); // โหลด Base64
      });
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }
Future<void> _logout() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // ลบเฉพาะค่าที่เกี่ยวกับ session
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('role');
    // **ไม่ลบรูป profile**

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  } catch (e) {
    debugPrint('❌ Error during logout: $e');
  }
}

  // ฟังก์ชันแยกสร้าง widget รูปโปรไฟล์ รองรับทั้ง Base64 และ URL
  Widget buildProfileImage(bool isAdmin) {
    if (profileImageUrl == null) {
      // ไม่มีรูป
      return Icon(
        isAdmin ? Icons.admin_panel_settings : Icons.person,
        size: 40,
        color: isAdmin ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
      );
    }

    if (profileImageUrl!.startsWith('http')) {
      // เป็น URL รูปภาพ
      return Image.network(
        profileImageUrl!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          isAdmin ? Icons.admin_panel_settings : Icons.person,
          size: 40,
          color: isAdmin ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
        ),
      );
    } else {
      // สมมติว่าเป็น Base64
      try {
        return Image.memory(
          base64Decode(profileImageUrl!),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        );
      } catch (e) {
        // ถ้า decode ไม่ได้ fallback เป็น icon
        return Icon(
          isAdmin ? Icons.admin_panel_settings : Icons.person,
          size: 40,
          color: isAdmin ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = userRole?.toLowerCase() == 'admin';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: GestureDetector(
              onTap: _pickAndUploadImage,
              child: ClipOval(
                child: buildProfileImage(isAdmin),
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
