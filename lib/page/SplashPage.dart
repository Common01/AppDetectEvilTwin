import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_wifi_app/page/login.dart';
import 'package:temp_wifi_app/page/scanwifi.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> 
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.linear,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _rotateController.repeat();
    
    // Check login status after a delay
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 2500));
    await _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    debugPrint('isLoggedIn: $isLoggedIn');

    if (isLoggedIn) {
      final username = prefs.getString('username') ?? 'ไม่ทราบชื่อ';
      final email = prefs.getString('email') ?? 'ไม่ทราบอีเมล';
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                ScanPage(username: username, email: email),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                const LoginPage(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and Icon Section
              Expanded(
                flex: 3,
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _fadeAnimation,
                      _scaleAnimation,
                      _rotateAnimation,
                    ]),
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Rotating glow effect
                              Transform.rotate(
                                angle: _rotateAnimation.value * 3.14159,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Main WiFi Security Icon
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: CustomPaint(
                                  painter: WiFiSecurityIconPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // App Title and Subtitle
              Expanded(
                flex: 1,
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'WiFi Security',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ป้องกัน Evil Twin & Rogue Access Point',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          
                          // Loading indicator
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'กำลังเริ่มต้นระบบ...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for WiFi Security Icon
class WiFiSecurityIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 200; // Base design was 200x200

    // Create gradients
    final shieldGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4F46E5),
          const Color(0xFF3730A3),
        ],
      ).createShader(Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      ));

    final wifiGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF10B981),
          const Color(0xFF059669),
        ],
      ).createShader(Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      ));

    final dangerGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFEF4444),
          const Color(0xFFDC2626),
        ],
      ).createShader(Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      ));

    // Background circle with shadow
    final backgroundPaint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    canvas.drawCircle(center, 95 * scale, backgroundPaint);

    // Main shield shape
    final shieldPath = Path();
    shieldPath.moveTo(center.dx, center.dy - 70 * scale);
    shieldPath.lineTo(center.dx + 40 * scale, center.dy - 50 * scale);
    shieldPath.lineTo(center.dx + 40 * scale, center.dy + 10 * scale);
    shieldPath.quadraticBezierTo(
      center.dx + 40 * scale, center.dy + 40 * scale,
      center.dx, center.dy + 60 * scale,
    );
    shieldPath.quadraticBezierTo(
      center.dx - 40 * scale, center.dy + 40 * scale,
      center.dx - 40 * scale, center.dy + 10 * scale,
    );
    shieldPath.lineTo(center.dx - 40 * scale, center.dy - 50 * scale);
    shieldPath.close();

    canvas.drawPath(shieldPath, shieldGradient);

    // Shield border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawPath(shieldPath, borderPaint);

    // WiFi waves (protected)
    final wifiPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3 * scale;

    // Wave 1
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 20 * scale),
        width: 40 * scale,
        height: 40 * scale,
      ),
      3.14159 + 0.5,
      3.14159 - 1.0,
      false,
      wifiPaint..strokeWidth = 3 * scale,
    );

    // Wave 2
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 20 * scale),
        width: 30 * scale,
        height: 30 * scale,
      ),
      3.14159 + 0.4,
      3.14159 - 0.8,
      false,
      wifiPaint..strokeWidth = 2.5 * scale,
    );

    // Wave 3
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 20 * scale),
        width: 20 * scale,
        height: 20 * scale,
      ),
      3.14159 + 0.3,
      3.14159 - 0.6,
      false,
      wifiPaint..strokeWidth = 2 * scale,
    );

    // Center dot
    final centerDotPaint = Paint()
      ..color = const Color(0xFF10B981);
    canvas.drawCircle(
      Offset(center.dx, center.dy - 8 * scale),
      3 * scale,
      centerDotPaint,
    );

    // Checkmark in shield
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path();
    checkPath.moveTo(center.dx - 15 * scale, center.dy - 5 * scale);
    checkPath.lineTo(center.dx - 5 * scale, center.dy + 5 * scale);
    checkPath.lineTo(center.dx + 15 * scale, center.dy - 15 * scale);
    
    canvas.drawPath(checkPath, checkPaint);

    // Blocked evil twin and rogue AP (simplified)
    final dangerPaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;

    // Evil twin (left) - X mark
    canvas.drawLine(
      Offset(center.dx - 55 * scale, center.dy - 55 * scale),
      Offset(center.dx - 43 * scale, center.dy - 43 * scale),
      dangerPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 43 * scale, center.dy - 55 * scale),
      Offset(center.dx - 55 * scale, center.dy - 43 * scale),
      dangerPaint,
    );

    // Rogue AP (right) - X mark
    canvas.drawLine(
      Offset(center.dx + 45 * scale, center.dy - 55 * scale),
      Offset(center.dx + 57 * scale, center.dy - 43 * scale),
      dangerPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 57 * scale, center.dy - 55 * scale),
      Offset(center.dx + 45 * scale, center.dy - 43 * scale),
      dangerPaint,
    );

    // Lock symbol at bottom of shield
    final lockPaint = Paint()
      ..color = Colors.white.withOpacity(0.9);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 32 * scale),
          width: 8 * scale,
          height: 6 * scale,
        ),
        Radius.circular(1 * scale),
      ),
      lockPaint,
    );

    // Lock arc
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 30 * scale),
        width: 6 * scale,
        height: 6 * scale,
      ),
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}