import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:temp_wifi_app/page/admin.dart';
import 'package:temp_wifi_app/page/register.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';
import 'package:temp_wifi_app/model/response/userLoginResponse.dart';
import 'package:temp_wifi_app/widget/number_selection_captcha.dart';
import 'package:temp_wifi_app/model/request/userLoginRequest.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _deviceIP;
  bool _isCheckingLogin = true;

  @override
  void initState() {
    super.initState();
    _initializeLoginPage();
  }

  Future<void> _initializeLoginPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ล้างสถานะ login เดิม เพื่อบังคับ login ใหม่เสมอ
      await prefs.setBool('isLoggedIn', false);

      await _getDeviceIP();
    } catch (e) {
      debugPrint('Error initializing login page: $e');
    } finally {
      if (mounted) setState(() => _isCheckingLogin = false);
    }
  }

  Future<void> _getDeviceIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (mounted) setState(() => _deviceIP = wifiIP ?? 'unknown');
    } catch (e) {
      debugPrint('Error getting device IP: $e');
      if (mounted) setState(() => _deviceIP = 'unknown');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final loginRequest = UserLoginRequest(email: email, passwords: password);
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null || apiUrl.isEmpty) {
        _showError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
        return;
      }

      final url = Uri.parse('$apiUrl/login');
      debugPrint('Attempting login to: $url');

      final response = await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode(loginRequest.toJson()))
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Timeout');
      });

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final loginResponse = loginResponseFromJson(response.body);
        if (loginResponse.success && loginResponse.user != null) {
          await _handleSuccessfulLogin(loginResponse.user!);
          return;
        } else {
          _showError(loginResponse.message ?? 'เข้าสู่ระบบล้มเหลว');
        }
      } else {
        debugPrint('❗ Server login failed: ${response.body}');
        await _attemptOfflineLogin(email, password);
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      await _attemptOfflineLogin(email, password);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _attemptOfflineLogin(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineUsersJson = prefs.getString('offline_users');

      debugPrint('Attempting offline login...');
      if (offlineUsersJson != null) {
        final Map<String, dynamic> userMap = jsonDecode(offlineUsersJson);
        final userData = userMap[email];
        debugPrint('Offline data for $email: $userData');

        if (userData != null && userData['password'] == password) {
          debugPrint('✅ Offline login success');

          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('username', userData['username']);
          await prefs.setString('email', userData['email']);
          await prefs.setString('uid', userData['uid']);
          await prefs.setString('role', userData['role']);

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => userData['role'].toLowerCase() == 'admin'
                  ? const AdminPage()
                  : ScanPage(
                      username: userData['username'],
                      email: userData['email'],
                    ),
            ),
          );
          return;
        } else {
          _showError('ไม่สามารถเข้าสู่ระบบแบบออฟไลน์ได้');
        }
      } else {
        _showError('ไม่พบข้อมูลในเครื่อง กรุณาเข้าสู่ระบบโดยเชื่อมต่อ');
      }
    } catch (e) {
      debugPrint('❌ Offline login failed: $e');
      _showError('เข้าสู่ระบบล้มเหลว');
    }
  }

  Future<void> _handleSuccessfulLogin(dynamic user) async {
    try {
      final isHuman = await _showNumberCaptchaDialog();
      if (!isHuman) {
        _showError('กรุณาผ่านการยืนยัน CAPTCHA');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', user.username ?? '');
      await prefs.setString('email', user.email ?? '');
      await prefs.setString('uid', user.uid?.toString() ?? '');
      await prefs.setString('role', user.roles ?? 'user');
      await prefs.setString('password', _passwordController.text);

      final offlineUsers = prefs.getString('offline_users') ?? '{}';
      final Map<String, dynamic> userMap = jsonDecode(offlineUsers);
      userMap[user.email ?? ''] = {
        'email': user.email,
        'password': _passwordController.text,
        'username': user.username,
        'uid': user.uid?.toString(),
        'role': user.roles ?? 'user',
      };
      await prefs.setString('offline_users', jsonEncode(userMap));

      debugPrint('💾 Cached offline user: ${user.email}');

      _sendServiceLogs(user.email ?? 'unknown');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เข้าสู่ระบบสำเร็จ'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      if ((user.roles ?? '').toLowerCase() == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const AdminPage()));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => ScanPage(
                    username: user.username ?? 'ไม่ทราบชื่อ',
                    email: user.email ?? 'ไม่ทราบอีเมล')));
      }
    } catch (e) {
      debugPrint('Error handling successful login: $e');
      _showError('เกิดข้อผิดพลาดในการบันทึกข้อมูล');
    }
  }

  Future<void> _sendServiceLogs(String email) async {
    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null || apiUrl.isEmpty) return;
      final url = Uri.parse('$apiUrl/service-logs');
      final logs = [
        {
          'event': 'login',
          'email': email,
          'ip': _deviceIP ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
          'user_agent': 'Flutter App',
        }
      ];
      await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'logs': logs}))
          .timeout(const Duration(seconds: 10));

      debugPrint('Service logs sent successfully');
    } catch (e) {
      debugPrint('Failed to send service logs: $e');
    }
  }

  Future<bool> _showNumberCaptchaDialog() async {
    if (!mounted) return false;
    bool isHuman = false;
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'ยืนยันว่าคุณไม่ใช่บอท',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: NumberSelectionCaptcha(onConfirm: () {
            isHuman = true;
            Navigator.of(dialogContext).pop(true);
          }),
          actions: [
            TextButton(
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.red)),
              onPressed: () {
                isHuman = false;
                Navigator.of(dialogContext).pop(false);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing CAPTCHA dialog: $e');
      isHuman = false;
    }
    return isHuman;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'ปิด',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon,
          {Widget? suffixIcon}) =>
      InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
        suffixIcon: suffixIcon,
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF4F46E5).withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF4F46E5), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        labelStyle: const TextStyle(fontSize: 16),
      );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLogin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(
                            Icons.security,
                            size: 40,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "เข้าสู่ระบบ",
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937)),
                        ),
                        const Text(
                          "WiFi Security Scanner",
                          style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: _inputDecoration('อีเมล', Icons.email_outlined),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกอีเมล';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value.trim())) {
                              return 'รูปแบบอีเมลไม่ถูกต้อง';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: _inputDecoration(
                              'รหัสผ่าน', Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF6B7280),
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              )),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกรหัสผ่าน';
                            }
                            if (value.trim().length < 6) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'เข้าสู่ระบบ',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const RegisterPage()),
                                  ),
                          child: const Text(
                            "ยังไม่มีบัญชี? สมัครสมาชิก",
                            style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
