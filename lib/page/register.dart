import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_wifi_app/model/request/userRegisterRequest.dart';
import 'package:temp_wifi_app/page/login.dart';
import 'package:temp_wifi_app/model/response/userRegisterResponse.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent multiple register attempts
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // Validate inputs
      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        _showError('กรุณากรอกข้อมูลให้ครบถ้วน');
        return;
      }

      final user = UserRegisterRequest(
        username: username,
        email: email,
        passwords: password,
      );

      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null || apiUrl.isEmpty) {
        _showError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
        return;
      }

      final registerUrl = Uri.parse('$apiUrl/register');
      debugPrint('Attempting registration to: $registerUrl');

      final registerRes = await http.post(
        registerUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: userRegisterRequestToJson(user),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('การเชื่อมต่อใช้เวลานานเกินไป');
        },
      );

      debugPrint('Registration response status: ${registerRes.statusCode}');
      debugPrint('Registration response body: ${registerRes.body}');

      if (registerRes.statusCode == 200 || registerRes.statusCode == 201) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate to login page after delay
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        }
      } else {
        // Handle different status codes
        String errorMessage = 'สมัครสมาชิกล้มเหลว';
        
        try {
          final errorBody = jsonDecode(registerRes.body);
          errorMessage = errorBody['message'] ?? errorBody['error'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        switch (registerRes.statusCode) {
          case 400:
            errorMessage = 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
            break;
          case 409:
            errorMessage = 'อีเมลหรือชื่อผู้ใช้นี้ถูกใช้แล้ว';
            break;
          case 500:
            errorMessage = 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง';
            break;
        }
        
        _showError(errorMessage);
      }
    } catch (e) {
      debugPrint('Registration error: $e');
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
  Widget build(BuildContext context) {
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
                            Icons.person_add_alt_1,
                            size: 40,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          "สมัครสมาชิก",
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
                        
                        // Username Field
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('ชื่อผู้ใช้', Icons.person_outline),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกชื่อผู้ใช้';
                            }
                            if (value.trim().length < 3) {
                              return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                              return 'ชื่อผู้ใช้ใช้ได้เฉพาะตัวอักษร ตัวเลข และ _';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

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
                          textInputAction: TextInputAction.next,
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
                        const SizedBox(height: 20),

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          decoration: _inputDecoration(
                            'ยืนยันรหัสผ่าน', 
                            Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF6B7280),
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณายืนยันรหัสผ่าน';
                            }
                            if (value.trim() != _passwordController.text.trim()) {
                              return 'รหัสผ่านไม่ตรงกัน';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        
                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
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
                                    'สมัครสมาชิก',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Login Link
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ",
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