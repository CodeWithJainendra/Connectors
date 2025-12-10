import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/seller.dart';

class SellerDetailScreen extends StatelessWidget {
  final Seller seller;
  final bool isSaved;
  final LatLng? userPosition;
  const SellerDetailScreen({super.key, required this.seller, required this.isSaved, this.userPosition});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(launchUri)) {
      debugPrint('Could not launch display call options');
    }
  }

  Future<void> _openMap() async {
    final lat = seller.position.latitude;
    final lon = seller.position.longitude;
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (!await launchUrl(googleMapsUrl)) {
      debugPrint('Could not launch map');
    }
  }

  @override
  Widget build(BuildContext context) {
    String dn = (seller.name).replaceAll('_', ' ').trim();
    String dc = (seller.category).replaceAll('_', ' ').trim();
    String desc = seller.description ?? 'Quality ${seller.category.toLowerCase()} products and services in your neighbourhood. Contact for details.';
    
    // Construct full image URL if needed
    String? imageUrl = seller.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context, isSaved ? 'unsave' : 'save');
            },
            icon: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved ? const Color(0xFFCDDC39) : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
             // Circle Avatar with Icon
             Container(
               width: 100,
               height: 100,
               decoration: BoxDecoration(
                 color: const Color(0xFFEEF0C3), // Light lime bg
                 shape: BoxShape.circle,
               ),
               clipBehavior: Clip.hardEdge,
               child: imageUrl != null 
                   ? Image.network(
                       imageUrl,
                       fit: BoxFit.cover,
                       errorBuilder: (context, error, stackTrace) {
                         return const Center(
                           child: Icon(Icons.storefront_outlined, size: 40, color: Color(0xFF1A1A1A)),
                         );
                       },
                   )
                   : const Center(
                       child: Icon(Icons.storefront_outlined, size: 40, color: Color(0xFF1A1A1A)),
                   ),
             ),
             const SizedBox(height: 24),
             
             // Shop Name
             Text(
               dn,
               textAlign: TextAlign.center,
               style: GoogleFonts.playfairDisplay(
                 fontSize: 26,
                 fontWeight: FontWeight.w700,
                 color: const Color(0xFF1A1A1A),
                 letterSpacing: 0.5,
               ),
             ),
             const SizedBox(height: 12),
             
             // Category Chip
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
               decoration: BoxDecoration(
                 color: const Color(0xFFEEF0C3),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Text(
                 dc,
                 style: GoogleFonts.lato(
                   fontSize: 13,
                   fontWeight: FontWeight.w600,
                   color: const Color(0xFF1A1A1A),
                 ),
               ),
             ),
             
             const SizedBox(height: 48),

             // About Section
             Align(
               alignment: Alignment.centerLeft,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'About',
                     style: GoogleFonts.playfairDisplay(
                       fontSize: 20,
                       fontWeight: FontWeight.w700,
                       color: const Color(0xFF1A1A1A),
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     desc,
                     style: GoogleFonts.lato(
                       fontSize: 15,
                       height: 1.5,
                       color: const Color(0xFF4A4A4A),
                     ),
                   ),
                 ],
               ),
             ),
             
             const SizedBox(height: 48),
             
             // Action Buttons
             Row(
               children: [
                 // Call Now
                 Expanded(
                   child: SizedBox(
                     height: 52,
                     child: ElevatedButton.icon(
                       onPressed: () {
                         if (seller.phoneNumber != null && seller.phoneNumber!.isNotEmpty) {
                           _makePhoneCall(seller.phoneNumber!);
                         } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Phone number not available')),
                           );
                         }
                       },
                       icon: const Icon(Icons.call, size: 18),
                       label: Text('Call Now', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF1A1A1A),
                         foregroundColor: Colors.white,
                         elevation: 0,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ),
                 ),
                 const SizedBox(width: 16),
                 
                 // See on Map
                 Expanded(
                   child: SizedBox(
                     height: 52,
                     child: OutlinedButton.icon(
                       onPressed: _openMap,
                       icon: const Icon(Icons.map_outlined, size: 18),
                       label: Text('See on Map', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: const Color(0xFF1A1A1A),
                         side: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ),
                 ),
               ],
             ),
          ],
        ),
      ),
    );
  }
}
