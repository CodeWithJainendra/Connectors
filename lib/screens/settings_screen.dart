import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'otp_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _refreshPermissionStatus();
  }

  Future<void> _setNotifications(bool value) async {
    if (value) {
      final result = await Permission.notification.request();
      await _refreshPermissionStatus();
      if (!result.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enable notifications in Settings', style: GoogleFonts.lato(fontSize: 12))),
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      setState(() {
        _notifications = false;
      });
      await openAppSettings();
      await _refreshPermissionStatus();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final status = await Permission.notification.status;
    final allowed = status.isGranted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', allowed);
    setState(() {
      _notifications = allowed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A))),
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFAF7F0),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _sectionTitle('General'),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1.2),
            ),
            child: SwitchListTile(
              dense: true,
              title: Text('Notifications', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Text('Allow alerts even when app is closed', style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF4A4A4A))),
              value: _notifications,
              onChanged: _setNotifications,
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Seller'),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDDC39).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store_mall_directory_outlined, size: 16, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Become a Seller', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
      );
}
