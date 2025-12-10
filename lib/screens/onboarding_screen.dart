import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';
import '../widgets/elephant_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasShownNotificationPopup = false;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Welcome to\nJayantslist',
      subtitle: 'India\'s Trusted Marketplace',
      description: 'Connect with thousands of buyers and sellers across India in a secure and trusted environment',
      useElephantLogo: true,
      icon: null,
    ),
    OnboardingData(
      title: 'Discover Quality\nProducts',
      subtitle: 'Browse with Confidence',
      description: 'Explore a curated selection of products from verified sellers with transparent pricing and ratings',
      useElephantLogo: false,
      icon: Icons.storefront_rounded,
    ),
    OnboardingData(
      title: 'Safe & Secure\nTransactions',
      subtitle: 'Shop with Peace of Mind',
      description: 'Your transactions and data are protected with industry-leading security and encryption',
      useElephantLogo: false,
      icon: Icons.verified_user_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) async {
    setState(() {
      _currentPage = page;
    });
    
    // Mark onboarding as completed when reaching last page
    if (page == 2) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      
      // Show notification popup on last page
      if (!_hasShownNotificationPopup) {
        _hasShownNotificationPopup = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showNotificationPermissionPopup();
          }
        });
      }
    }
  }

  void _showNotificationPermissionPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => const NotificationPermissionPopup(),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skipToLastPage() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
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
              Color(0xFFFAF7F0), // Cream
              Color(0xFFF5F1E8), // Light beige
              Color(0xFFEBE7DD), // Darker cream
            ],
          ),
        ),
        child: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: _pages[index],
                currentPage: _currentPage,
                totalPages: _pages.length,
                onNext: _nextPage,
                onSkip: _skipToLastPage,
              );
            },
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  final OnboardingData data;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    this.onSkip,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(OnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
      child: Column(
        children: [
          // Logo/Icon Section
          Expanded(
            flex: 4,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: widget.data.useElephantLogo
                      ? const ElephantLogo(size: 160)
                      : Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDDC39).withOpacity(0.2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFCDDC39).withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.data.icon,
                            size: 60,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Content Section
          Expanded(
            flex: 6,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Flexible(
                      child: Text(
                        widget.data.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      widget.data.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCDDC39),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          widget.data.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF4A4A4A),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Decorative Line
                    Container(
                      width: 50,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDDC39),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Next Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCDDC39),
                          foregroundColor: const Color(0xFF1A1A1A),
                          elevation: 8,
                          shadowColor: const Color(0xFFCDDC39).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.currentPage == 2 ? 'Get Started' : 'Continue',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Page Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == widget.currentPage ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == widget.currentPage
                                ? const Color(0xFFCDDC39)
                                : const Color(0xFF1A1A1A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Skip Button (only show on first two pages)
                    if (widget.currentPage < 2)
                      SizedBox(
                        height: 36,
                        child: TextButton(
                          onPressed: () {
                            // Find the parent _OnboardingScreenState to access the controller
                            // Or better, pass a callback for skipping
                            // But since we are inside OnboardingPage which is built by OnboardingScreen,
                            // we need access to the controller.
                            // However, the controller is in the parent state.
                            // The OnboardingPage widget doesn't have access to _pageController directly.
                            // Wait, looking at the code, OnboardingPage is a separate widget.
                            // The Skip button logic was:
                            /*
                            _pageController.animateToPage(
                              2,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );
                            */
                            // But _pageController is NOT defined in OnboardingPage.
                            // Ah, I see the issue in the provided file content.
                            // Lines 396-400 in the provided file show:
                            /*
                            _pageController.animateToPage(
                              2,
                              ...
                            */
                            // BUT _pageController is NOT a field of OnboardingPage or its State.
                            // It is a field of _OnboardingScreenState.
                            // The code I see in view_file output for OnboardingPage (lines 149+) does NOT have _pageController passed to it.
                            // Wait, looking at line 396 in the file content I read:
                            // It says `_pageController.animateToPage(...)`.
                            // But `_pageController` is NOT defined in `_OnboardingPageState`.
                            // This code shouldn't even compile if `_pageController` isn't defined.
                            // Unless... it's using a global or I missed something.
                            // Ah, I see `PageController get _pageController { return PageController(); }` at line 425!
                            // This is creating a NEW PageController every time it's accessed!
                            // That is the bug! It's not attached to anything!
                            
                            // We need to pass the main controller or a callback to skip.
                            // The `onNext` callback is passed, but we need an `onSkip` callback.
                            widget.onSkip?.call();
                          },
                          child: Text(
                            'Skip',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4A4A4A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  

}

class NotificationPermissionPopup extends StatefulWidget {
  const NotificationPermissionPopup({super.key});

  @override
  State<NotificationPermissionPopup> createState() => _NotificationPermissionPopupState();
}

class _NotificationPermissionPopupState extends State<NotificationPermissionPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleAllow() async {
    await Permission.notification.request();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleSkip() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 350),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F0),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Bell Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFCDDC39).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: 28,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Stay Updated',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                'Get notified about new offers and updates',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: const Color(0xFF4A4A4A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Allow Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _handleAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCDDC39),
                    foregroundColor: const Color(0xFF1A1A1A),
                    elevation: 4,
                    shadowColor: const Color(0xFFCDDC39).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Allow Notifications',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip Button
              TextButton(
                onPressed: _handleSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  'Maybe Later',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4A4A4A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final bool useElephantLogo;
  final IconData? icon;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.useElephantLogo,
    this.icon,
  });
}
