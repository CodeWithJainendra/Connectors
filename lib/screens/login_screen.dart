import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../widgets/elephant_logo.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController(text: '\u200b'));
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _otpRequested = false;
  bool _isPhoneValid = false;
  bool _otpComplete = false;

  String _maskedPhone() {
    final digitsOnly = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return '+${_selectedCountry.phoneCode}';
    final keep = digitsOnly.length >= 2 ? 2 : 1;
    final hiddenLen = digitsOnly.length - keep;
    final hidden = List.filled(hiddenLen, '•').join();
    final visible = digitsOnly.substring(digitsOnly.length - keep);
    return '+${_selectedCountry.phoneCode} $hidden$visible';
  }
  
  Country _selectedCountry = Country(
    phoneCode: '91',
    countryCode: 'IN',
    e164Sc: 91,
    geographic: true,
    level: 1,
    name: 'India',
    example: '9123456789',
    displayName: 'India (IN) +91',
    displayNameNoCountryCode: 'India (IN)',
    e164Key: '91-IN-0',
  );

  @override
  void initState() {
    super.initState();
    // Ensure cursor is always at the end when a field gains focus
    for (int i = 0; i < 6; i++) {
      _otpFocusNodes[i].addListener(() {
        if (_otpFocusNodes[i].hasFocus) {
          // Use a post-frame callback to ensure the frame is ready for selection update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _otpControllers[i].selection = TextSelection.fromPosition(
                TextPosition(offset: _otpControllers[i].text.length),
              );
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _humanizeError(Object error) {
    String msg = error.toString().replaceAll('Exception: ', '').trim();
    try {
      if (msg.startsWith('{') || msg.startsWith('[')) {
        final decoded = jsonDecode(msg);
        if (decoded is Map) {
          final m = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
          if (m is String && m.trim().isNotEmpty) return m.trim();
          if (decoded['errors'] is List && (decoded['errors'] as List).isNotEmpty) {
            final first = (decoded['errors'] as List).first;
            if (first is String) return first;
            if (first is Map && first['message'] is String) return first['message'];
          }
        }
        if (decoded is List && decoded.isNotEmpty) {
          final first = decoded.first;
          if (first is String) return first;
        }
      }
    } catch (_) {}

    final lower = msg.toLowerCase();
    if (lower.contains('timeout')) {
      return 'Request timed out. Please check your internet and try again.';
    }
    if (lower.contains('socketexception') || lower.contains('failed host lookup') || lower.contains('connection refused')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }
    if (lower.contains('invalid json') || lower.contains('formatexception')) {
      return 'Server error. Please try again later.';
    }
    if (lower.contains('session expired')) {
      return 'Session expired. Please sign in again.';
    }
    if (lower.contains('invalid otp') || lower.contains('otp invalid')) {
      return 'The OTP you entered is incorrect.';
    }
    if (lower.contains('otp expired')) {
      return 'The OTP has expired. Please request a new one.';
    }
    if (lower.contains('mobile') && lower.contains('required')) {
      return 'Please enter a valid mobile number.';
    }
    if (lower.contains('user not found')) {
      return 'We could not find an account for this number.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit') || lower.contains('429')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (RegExp(r'^\{.*\}$').hasMatch(msg) || RegExp(r'^\[.*\]$').hasMatch(msg)) {
      return 'Something went wrong. Please try again.';
    }
    if (msg.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return msg;
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
        });
      },
      favorite: ['IN', 'US', 'GB', 'CA', 'AU'], // Show these at the top
    );
  }

  void _requestOtp() async {
    if (_formKey.currentState!.validate()) {
      final fullPhone = _phoneController.text.trim(); // API expects 10 digit number usually, let's check. 
      // The API docs say "mobile_no": "9876543210". It doesn't mention country code.
      // However, the previous code was adding country code. 
      // Let's stick to 10 digits as per the example in docs "9876543210".
      // But wait, the user might be international. 
      // The docs example is 10 digits. The previous code was sending fullPhone with country code to localhost.
      // I will send the 10 digit number if the country is India, or maybe just the number.
      // Let's check ApiService.sendOtp implementation. It takes a string.
      // I'll send the number as entered by user (without country code if it's just 10 digits).
      // Actually, let's look at the docs again. "mobile_no": "9876543210".
      // I'll use the raw text from controller which is just digits.
      
      final mobileNo = _phoneController.text.trim();

      setState(() {
        _isLoading = true;
        _otpRequested = true;
        for (final c in _otpControllers) {
          c.text = '\u200b';
        }
        _otpComplete = false;
      });

      ApiService().sendOtp(mobileNo).then((response) async {
        if (mounted) {
          // OTP is now visible in response for testing
          if (response['otp'] != null) {
            String otp = response['otp'].toString();
            print('DEBUG OTP: $otp');
            
            // WORKAROUND: Backend rejects OTPs starting with 0
            if (otp.startsWith('0')) {
              print('⚠️ OTP starts with 0, retrying request...');
              // Wait a bit before retrying to avoid spamming
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                _requestOtp(); // Recursively call to get a new OTP
              }
              return;
            }
          }
          
          setState(() {
            _isLoading = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_humanizeError(error)),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _verifyOtp() async {
    // Strip ZWS
    final otp = _otpControllers.map((c) => c.text.replaceAll('\u200b', '')).join();
    if (otp.length != 6) {
      return;
    }

    final mobileNo = _phoneController.text.trim();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService().validateOtp(mobileNo, otp);
      
      final prefs = await SharedPreferences.getInstance();
      
      // Save user data from new response format
      if (response['user_account'] != null) {
        final user = response['user_account'];
        await prefs.setString('user_name', user['fullname']?.toString() ?? '');
        await prefs.setString('user_phone', user['mobile']?.toString() ?? mobileNo);
        
        // Save picture URL
        if (user['picture_url'] != null) {
          String pictureUrl = user['picture_url'].toString();
          if (!pictureUrl.startsWith('http')) {
            pictureUrl = 'https://www.jayantslist.com$pictureUrl';
          }
          await prefs.setString('user_picture_url', pictureUrl);
        }
        
        // Handle roles array
        if (user['roles'] != null && user['roles'] is List) {
          final roles = user['roles'] as List;
          if (roles.isNotEmpty) {
            await prefs.setString('user_role', roles.first.toString());
          }
        }
      } else {
        await prefs.setString('user_phone', mobileNo);
      }

      await prefs.setBool('is_logged_in', true);
      
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanizeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          const Center(child: ElephantLogo(size: 100)),
                          const SizedBox(height: 16),
                          Text(
                            'Jayantslist',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Welcome back!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF4A4A4A),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          if (_otpRequested)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'SMS sent to ${_maskedPhone()}',
                                      key: const ValueKey('otp-info'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        color: const Color(0xFF4A4A4A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFF1A1A1A)),
                                      onPressed: () {
                                        setState(() {
                                          _otpRequested = false;
                                          _otpComplete = false;
                                          for (final c in _otpControllers) {
                                            c.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) {
                              final slide = Tween<Offset>(begin: const Offset(0.1, 0.0), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn));
                              return FadeTransition(
                                opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                                child: SlideTransition(position: slide, child: child),
                              );
                            },

                          
                            child: _otpRequested
                                ? Row(
                                    key: const ValueKey('otp-row'),
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(6, (index) {
                                      return SizedBox(
                                        width: 48,
                                        height: 56,
                                        child: TextFormField(
                                          controller: _otpControllers[index],
                                          focusNode: _otpFocusNodes[index],
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          enableInteractiveSelection: false,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(2),
                                            FilteringTextInputFormatter.allow(RegExp(r'[\d\u200b]')),
                                          ],
                                          style: GoogleFonts.roboto(fontSize: 18, color: const Color(0xFF1A1A1A)),
                                          decoration: InputDecoration(
                                            counterText: '',
                                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.7),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.1)),
                                            ),
                                            focusedBorder: const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(Radius.circular(12)),
                                              borderSide: BorderSide(color: Color(0xFFCDDC39), width: 2),
                                            ),
                                          ),
                                          onTap: () {
                                            // Handle random tap: redirect to valid field
                                            int targetIndex = 0;
                                            for (int i = 0; i < 6; i++) {
                                              if (_otpControllers[i].text == '\u200b') {
                                                targetIndex = i;
                                                break;
                                              }
                                              if (i == 5 && _otpControllers[i].text != '\u200b') {
                                                targetIndex = 5;
                                              }
                                            }
                                            if (index != targetIndex) {
                                              _otpFocusNodes[targetIndex].requestFocus();
                                            } else {
                                              // Ensure cursor at end
                                              _otpControllers[index].selection = TextSelection.fromPosition(
                                                TextPosition(offset: _otpControllers[index].text.length),
                                              );
                                            }
                                          },
                                          onChanged: (val) {
                                            if (val.isEmpty) {
                                              // Backspace on empty field handling
                                              _otpControllers[index].text = '\u200b';
                                              _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
                                              if (index > 0) {
                                                _otpFocusNodes[index - 1].requestFocus();
                                              }
                                              return;
                                            }
                                            
                                            if (val.length > 1) {
                                              // Normal input (ZWS + digit)
                                              String clean = val.replaceAll('\u200b', '');
                                              if (clean.isNotEmpty) {
                                                String char = clean.characters.last;
                                                _otpControllers[index].text = '\u200b$char';
                                                _otpControllers[index].selection = const TextSelection.collapsed(offset: 2);
                                                
                                                if (index < 5) {
                                                  _otpFocusNodes[index + 1].requestFocus();
                                                } else {
                                                  _otpFocusNodes[index].unfocus();
                                                  // Optional: auto-verify if complete
                                                  final fullOtp = _otpControllers.map((c) => c.text.replaceAll('\u200b', '')).join();
                                                  if (fullOtp.length == 6) {
                                                    setState(() => _otpComplete = true);
                                                    _verifyOtp();
                                                  }
                                                }
                                              } else {
                                                // Reset to ZWS if somehow result is emptyish
                                                _otpControllers[index].text = '\u200b';
                                                _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
                                              }
                                            }
                                            
                                            // Update complete status
                                            final otp = _otpControllers.map((c) => c.text.replaceAll('\u200b', '')).join();
                                            setState(() {
                                              _otpComplete = otp.length == 6;
                                            });
                                          },
                                        ),
                                      );
                                    }),
                                  )
                                : Row(
                                    key: const ValueKey('phone-row'),
                                    children: [
                                      GestureDetector(
                                        onTap: _showCountryPicker,
                                        child: Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFF1A1A1A).withOpacity(0.1),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_selectedCountry.flagEmoji, style: const TextStyle(fontSize: 20)),
                                              const SizedBox(width: 6),
                                              Text(
                                                '+${_selectedCountry.phoneCode}',
                                                style: GoogleFonts.roboto(
                                                  color: const Color(0xFF1A1A1A),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.arrow_drop_down, color: Color(0xFF4A4A4A), size: 18),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: TextFormField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            style: GoogleFonts.roboto(color: const Color(0xFF1A1A1A), fontSize: 14),
                                            decoration: InputDecoration(
                                              labelText: 'Phone Number',
                                              hintText: 'Enter your phone number',
                                              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF4A4A4A), size: 20),
                                              labelStyle: GoogleFonts.roboto(color: const Color(0xFF4A4A4A), fontSize: 13),
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.7),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.1)),
                                              ),
                                              focusedBorder: const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                                borderSide: BorderSide(color: Color(0xFFCDDC39), width: 2),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                                              setState(() {
                                                _isPhoneValid = digitsOnly.length == 10;
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your phone number';
                                              }
                                              final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                                              if (digitsOnly.length != 10) {
                                                return 'Please enter a valid phone number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (_isLoading || (!_otpRequested && !_isPhoneValid) || (_otpRequested && !_otpComplete))
                                  ? null
                                  : (_otpRequested ? _verifyOtp : _requestOtp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCDDC39),
                                foregroundColor: const Color(0xFF1A1A1A),
                                elevation: 6,
                                shadowColor: const Color(0xFFCDDC39).withOpacity(0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                                      ),
                                    )
                                  : Text(
                                      _otpRequested ? 'Verify' : 'Request OTP',
                                      style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          // "Don't have an account" removed
                        ],
                      ),
                    ],
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
