import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/seller.dart';
import '../services/api_service.dart';
import '../services/user_preferences.dart';

class SellerDetailScreen extends StatefulWidget {
  final Seller seller;
  final bool isSaved;
  final LatLng? userPosition;
  const SellerDetailScreen({super.key, required this.seller, required this.isSaved, this.userPosition});

  @override
  State<SellerDetailScreen> createState() => _SellerDetailScreenState();
}

class _SellerDetailScreenState extends State<SellerDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late bool _currentSaved;
  bool _showAllServices = false;

  @override
  void initState() {
    super.initState();
    _currentSaved = widget.isSaved;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    // Always add to recently viewed when this screen is opened
    UserPreferences().addToRecentlyViewed(widget.seller);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(launchUri)) {
      debugPrint('Could not launch display call options');
    }
  }

  Future<void> _openMap() async {
    final lat = widget.seller.position.latitude;
    final lon = widget.seller.position.longitude;
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (!await launchUrl(googleMapsUrl)) {
      debugPrint('Could not launch map');
    }
  }

  List<String> _parseServices(String desc) {
    // Parse services from description - split by common delimiters
    final services = <String>[];
    if (desc.toLowerCase().contains('services:')) {
      final afterServices = desc.split(RegExp(r'services:\s*', caseSensitive: false)).last;
      final items = afterServices.split(RegExp(r'[,\n•·\|]'));
      for (var item in items) {
        final cleaned = item.trim();
        if (cleaned.isNotEmpty && cleaned.length < 50) {
          services.add(cleaned);
        }
      }
    }
    return services;
  }

  @override
  Widget build(BuildContext context) {
    String dn = (widget.seller.name).replaceAll('_', ' ').trim();
    String dc = (widget.seller.category).replaceAll('_', ' ').trim();
    String desc = widget.seller.description ?? 'Quality ${widget.seller.category.toLowerCase()} products and services in your neighbourhood. Contact for details.';
    
    // Helper to check if image is a default placeholder
    bool isDefaultPlaceholder(String? url) {
      if (url == null || url.isEmpty) return true;
      final lowerUrl = url.toLowerCase();
      return lowerUrl.contains('default.jpg') || 
             lowerUrl.contains('default.svg') || 
             lowerUrl.contains('default.png') ||
             lowerUrl.contains('/default');
    }
    
    // Construct full image URL if needed, skip defaults
    String? imageUrl = widget.seller.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }
    if (isDefaultPlaceholder(imageUrl)) {
      imageUrl = null;
    }

    // Parse services from description
    final services = _parseServices(desc);
    final hasServices = services.isNotEmpty;
    
    // Clean description for display (remove services list if parsed)
    String cleanDesc = desc;
    if (hasServices && desc.toLowerCase().contains('services:')) {
      cleanDesc = desc.split(RegExp(r'services:\s*', caseSensitive: false)).first.trim();
      if (cleanDesc.isEmpty) {
        cleanDesc = 'Quality ${widget.seller.category.toLowerCase()} products and services in your neighbourhood.';
      }
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with elegant design - now includes profile info
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2C3E50),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _currentSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _currentSaved ? const Color(0xFFE8D5B7) : Colors.white,
                    size: 20,
                  ),
                  onPressed: () async {
                    // Update state locally without closing the screen
                    setState(() => _currentSaved = !_currentSaved);
                    
                    // Immediately persist
                    try {
                      if (widget.seller.id != null) {
                        if (_currentSaved) {
                          ApiService().pinSeller(widget.seller.id!);
                        } else {
                          ApiService().unpinSeller(widget.seller.id!);
                        }
                      }
                      await UserPreferences().toggleSavedSeller(widget.seller);
                    } catch (e) {
                      print('Error updating saved status: $e');
                    }
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF34495E),
                      Color(0xFF2C3E50),
                      Color(0xFF1A252F),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative pattern overlay
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: CustomPaint(
                          painter: _PatternPainter(),
                        ),
                      ),
                    ),
                    // Profile content centered in header
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Avatar with elegant golden border
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFFD4AF37), Color(0xFFE8D5B7), Color(0xFFD4AF37)],
                                ),
                              ),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F6F1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF2C3E50), width: 2),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: imageUrl != null 
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              dn.isNotEmpty ? dn[0].toUpperCase() : '?',
                                              style: GoogleFonts.playfairDisplay(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF2C3E50),
                                              ),
                                            ),
                                          );
                                        },
                                    )
                                    : Center(
                                        child: Text(
                                          dn.isNotEmpty ? dn[0].toUpperCase() : '?',
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2C3E50),
                                          ),
                                        ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            
                            // Name with elegant white typography
                            Text(
                              dn,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            // Category with refined chip design
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withOpacity(0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD4AF37),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dc,
                                    style: GoogleFonts.lato(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFE8D5B7),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Gold accent line at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
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
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Transform.translate(
                offset: Offset(0, _fadeAnim.value * -10 + 10),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Services Section (if available)
                    if (hasServices) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2C3E50).withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Services Offered',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (_showAllServices ? services : services.take(12))
                                    .map((service) => _buildServiceChip(service))
                                    .toList(),
                              ),
                              if (services.length > 12)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _showAllServices = !_showAllServices),
                                    child: Text(
                                      _showAllServices ? 'Show less' : '+${services.length - 12} more services',
                                      style: GoogleFonts.lato(
                                        fontSize: 10,
                                        color: const Color(0xFF1E88E5),
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // About Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2C3E50).withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'About',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hasServices ? cleanDesc : desc,
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                height: 1.6,
                                color: const Color(0xFF4A5568),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Quick Info Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    
                    ),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Row(
                        children: [
                          // Call Now - Premium dark button
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF34495E), Color(0xFF2C3E50)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2C3E50).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    if (widget.seller.phoneNumber != null && widget.seller.phoneNumber!.isNotEmpty) {
                                      _makePhoneCall(widget.seller.phoneNumber!);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Phone number not available', style: GoogleFonts.lato(fontSize: 12)),
                                          backgroundColor: const Color(0xFF2C3E50),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.call, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Call Now',
                                        style: GoogleFonts.lato(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // See on Map - Elegant outline
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _openMap,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.map_outlined, color: Color(0xFF2C3E50), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'See on Map',
                                        style: GoogleFonts.lato(
                                          color: const Color(0xFF2C3E50),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChip(String service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Text(
        service,
        style: GoogleFonts.lato(
          fontSize: 10,
          color: const Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3E50).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 9,
              color: const Color(0xFF718096),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 11,
              color: const Color(0xFF2C3E50),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom pattern painter for elegant header background
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(0, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
