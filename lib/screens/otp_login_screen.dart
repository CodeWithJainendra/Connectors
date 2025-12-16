import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _phoneController = TextEditingController();
  // Using Zero Width Space (\u200b) to detect backspace on empty fields
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController(text: '\u200b'));
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _debugOtp;
  String? _token;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _otpFocusNodes[i].addListener(() {
        if (_otpFocusNodes[i].hasFocus) {
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
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    print('UI: _sendOtp called with phone: "$phone"');
    
    if (phone.isEmpty) {
      print('UI: Phone is empty');
      setState(() => _error = 'Please enter your phone number');
      return;
    }
    if (phone.length < 10) {
      print('UI: Phone is too short (${phone.length} digits)');
      setState(() => _error = 'Please enter a valid phone number (10 digits)');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('UI: Starting _sendOtp for $phone');

    try {
      print('UI: Calling ApiService.sendOtp with 30s timeout');
      // Add timeout to prevent infinite loading
      await ApiService().sendOtp(phone).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('UI: API call timed out after 30 seconds');
          throw Exception('Request timed out. Please check your internet connection.');
        },
      );
      print('UI: ApiService.sendOtp returned success');

      if (mounted) {
        setState(() {
          _isOtpSent = true;
          _isLoading = false;
          _debugOtp = null; 
        });
        print('UI: State updated - _isOtpSent = true, _isLoading = false');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent successfully', style: GoogleFonts.roboto()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else {
        print('UI: Widget not mounted after success');
      }
    } catch (e) {
      print('UI: Error in _sendOtp: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        print('UI: Error state updated - _isLoading = false');
      }
    } finally {
      print('UI: Finally block - ensuring loading is false');
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        print('UI: Force stopped loading in finally block');
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    // Remove the zero width space from the OTP string
    final otp = _otpControllers.map((c) => c.text.replaceAll('\u200b', '')).join();
    
    print('UI: _verifyOtp called with phone: "$phone", otp length: ${otp.length}');
    
    if (otp.isEmpty || otp.length != 6) {
      setState(() => _error = 'Please enter 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('UI: Verifying OTP...');


    try {
      print('UI: Calling ApiService.validateOtp with 30s timeout');
      final response = await ApiService().validateOtp(phone, otp).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('UI: OTP verification timed out after 30 seconds');
          throw Exception('Request timed out. Please check your internet connection.');
        },
      );
      print('UI: OTP verification successful');
      
      // Token is already saved by ApiService
      // We might want to save user_phone too if needed elsewhere
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      
      if (!mounted) return;
      
      // Extract token for the next screen if it needs it, though it should probably use ApiService too.
      // The previous code passed 'token' to SellerRegistrationScreen.
      final token = response['data']['accessToken'];

      setState(() => _isLoading = false); // Stop loading before navigation
      print('UI: Navigating to HomeScreen');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (e) {
      print('UI: Error in _verifyOtp: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        print('UI: Error state updated - _isLoading = false');
      }
    } finally {
      print('UI: Finally block - ensuring loading is false');
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        print('UI: Force stopped loading in finally block');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isOtpSent ? 'Enter OTP' : 'Enter Phone Number (Debug)',
          style: GoogleFonts.roboto(color: const Color(0xFF1A1A1A)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (_isOtpSent)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SMS sent to ',
                      style: GoogleFonts.roboto(fontSize: 16, color: const Color(0xFF4A4A4A)),
                    ),
                    Text(
                      _phoneController.text,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: const Color(0xFF1A1A1A),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1A1A1A)),
                      onPressed: () {
                        setState(() {
                          _isOtpSent = false;
                          for (var c in _otpControllers) {
                            c.text = '\u200b';
                          }
                          _isLoading = false; // Ensure loading is off
                        });
                      },
                    ),
                  ],
                )
              else
                Text(
                  'Enter your phone number to continue',
                  style: GoogleFonts.roboto(fontSize: 16, color: const Color(0xFF4A4A4A)),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 32),
              if (!_isOtpSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: GoogleFonts.roboto(color: const Color(0xFF9E9E9E)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCDDC39)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCDDC39)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFFCDDC39)),
                  ),
                  style: GoogleFonts.roboto(),
                ),
                const SizedBox(height: 24),
                if (_debugOtp != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDDC39).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Debug OTP: $_debugOtp',
                      style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                const SizedBox(height: 24),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      height: 55,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        enableInteractiveSelection: false, // Disable copy/paste menu
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2),
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\u200b]')),
                        ],
                        onChanged: (value) {
                          if (value.isEmpty) {
                            // Backspace pressed on empty field (triggers on Android/iOS with ZWS trick)
                            _otpControllers[index].text = '\u200b';
                            _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
                            
                            // Move to previous field
                            if (index > 0) {
                              _otpFocusNodes[index - 1].requestFocus();
                              // Optional: also clear the previous field?
                              // Standard behavior: just move back. User types again to overwrite or backspace again to clear.
                              // If user wants "delete immediately", we can't easily do it without knowing state.
                            }
                            return;
                          }
                          
                          // Handle input
                          if (value.length > 1) {
                            // Valid input (ZWS + Digit)
                            String cleanValue = value.replaceAll('\u200b', '');
                            if (cleanValue.isNotEmpty) {
                              // Taking the last entered char if multiple
                              String lastChar = cleanValue.characters.last;
                              _otpControllers[index].text = '\u200b$lastChar';
                              _otpControllers[index].selection = const TextSelection.collapsed(offset: 2);
                              
                              // Move to next
                              if (index < 5) {
                                _otpFocusNodes[index + 1].requestFocus();
                              } else {
                                _otpFocusNodes[index].unfocus();
                                _verifyOtp();
                              }
                            } else {
                              // Just ZWS remains (unlikely path if value.length > 1)
                              _otpControllers[index].text = '\u200b';
                              _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
                            }
                          }
                        },
                        onTap: () {
                          // Prevent selecting middle empty fields
                          // Find the first empty field (containing only ZWS)
                          int targetIndex = 0;
                          for (int i = 0; i < 6; i++) {
                            if (_otpControllers[i].text == '\u200b') {
                              targetIndex = i;
                              break;
                            }
                            // If it's the last iteration and it's filled, targetIndex stays at 0?
                            // No, if all filled, target the last one.
                            if (i == 5 && _otpControllers[i].text != '\u200b') {
                              targetIndex = 5;
                            }
                          }
                          
                          // If current tapped index is greater than allowed target
                          if (index != targetIndex) {
                            _otpFocusNodes[targetIndex].requestFocus();
                          } else {
                            // Ensure cursor is at end
                            if (_otpControllers[index].text == '\u200b') {
                                _otpControllers[index].selection = const TextSelection.collapsed(offset: 1);
                            } else {
                                _otpControllers[index].selection = const TextSelection.collapsed(offset: 2);
                            }
                          }
                        },
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCDDC39)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCDDC39), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _sendOtp,
                  child: Text(
                    'Resend OTP',
                    style: GoogleFonts.roboto(color: const Color(0xFFCDDC39)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.roboto(fontSize: 12, color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_isOtpSent ? _verifyOtp : _sendOtp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCDDC39),
                  foregroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isOtpSent ? 'Verify OTP' : 'Send OTP',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const Spacer(),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy',
                style: GoogleFonts.roboto(fontSize: 10, color: const Color(0xFF9E9E9E)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}