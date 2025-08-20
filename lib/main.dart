import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:temp_wifi_app/page/SplashPage.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: "assets/.env");
    print('✅ Environment loaded: ${dotenv.env['API_URL']}');
  } catch (e) {
    print('⚠️  Could not load .env file: $e');
  }
  
  // Set preferred orientations (optional)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiFi Security Scanner',
      debugShowCheckedModeBanner: false,
      
      // App theme
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        
        // Color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        
        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        // Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        
        // Text theme
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
          ),
        ),
        
        // Card theme
        cardTheme: const CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      
      // Dark theme (optional)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
      ),
      
      // Start with splash page
      home: const SplashPage(),
      
      // Route configuration (optional)
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const SplashPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const SplashPage(),
            );
        }
      },
    );
  }
}