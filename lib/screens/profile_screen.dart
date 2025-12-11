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
import 'home_screen.dart';

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
      backgroundColor: const Color(0xFFF8F6F1),
      body: Column(
        children: [
          // Elegant Header Section with dark theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF34495E),
                  Color(0xFF2C3E50),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // Top row with logout
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: _logout,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.logout, size: 18, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Profile Avatar with elegant golden border
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFE8D5B7), Color(0xFFD4AF37)],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFFF8F6F1),
                            child: _pictureUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      _pictureUrl,
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Text(
                                          uname.isNotEmpty ? uname[0].toUpperCase() : '?',
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : (_profileImagePath.isNotEmpty 
                                    ? ClipOval(
                                        child: Image.file(
                                          File(_profileImagePath),
                                          width: 68,
                                          height: 68,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(
                                        uname.isNotEmpty ? uname[0].toUpperCase() : '?',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2C3E50),
                                        ),
                                      )),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final src = await _askImageSource();
                                if (src != null) {
                                  final p = await _pickProfileImage(src);
                                  if (p != null) {
                                    setState(() {
                                      _profileImagePath = p;
                                      _pictureUrl = '';
                                    });
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('user_profile_image_path', _profileImagePath.trim());
                                    await prefs.remove('user_picture_url');
                                    await _autoSaveProfileImage(_profileImagePath);
                                  }
                                }
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF2C3E50), width: 2),
                                ),
                                child: const Icon(Icons.edit, size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // User name with elegant typography
                    Text(
                      uname,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Edit profile button
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showEditProfileDialog,
                              borderRadius: BorderRadius.circular(17),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Center(
                                  child: Text(
                                    'Edit Profile',
                                    style: GoogleFonts.lato(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        if (_userRole.toUpperCase() == 'SELLER')
                          Container(
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD4AF37), Color(0xFFE8D5B7)],
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CreateServicePostPage(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(17),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Center(
                                    child: Text(
                                      'Create Post',
                                      style: GoogleFonts.lato(
                                        color: const Color(0xFF2C3E50),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Gold accent divider
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFD4AF37),
                  Color(0xFFE8D5B7),
                  Color(0xFFD4AF37),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Tab Bar with elegant design
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _tabIndex = 0);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _tabIndex == 0 ? const Color(0xFFD4AF37) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_outline,
                            size: 14,
                            color: _tabIndex == 0 ? const Color(0xFF2C3E50) : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pinned Sellers',
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _tabIndex == 0 ? const Color(0xFF2C3E50) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _tabIndex = 1);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _tabIndex == 1 ? const Color(0xFFD4AF37) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 14,
                            color: _tabIndex == 1 ? const Color(0xFF2C3E50) : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recently Viewed',
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _tabIndex == 1 ? const Color(0xFF2C3E50) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: SafeArea(
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 5),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isEmpty
                    ? Center(
                        key: ValueKey(_tabIndex == 0 ? 'empty_pinned' : 'empty_recent'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C3E50).withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _tabIndex == 0 ? Icons.bookmark_border : Icons.history,
                                size: 32,
                                color: const Color(0xFF2C3E50).withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tabIndex == 0 ? 'No pinned sellers' : 'No recent views',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _tabIndex == 0 
                                  ? 'Save your favorite sellers here'
                                  : 'Start exploring to see history',
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const HomeScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF34495E), Color(0xFF2C3E50)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Explore Now',
                                  style: GoogleFonts.lato(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        key: ValueKey(_tabIndex == 0 ? 'grid_pinned' : 'grid_recent'),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
        // Add to recently viewed immediately
        await UserPreferences().addToRecentlyViewed(s);
        
        // Check selection status from _savedBiz list
        final isSaved = _savedBiz.any((element) => element.id == s.id);
        
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerDetailScreen(
              seller: s,
              isSaved: isSaved,
            ),
          ),
        );

        // Always reload to reflect changes made in detail screen
        if (mounted) _load(); 
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C3E50).withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 25),
                // Avatar with subtle gold border
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFE8D5B7)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18, 
                      backgroundColor: const Color(0xFFF8F6F1),
                      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null 
                          ? Text(
                              dn.isNotEmpty ? dn[0].toUpperCase() : '?',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14 ,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C3E50),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (showCat)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 8,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
            // Bookmark icon for pinned sellers
            if (_tabIndex == 0)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () async {
                    if (s.id != null) {
                       try {
                         await ApiService().unpinSeller(s.id!);
                       } catch (e) {
                         print('Failed to unpin seller: $e');
                       }
                    }
                    await UserPreferences().toggleSavedSeller(s);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark,
                      size: 10,
                      color: Color(0xFFD4AF37),
                    ),
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
                                    try {
                                      final fullname = _name.text.trim();
                                      if (fullname.length < 3 || fullname.length > 100) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Name must be between 3 and 100 characters')),
                                          );
                                        }
                                        return;
                                      }
                                      String? filePath;
                                      if (_profileImagePath.isNotEmpty) {
                                        final f = File(_profileImagePath);
                                        if (!await f.exists()) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Selected image not found on device')),
                                            );
                                          }
                                          return;
                                        }
                                        filePath = _profileImagePath;
                                      }
                                      final updateRes = await ApiService().updateAccountProfile(
                                        fullname: fullname,
                                        filePath: filePath,
                                      );
                                      // Optionally refresh posts
                                      try {
                                        await ApiService().getSellerPosts();
                                      } catch (_) {}
                                      try {
                                        final data0 = updateRes['data'] ?? updateRes;
                                        var data = data0;
                                        if (data is Map && data['user_account'] == null && data['user'] == null && data['account'] == null) {
                                          final prof = await ApiService().getAccountProfile();
                                          data = prof['data'] ?? prof;
                                        }
                                        final user = (data is Map) ? (data['user_account'] ?? data['user'] ?? data['account']) : null;
                                        String? pictureUrl;
                                        if (user is Map) {
                                          final pu = user['picture_url']?.toString();
                                          if (pu != null && pu.isNotEmpty) {
                                            pictureUrl = pu.startsWith('http') ? pu : 'https://www.jayantslist.com$pu';
                                          }
                                          final fullnameServer = user['fullname']?.toString();
                                          if (fullnameServer != null && fullnameServer.isNotEmpty) {
                                            _name.text = fullnameServer;
                                          }
                                        }
                                        final prefs = await SharedPreferences.getInstance();
                                        if (pictureUrl != null && pictureUrl.isNotEmpty) {
                                          final ts = DateTime.now().millisecondsSinceEpoch;
                                          final sep = pictureUrl.contains('?') ? '&' : '?';
                                          final busted = '$pictureUrl${sep}v=$ts';
                                          await prefs.setString('user_picture_url', busted);
                                          setState(() {
                                            _pictureUrl = busted;
                                          });
                                        }
                                      } catch (_) {}
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Profile updated on server', style: GoogleFonts.lato(fontSize: 12))),
                                        );
                                      }
                                    } catch (e) {
                                      final msg = e.toString();
                                      final isDefaultUnlinkError = msg.contains('ENOENT') && (msg.contains('default.jpg') || msg.contains('unlink'));
                                      if (isDefaultUnlinkError) {
                                        try {
                                          final prof = await ApiService().getAccountProfile();
                                          final data = prof['data'] ?? prof;
                                          final user = (data is Map) ? (data['user_account'] ?? data['user'] ?? data['account']) : null;
                                          String? pictureUrl;
                                          if (user is Map) {
                                            final pu = user['picture_url']?.toString();
                                            if (pu != null && pu.isNotEmpty) {
                                              pictureUrl = pu.startsWith('http') ? pu : 'https://www.jayantslist.com$pu';
                                            }
                                          }
                                          if (pictureUrl != null && pictureUrl.isNotEmpty) {
                                            final prefs = await SharedPreferences.getInstance();
                                            final ts = DateTime.now().millisecondsSinceEpoch;
                                            final sep = pictureUrl.contains('?') ? '&' : '?';
                                            final busted = '$pictureUrl${sep}v=$ts';
                                            await prefs.setString('user_picture_url', busted);
                                            if (mounted) {
                                              setState(() {
                                                _pictureUrl = busted;
                                              });
                                            }
                                          }
                                        } catch (_) {}
                                      } else {
                                        // Silent failure: no user-facing error message
                                      }
                                    }
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

  Future<void> _autoSaveProfileImage(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) {
        return;
      }
      var fullname = _name.text.trim();
      if (fullname.length < 3 || fullname.length > 100) {
        final email = _email.text.trim();
        fullname = email.isNotEmpty ? email.split('@').first : 'User';
      }
      final res = await ApiService().updateAccountProfile(
        fullname: fullname,
        filePath: path,
      );
      final data = res['data'] ?? res;
      final user = (data is Map) ? (data['user_account'] ?? data['user'] ?? data['account']) : null;
      String? pictureUrl;
      if (user is Map) {
        final pu = user['picture_url']?.toString();
        if (pu != null && pu.isNotEmpty) {
          pictureUrl = pu.startsWith('http') ? pu : 'https://www.jayantslist.com$pu';
        }
      }
      if (pictureUrl != null && pictureUrl.isNotEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final sep = pictureUrl.contains('?') ? '&' : '?';
        final busted = '$pictureUrl${sep}v=$ts';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_picture_url', busted);
        if (mounted) {
          setState(() {
            _pictureUrl = busted;
          });
        }
      }
    } catch (_) {
      // Silent: no snackbar
    }
  }
}
