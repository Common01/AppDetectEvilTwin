import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:temp_wifi_app/model/request/userRegisterRequest.dart';
import 'package:temp_wifi_app/page/login.dart';
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

  // Form validation states for better UX
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
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
      if (apiUrl?.isEmpty ?? true) {
        _showError('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
        return;
      }

      final registerUrl = Uri.parse('$apiUrl/register');
      final registerRes = await http.post(
        registerUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: userRegisterRequestToJson(user),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('การเชื่อมต่อใช้เวลานานเกินไป'),
      );

      if (registerRes.statusCode == 200 || registerRes.statusCode == 201) {
        if (mounted) {
          _showSuccessMessage();
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        }
      } else {
        _handleErrorResponse(registerRes);
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _handleException(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleErrorResponse(http.Response response) {
    String errorMessage = 'สมัครสมาชิกล้มเหลว';
    
    try {
      final errorBody = jsonDecode(response.body);
      errorMessage = errorBody['message'] ?? errorBody['error'] ?? errorMessage;
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        errorMessage = 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
        break;
      case 409:
        errorMessage = 'อีเมลหรือชื่อผู้ใช้นี้ถูกใช้แล้ว';
        break;
      case 422:
        errorMessage = 'ข้อมูลไม่ถูกต้องตามรูปแบบที่กำหนด';
        break;
      case 500:
        errorMessage = 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง';
        break;
    }
    
    _showError(errorMessage);
  }

  void _handleException(dynamic e) {
    String errorMessage = 'เกิดข้อผิดพลาด: ';
    
    if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
      errorMessage += 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
    } else if (e.toString().contains('TimeoutException') || e.toString().contains('ใช้เวลานานเกินไป')) {
      errorMessage += 'การเชื่อมต่อใช้เวลานานเกินไป';
    } else {
      errorMessage += 'กรุณาลองใหม่อีกครั้ง';
    }
    
    _showError(errorMessage);
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'ปิด',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  String? _validateUsername(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'กรุณากรอกชื่อผู้ใช้';
    }
    if (value!.trim().length < 3) {
      return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
    }
    if (value.trim().length > 20) {
      return 'ชื่อผู้ใช้ต้องไม่เกิน 20 ตัวอักษร';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'ชื่อผู้ใช้ใช้ได้เฉพาะตัวอักษร ตัวเลข และ _';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'กรุณากรอกอีเมล';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!.trim())) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'กรุณากรอกรหัสผ่าน';
    }
    if (value!.trim().length < 6) {
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }
    if (value.trim().length > 50) {
      return 'รหัสผ่านต้องไม่เกิน 50 ตัวอักษร';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'กรุณายืนยันรหัสผ่าน';
    }
    if (value!.trim() != _passwordController.text.trim()) {
      return 'รหัสผ่านไม่ตรงกัน';
    }
    return null;
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon, String? errorText}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
      suffixIcon: suffixIcon,
      labelText: label,
      errorText: errorText,
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
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
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth > 600;
              final maxWidth = isTablet ? 500.0 : double.infinity;
              final padding = isTablet ? 48.0 : 24.0;
              
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: maxWidth,
                      padding: EdgeInsets.all(isTablet ? 40 : 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            Container(
                              width: isTablet ? 100 : 80,
                              height: isTablet ? 100 : 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.person_add_alt_1,
                                size: isTablet ? 50 : 40,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            SizedBox(height: isTablet ? 32 : 24),
                            
                            // Title
                            Text(
                              "สมัครสมาชิก",
                              style: TextStyle(
                                fontSize: isTablet ? 32 : 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              "WiFi Security Scanner",
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: isTablet ? 40 : 32),
                            
                            // Username Field
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                'ชื่อผู้ใช้', 
                                Icons.person_outline,
                                errorText: _usernameError,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _usernameError = _validateUsername(value);
                                });
                              },
                              validator: _validateUsername,
                            ),
                            SizedBox(height: isTablet ? 24 : 20),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                'อีเมล', 
                                Icons.email_outlined,
                                errorText: _emailError,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _emailError = _validateEmail(value);
                                });
                              },
                              validator: _validateEmail,
                            ),
                            SizedBox(height: isTablet ? 24 : 20),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                'รหัสผ่าน', 
                                Icons.lock_outline,
                                errorText: _passwordError,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _passwordError = _validatePassword(value);
                                  // Re-validate confirm password if it was already filled
                                  if (_confirmPasswordController.text.isNotEmpty) {
                                    _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
                                  }
                                });
                              },
                              validator: _validatePassword,
                            ),
                            SizedBox(height: isTablet ? 24 : 20),

                            // Confirm Password Field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _register(),
                              decoration: _inputDecoration(
                                'ยืนยันรหัสผ่าน', 
                                Icons.lock_outline,
                                errorText: _confirmPasswordError,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _confirmPasswordError = _validateConfirmPassword(value);
                                });
                              },
                              validator: _validateConfirmPassword,
                            ),
                            SizedBox(height: isTablet ? 40 : 32),
                            
                            // Register Button
                            SizedBox(
                              width: double.infinity,
                              height: isTablet ? 56 : 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  disabledBackgroundColor: Colors.grey.shade400,
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
                                    : Text(
                                        'สมัครสมาชิก',
                                        style: TextStyle(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: isTablet ? 32 : 24),
                            
                            // Login Link
                            TextButton(
                              onPressed: _isLoading 
                                  ? null 
                                  : () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LoginPage()),
                                    ),
                              child: Text(
                                "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ",
                                style: TextStyle(
                                  fontSize: isTablet ? 18 : 16,
                                  color: const Color(0xFF4F46E5),
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
              );
            },
          ),
        ),
      ),
    );
  }
}