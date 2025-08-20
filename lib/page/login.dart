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
      // Get device IP and check login status concurrently
      await Future.wait([
        _getDeviceIP(),
        _checkLoggedIn(),
      ]);
    } catch (e) {
      debugPrint('Error initializing login page: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingLogin = false);
      }
    }
  }

  Future<void> _getDeviceIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (mounted) {
        setState(() => _deviceIP = wifiIP ?? 'unknown');
      }
    } catch (e) {
      debugPrint('Error getting device IP: $e');
      if (mounted) {
        setState(() => _deviceIP = 'unknown');
      }
    }
  }

  Future<void> _checkLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final username = prefs.getString('username');
      final email = prefs.getString('email');
      final roles = prefs.getString('role');

      debugPrint('Login check - isLoggedIn: $isLoggedIn, username: $username, email: $email, role: $roles');

      if (isLoggedIn && username != null && email != null && roles != null) {
        // Navigate based on role
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (roles.toLowerCase() == 'admin') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanPage(username: username, email: email),
                  ),
                );
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      // Clear potentially corrupted data
      await _clearLoginData();
    }
  }

  Future<void> _clearLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('username');
      await prefs.remove('email');
      await prefs.remove('uid');
      await prefs.remove('role');
    } catch (e) {
      debugPrint('Error clearing login data: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Prevent multiple login attempts
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        _showError('กรุณากรอกข้อมูลให้ครบถ้วน');
        return;
      }

      final loginRequest = UserLoginRequest(email: email, passwords: password);

      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null || apiUrl.isEmpty) {
        _showError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
        return;
      }

      final url = Uri.parse('$apiUrl/login');
      debugPrint('Attempting login to: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(loginRequest.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('การเชื่อมต่อใช้เวลานานเกินไป');
        },
      );

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final loginResponse = loginResponseFromJson(response.body);
        
        if (loginResponse.success && loginResponse.user != null) {
          await _handleSuccessfulLogin(loginResponse.user!);
        } else {
          _showError(loginResponse.message ?? 'เข้าสู่ระบบล้มเหลว');
        }
      } else {
        // Handle different status codes
        String errorMessage = 'เข้าสู่ระบบล้มเหลว';
        
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorBody['error'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        switch (response.statusCode) {
          case 401:
            errorMessage = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
            break;
          case 404:
            errorMessage = 'ไม่พบผู้ใช้งานในระบบ';
            break;
          case 500:
            errorMessage = 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง';
            break;
        }
        
        _showError(errorMessage);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      String errorMessage = 'เกิดข้อผิดพลาด: ';
      
      if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
        errorMessage += 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('ใช้เวลานานเกินไป')) {
        errorMessage += 'การเชื่อมต่อใช้เวลานานเกินไป';
      } else {
        errorMessage += 'กรุณาลองใหม่อีกครั้ง';
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSuccessfulLogin(dynamic user) async {
    try {
      // Show CAPTCHA first
      final isHuman = await _showNumberCaptchaDialog();
      if (!isHuman) {
        _showError('กรุณาผ่านการยืนยัน CAPTCHA');
        return;
      }

      // Save user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', user.username ?? '');
      await prefs.setString('email', user.email ?? '');
      await prefs.setString('uid', user.uid?.toString() ?? '');
      await prefs.setString('role', user.roles ?? 'user');

      debugPrint('User data saved - username: ${user.username}, email: ${user.email}, role: ${user.roles}');

      // Send service logs (don't wait for completion)
      _sendServiceLogs(user.email ?? 'unknown').catchError((e) {
        debugPrint('Error sending service logs: $e');
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เข้าสู่ระบบสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate based on role
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          if ((user.roles ?? '').toLowerCase() == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminPage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ScanPage(
                  username: user.username ?? 'ไม่ทราบชื่อ', 
                  email: user.email ?? 'ไม่ทราบอีเมล'
                ),
              ),
            );
          }
        }
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

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'logs': logs}),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('Service logs sent successfully');
    } catch (e) {
      debugPrint('Failed to send service logs: $e');
      // Don't show error to user as this is not critical
    }
  }

  Future<bool> _showNumberCaptchaDialog() async {
    if (!mounted) return false;
    
    bool isHuman = false;
    
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ยืนยันว่าคุณไม่ใช่บอท',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: NumberSelectionCaptcha(
            onConfirm: () {
              isHuman = true;
              Navigator.of(dialogContext).pop(true);
            },
          ),
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
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
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
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      labelStyle: const TextStyle(fontSize: 16),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking login status
    if (_isCheckingLogin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo/Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.security,
                            size: 40,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          "เข้าสู่ระบบ",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const Text(
                          "WiFi Security Scanner",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('อีเมล', Icons.email_outlined),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกอีเมล';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                              return 'รูปแบบอีเมลไม่ถูกต้อง';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: _inputDecoration(
                            'รหัสผ่าน', 
                            Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF6B7280),
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
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
                        
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'เข้าสู่ระบบ',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Register Link
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "ยังไม่มีบัญชี? สมัครสมาชิก",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.w500,
                            ),
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