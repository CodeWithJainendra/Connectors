import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';




import 'login_screen.dart';
import 'create_service_post_page.dart';
import '../services/user_preferences.dart';
import '../services/api_service.dart';
import '../models/seller.dart';
import 'seller_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  String _profileImagePath = '';
  List<Seller> _savedBiz = [];
  List<Seller> _recentlyViewed = [];
  int _tabIndex = 0;
  String _userRole = '';
  String _pictureUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _name.text = prefs.getString('user_name') ?? '';
    _email.text = prefs.getString('user_email') ?? '';
    _password.text = prefs.getString('user_password') ?? '';
    _phone.text = prefs.getString('user_phone') ?? '';
    _address.text = prefs.getString('user_address') ?? '';
    _profileImagePath = prefs.getString('user_profile_image_path') ?? '';
    _userRole = prefs.getString('user_role') ?? '';
    _pictureUrl = prefs.getString('user_picture_url') ?? '';
    
    _savedBiz = await UserPreferences().getSavedSellers();
    _recentlyViewed = await UserPreferences().getRecentlyViewed();
    setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _name.text.trim());
    await prefs.setString('user_email', _email.text.trim());
    await prefs.setString('user_password', _password.text);
    await prefs.setString('user_phone', _phone.text.trim());
    await prefs.setString('user_address', _address.text.trim());
    await prefs.setString('user_profile_image_path', _profileImagePath.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile saved', style: GoogleFonts.lato(fontSize: 12))),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uname = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : (_email.text.trim().isNotEmpty ? _email.text.trim().split('@').first : 'User');
    
    final currentList = _tabIndex == 0 ? _savedBiz : _recentlyViewed;
    final isEmpty = currentList.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE9DF),
        elevation: 0,
        titleSpacing: 0,
        toolbarHeight: 10,
        title: const SizedBox.shrink(),
        actions: const [],
      ),
      backgroundColor: const Color(0xFFFAF7F0),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFEDE9DF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Stack(
              children: [
                Column(
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFFCDDC39).withOpacity(0.25),
                            child: _pictureUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _pictureUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.person, color: Color(0xFF1A1A1A), size: 30);
                                      },
                                    ),
                                  )
                                : (_profileImagePath.isNotEmpty 
                                    ? ClipOval(
                                        child: Image.file(
                                          File(_profileImagePath),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.person, color: Color(0xFF1A1A1A), size: 30)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: InkWell(
                              onTap: () async {
                                final src = await _askImageSource();
                                if (src != null) {
                                  final p = await _pickProfileImage(src);
                                  if (p != null) {
                                    setState(() {
                                      _profileImagePath = p;
                                    });
                                    await _save();
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F0),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
                                ),
                                child: const Icon(Icons.edit, size: 14, color: Color(0xFF1A1A1A)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        uname,
                        style: GoogleFonts.playfairDisplay(color: const Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 40,
                          width: 140,
                          child: OutlinedButton(
                            onPressed: _showEditProfileDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
                              backgroundColor: const Color(0xFFFAF7F0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text('Edit profile', style: GoogleFonts.lato(color: const Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: _logout,
                    child: const Icon(Icons.logout, size: 24, color: Color(0xFF1A1A1A)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFEDE9DF),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  top: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1),
                  bottom: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1),
                ),
              ),
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _tabIndex = 0);
                          _load(); // Reload to refresh list
                        },
                        icon: Icon(Icons.grid_on, size: 16, color: const Color(0xFF1A1A1A)),
                        label: Text('Pinned Sellers', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          side: const BorderSide(color: Colors.transparent, width: 0),
                          backgroundColor: _tabIndex == 0 ? const Color(0xFFCDDC39).withOpacity(0.2) : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _tabIndex = 1);
                          _load(); // Reload to refresh list
                        },
                        icon: Icon(Icons.history, size: 16, color: const Color(0xFF1A1A1A)),
                        label: Text('Recently Viewed', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          side: const BorderSide(color: Colors.transparent, width: 0),
                          backgroundColor: _tabIndex == 1 ? const Color(0xFFCDDC39).withOpacity(0.2) : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 5),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isEmpty
                    ? GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          // Blurred placeholder card
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.05), width: 1),
                            ),
                            child: Center(
                              child: Icon(Icons.image, color: const Color(0xFF1A1A1A).withOpacity(0.1), size: 24),
                            ),
                          );
                        },
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final seller = currentList[index];
                          return _sellerCard(seller);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _userRole.toUpperCase() == 'SELLER'
          ? Builder(
              builder: (context) {
                // Calculate bottom nav bar total height:
                // Navigation bar height (58) + SafeArea bottom (6) + vertical margins (16) + extra spacing (10)
                const double navBarHeight = 58.0;
                const double navBarSafeArea = 6.0;
                const double navBarMargins = 16.0; // 8 top + 8 bottom
                const double extraSpacing = 10.0;
                const double totalBottomPadding = navBarHeight + navBarSafeArea + navBarMargins + extraSpacing;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: totalBottomPadding),
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateServicePostPage(),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xFF014D4E),
                    elevation: 6,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/Copilot_20251204_141221.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _sellerCard(Seller s) {
    final dn = s.name.replaceAll('_', ' ').trim();
    final dc = s.category.replaceAll('_', ' ').trim();
    final showCat = dc.isNotEmpty && dc.toLowerCase() != dn.toLowerCase();
    
    String? imageUrl = s.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }

    return GestureDetector(
      onTap: () async {
        // Check selection status from _savedBiz list
        final isSaved = _savedBiz.any((element) => element.id == s.id);
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerDetailScreen(
              seller: s,
              isSaved: isSaved,
              // userPosition is optional check navigation
            ),
          ),
        );

        if (result != null && s.id != null) {
           if (result == 'save') {
             try { await ApiService().pinSeller(s.id!); } catch(e) { debugPrint('Pin failed: $e'); }
             // Ensure it's added
             if (!_savedBiz.any((e) => e.id == s.id)) {
                await UserPreferences().toggleSavedSeller(s);
             }
           } else if (result == 'unsave') {
             try { await ApiService().unpinSeller(s.id!); } catch(e) { debugPrint('Unpin failed: $e'); }
             // Ensure it's removed
             if (_savedBiz.any((e) => e.id == s.id)) {
                await UserPreferences().toggleSavedSeller(s);
             }
           }
           _load();
        }
      },
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 20, 
                  backgroundColor: const Color(0xFFEDE9DF),
                  backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null 
                      ? Text(dn.isNotEmpty ? dn[0].toUpperCase() : '?', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)))
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 2),
                      if (showCat)
                        Text(
                          dc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 9, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                        ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          'Quality products & services.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 9, color: const Color(0xFF9CA3AF), height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          if (_tabIndex == 0) // Only show heart in Saved Bizz tab (or both? User said "saved Bizz mein... show ho")
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: () async {
                // Unsave logic for Profile Screen
                if (s.id != null) {
                   try {
                     // Assuming we only show saved items here, tapping heart should probably unsave it
                     // But let's check if it's already saved (it should be)
                     await ApiService().unpinSeller(s.id!);
                   } catch (e) {
                     print('Failed to unpin seller: $e');
                   }
                }
                await UserPreferences().toggleSavedSeller(s);
                _load(); // Refresh list
              },
              child: const Icon(
                Icons.favorite,
                size: 14,
                color: Color(0xFFCDDC39),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _field(String label, TextEditingController controller, IconData icon, {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF4A4A4A))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFFFAF7F0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Color(0xFFCDDC39), width: 1.4),
            ),
          ),
          style: GoogleFonts.lato(fontSize: 11),
        ),
      ],
    );
  }

  void _showEditProfileDialog() {
    final tn = TextEditingController(text: _name.text);
    final tp = TextEditingController(text: _phone.text);
    final ta = TextEditingController(text: _address.text);
    String localImagePath = _profileImagePath;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFFAF7F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return AnimatedPadding(
                padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12 + MediaQuery.of(context).viewInsets.bottom),
                duration: const Duration(milliseconds: 150),
                curve: Curves.decelerate,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Edit Profile', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _field('Name', tn, Icons.person_outline_rounded, keyboard: TextInputType.name),
                        const SizedBox(height: 8),
                        _field('Phone number', tp, Icons.phone_outlined, keyboard: TextInputType.phone),
                        const SizedBox(height: 8),
                        _field('Address', ta, Icons.location_on_outlined, keyboard: TextInputType.streetAddress),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1A1A1A),
                                    side: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
                                    backgroundColor: const Color(0xFFFAF7F0),
                                  ),
                                  child: Text('Cancel', style: GoogleFonts.lato(color: const Color(0xFF1A1A1A), fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    _name.text = tn.text.trim();
                                    _phone.text = tp.text.trim();
                                    _address.text = ta.text.trim();
                                    _profileImagePath = localImagePath.trim();
                                    await _save();
                                    if (mounted) setState(() {});
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1A1A1A),
                                    backgroundColor: const Color(0xFFCDDC39),
                                  ),
                                  child: Text('Save', style: GoogleFonts.lato(color: const Color(0xFF1A1A1A), fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return null;
      return picked.path;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image picker unavailable. Please stop and re-run the app.', style: GoogleFonts.lato(fontSize: 12))),
        );
      }
      return null;
    }
  }

  Future<ImageSource?> _askImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFFAF7F0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF1A1A1A), size: 20),
                title: Text('Camera', style: GoogleFonts.lato(color: const Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1A1A1A), size: 20),
                title: Text('Gallery', style: GoogleFonts.lato(color: const Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }
}
