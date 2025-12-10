import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/seller.dart';

class UserPreferences {
  static const String _keySavedSellers = 'saved_sellers_v2';
  static const String _keyRecentlyViewed = 'recently_viewed_v2';

  // Singleton
  static final UserPreferences _instance = UserPreferences._internal();
  factory UserPreferences() => _instance;
  UserPreferences._internal();

  Future<List<Seller>> getSavedSellers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? list = prefs.getStringList(_keySavedSellers);
    if (list == null) return [];
    return list.map((e) => Seller.fromJson(jsonDecode(e))).toList();
  }

  Future<void> toggleSavedSeller(Seller seller) async {
    final prefs = await SharedPreferences.getInstance();
    List<Seller> current = await getSavedSellers();
    
    // Check if exists (by ID if available, else by name)
    final index = current.indexWhere((s) => 
      (s.id != null && seller.id != null && s.id == seller.id) || 
      (s.name == seller.name)
    );

    if (index != -1) {
      // Remove
      current.removeAt(index);
    } else {
      // Add
      current.add(seller);
    }

    final List<String> encoded = current.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keySavedSellers, encoded);
  }

  Future<bool> isSellerSaved(Seller seller) async {
    final list = await getSavedSellers();
    return list.any((s) => 
      (s.id != null && seller.id != null && s.id == seller.id) || 
      (s.name == seller.name)
    );
  }

  Future<List<Seller>> getRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? list = prefs.getStringList(_keyRecentlyViewed);
    if (list == null) return [];
    return list.map((e) => Seller.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addToRecentlyViewed(Seller seller) async {
    final prefs = await SharedPreferences.getInstance();
    List<Seller> current = await getRecentlyViewed();

    // Remove if already exists to move it to top
    current.removeWhere((s) => 
      (s.id != null && seller.id != null && s.id == seller.id) || 
      (s.name == seller.name)
    );

    // Add to start
    current.insert(0, seller);

    // Limit to 20
    if (current.length > 20) {
      current = current.sublist(0, 20);
    }

    final List<String> encoded = current.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyRecentlyViewed, encoded);
  }
}
