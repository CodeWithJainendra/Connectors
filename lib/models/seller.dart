import 'package:latlong2/latlong.dart';

// Seller Model

class Seller {
  final int? id;
  final String name;
  final String category;
  final LatLng position;
  final String? imageUrl;
  final String? phoneNumber;
  final String? description;

  const Seller({
    this.id,
    required this.name,
    required this.category,
    required this.position,
    this.imageUrl,
    this.phoneNumber,
    this.description,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    String cat = 'Service';
    if (json['category'] is Map) {
      cat = json['category']['name']?.toString() ?? 'Service';
    } else {
      cat = json['category']?.toString() ?? 'Service';
    }

    return Seller(
      id: int.tryParse(json['id']?.toString() ?? ''),
      name: json['shop_name'] ?? json['item_name'] ?? json['name'] ?? 'Shop',
      category: cat,
      position: LatLng(
        double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
        double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      ),
      imageUrl: json['picture_url'] ?? json['imageUrl'] ?? json['profile_image_url'],
      phoneNumber: json['contact_no'] ?? json['mobile_number'] ?? json['phone_number'] ?? json['phone'] ?? json['contact_number'],
      description: json['description'] ?? json['about'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'imageUrl': imageUrl,
      'phone_number': phoneNumber,
      'description': description,
    };
  }
}
