import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Onboarding removed - users go directly to login
import 'login_screen.dart';
import 'home_screen.dart';
import '../widgets/elephant_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();
    _clearOldTokens(); // Clear old API tokens
    _prefetchCategories();
    _prefetchArtisans();
    
    // Check onboarding status and navigate after 4 seconds
    Timer(const Duration(seconds: 4), () {
      _checkOnboardingStatus();
    });
  }

  Future<void> _clearOldTokens() async {
    // Clear old auth tokens from previous API to prevent issues
    final prefs = await SharedPreferences.getInstance();
    final hasOldToken = prefs.getString('accessToken') != null || 
                       prefs.getString('refreshToken') != null;
    if (hasOldToken) {
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('is_logged_in'); // Force re-login
    }
  }

  Future<void> _checkOnboardingStatus() async {
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final hasAuthToken = prefs.getString('auth_token') != null;
    
    if (!mounted) return;
    
    // Determine which screen to show
    Widget nextScreen;
    
    if (isLoggedIn && hasAuthToken) {
      // User is logged in with valid token, go to home
      nextScreen = const HomeScreen();
    } else {
      // Not logged in, go directly to login (skip onboarding)
      nextScreen = const LoginScreen();
    }
    
    // Navigate to appropriate screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _prefetchCategories() async {
    try {
      final resp = await http.get(
        Uri.parse('https://www.jayantslist.com/api/categories'),
        headers: {'User-Agent': 'JayantsList/1.0'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final List<dynamic> list = data['data'] ?? [];
        final names = list
            .map((e) => e['serviceCategoryName']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_categories', json.encode(names));
      }
    } catch (_) {}
  }

  Future<void> _prefetchArtisans() async {
    try {
      final firstResp = await http.get(
        Uri.parse('https://www.jayantslist.com/api/artisans?page=1&limit=100'),
        headers: {'User-Agent': 'JayantsList/1.0'},
      );
      if (firstResp.statusCode != 200) return;
      final firstData = json.decode(firstResp.body);
      final int totalPages = (firstData['totalPages'] ?? 1) as int;
      final List<dynamic> firstPage = firstData['data'] ?? [];
      List<dynamic> all = List<dynamic>.from(firstPage);
      final futures = <Future<http.Response>>[];
      for (int p = 2; p <= totalPages; p++) {
        futures.add(http.get(
          Uri.parse('https://www.jayantslist.com/api/artisans?page=$p&limit=100'),
          headers: {'User-Agent': 'JayantsList/1.0'},
        ));
      }
      final results = await Future.wait(futures);
      for (final r in results) {
        if (r.statusCode == 200) {
          final d = json.decode(r.body);
          final List<dynamic> page = d['data'] ?? [];
          all.addAll(page);
        }
      }
      final minimal = all.map((e) => {
            'name': e['artisan_name'],
            'category': e['service_category']?['serviceCategoryName'],
            'lat': e['latitude'],
            'lon': e['longitude'],
          }).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_artisans', json.encode(minimal));
      await prefs.setInt('cached_artisans_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
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
              Color(0xFFFAF7F0), // Cream
              Color(0xFFF5F1E8), // Light beige
              Color(0xFFEBE7DD), // Darker cream
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Elephant Logo
                  const ElephantLogo(size: 140),
                  
                  const SizedBox(height: 28),
                  
                  // App Name
                  Text(
                    'Jayantslist',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Color(0xFFCDDC39).withOpacity(0.3),
                          offset: Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Tagline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'India\'s trusted marketplace for sellers and buyers',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4A4A4A),
                        letterSpacing: 0.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 3),
                  
                  // Version Number
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4A4A4A),
                        letterSpacing: 0.5,
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
  }
}
