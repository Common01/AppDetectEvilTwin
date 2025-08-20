import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_wifi_app/model/response/user_response_model.dart';
import 'package:temp_wifi_app/model/request/update_user_request.dart';
import 'CommonDrawer.dart';

class Usermanagepage extends StatefulWidget {
  const Usermanagepage({super.key});

  @override
  State<Usermanagepage> createState() => _UsermanagepageState();
}

class _UsermanagepageState extends State<Usermanagepage> {
  List<UserResponseModel> users = [];
  String searchQuery = '';
  bool isLoading = true;
  String username = '';
  String email = '';

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    fetchUsers();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      email = prefs.getString('email') ?? '';
    });
  }

  Future<void> fetchUsers() async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/users');
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        url,
        headers: {'x-role': 'Admin'},
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<UserResponseModel> loadedUsers = (jsonData as List)
            .map((json) => UserResponseModel.fromJson(json))
            .toList();
        setState(() {
          users = loadedUsers;
          isLoading = false;
        });
      } else {
        throw Exception('โหลดข้อมูลผู้ใช้ล้มเหลว');
      }
    } catch (e) {
      debugPrint("❌ Error fetching users: $e");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้')),
      );
    }
  }

  Future<void> updateRole(int uid, String newRole) async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/users/$uid');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'Admin',
        },
        body: jsonEncode(UpdateUserRequest(roles: newRole).toJson()),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตสิทธิ์ผู้ใช้สำเร็จ')),
        );
        fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตสิทธิ์ล้มเหลว: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating user role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปเดต')),
      );
    }
  }

  Future<void> deleteUser(int uid) async {
    final apiUrl = dotenv.env['API_URL'];
    final url = Uri.parse('$apiUrl/users/$uid');
    try {
      final response = await http.delete(
        url,
        headers: {'x-role': 'Admin'},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบผู้ใช้สำเร็จ')),
        );
        fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบผู้ใช้ล้มเหลว: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการลบผู้ใช้')),
      );
    }
  }

  Future<bool?> confirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ตกลง')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = users
        .where((user) =>
            user.username.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการผู้ใช้งาน'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      drawer: CommonDrawer(
        username: username,
        email: email,
        currentPage: 'user_manage',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'ค้นหาผู้ใช้',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => searchQuery = value),
                  ),
                ),
                Expanded(
                  child: filteredUsers.isEmpty
                      ? const Center(
                          child: Text(
                            'ไม่พบผู้ใช้ที่ค้นหา',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: ListTile(
                                title: Text(user.username),
                                subtitle:
                                    Text('${user.email} (${user.roles})'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButton<String>(
                                      value: user.roles,
                                      underline: const SizedBox(),
                                      borderRadius: BorderRadius.circular(8),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'User',
                                            child: Text('User')),
                                        DropdownMenuItem(
                                            value: 'Admin',
                                            child: Text('Admin')),
                                      ],
                                      onChanged: (value) async {
                                        if (value != null &&
                                            value != user.roles) {
                                          final confirmed = await confirmDialog(
                                            'ยืนยันการเปลี่ยนบทบาท',
                                            'ต้องการเปลี่ยนบทบาทของผู้ใช้ ${user.username} เป็น $value หรือไม่?',
                                          );
                                          if (confirmed == true) {
                                            updateRole(user.uid, value);
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () async {
                                        final confirmed = await confirmDialog(
                                          'ยืนยันการลบผู้ใช้',
                                          'ต้องการลบผู้ใช้ ${user.username} หรือไม่?',
                                        );
                                        if (confirmed == true) {
                                          deleteUser(user.uid);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
