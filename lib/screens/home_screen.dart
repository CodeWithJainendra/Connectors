import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'chatbot_screen.dart';
import 'seller_detail_screen.dart';
import '../services/api_service.dart';
import '../services/user_preferences.dart';
import '../models/seller.dart';

class HomeScreen extends StatefulWidget {
  final int initialLocationViewIndex;
  const HomeScreen({super.key, this.initialLocationViewIndex = 1});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentLocation = 'Fetching location...';
  int _selectedIndex = 1;
  int _previousIndex = 0;
  MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(28.6139, 77.2090); // Default: Delhi
  bool _mapLoading = false;
  bool _isSeller = false;
  List<String> _recentlyViewed = const [
    'Cafe Bloom',
    'Tech Hub',
    'Craft Corner',
    'Fresh Farm',
    'Lotus Flowers',
    'Daily Needs',
  ];
  List<String> _savedBiz = const [
    'Green Grocer',
    'Urban Bakery',
    'Spark Electronics',
    'Style Studio',
    'Home Care',
  ];
  // Filters
  double _filterDistance = 3000.0;
  Set<String> _selectedCategories = {};
  List<int> _selectedCategoryIds = [];
  String _searchQuery = '';
  List<Seller> _sellers = [];
  Seller? _selectedSeller;
  bool _sellersLoading = false;
  Set<String> _lastFetchedCategories = {};
  final TextEditingController _searchController = TextEditingController();
  // removed duplicate query
  Set<String> _selectedLetters = {};
  final List<String> _allCategories = const []; // We will use _apiCategories instead
  double? _distanceLimitKm = 50.0;
  Timer? _debounceTimer;
  int _locationViewIndex = 1;
  Timer? _searchDebounce;
  Timer? _locationDebounce;
  Timer? _sellerLoadDebounce;
  int _notificationCount = 3;
  final List<String> _notifications = const [
    'New offer near you',
    'Profile updated successfully',
    '3 new sellers added nearby',
  ];
  bool _expandingSearch = false;
  List<String> _apiCategories = [];
  bool _apiCatsLoading = false;
  String? _apiCatsError;
  Map<String, String> _apiCatCodes = {};
  Map<String, int> _apiCatIds = {};
  Map<String, String> _apiCatImages = {};
  List<Map<String, dynamic>> _allRawCategories = [];

  // Grid Category Hierarchy State
  List<Map<String, dynamic>> _gridCategories = [];
  int? _currentGridParentId;
  String? _currentGridParentName;
  bool _gridCatsLoading = false;

  String _clean(String? s) {
    final t = (s ?? '').replaceAll('_', ' ').trim();
    return t;
  }

  String _norm(String? s) {
    return _clean(s).toLowerCase();
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: Icon(icon, size: 18, color: const Color(0xFF1A1A1A))),
          ),
        ),
      ),
    );
  }

  Widget _chipButton(String label, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFCDDC39), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Polygon>> _loadIndiaPolygons() async {
    try {
      final raw = await rootBundle.loadString('assets/images/Maps/INDIA_STATES.geojson');
      final data = json.decode(raw);
      final features = (data['features'] as List?) ?? const [];
      final List<Polygon> polygons = [];
      for (final f in features) {
        final geom = f['geometry'] ?? {};
        final type = geom['type'];
        final coords = geom['coordinates'];
        Color fill = const Color(0xFFE8F5E9);
        Color border = const Color(0xFF1A1A1A).withOpacity(0.25);
        double stroke = 0.7;
        if (type == 'Polygon') {
          final rings = (coords as List); // [outer, holes...]
          if (rings.isNotEmpty) {
            final outer = (rings.first as List);
            final points = outer.map<LatLng>((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();
            polygons.add(Polygon(points: points, color: fill, borderColor: border, borderStrokeWidth: stroke, isFilled: true));
          }
        } else if (type == 'MultiPolygon') {
          final polys = (coords as List); // [[rings], [rings]...]
          for (final poly in polys) {
            final rings = (poly as List);
            if (rings.isNotEmpty) {
              final outer = (rings.first as List);
              final points = outer.map<LatLng>((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();
              polygons.add(Polygon(points: points, color: fill, borderColor: border, borderStrokeWidth: stroke, isFilled: true));
            }
          }
        }
      }
      return polygons;
    } catch (e) {
      print('Failed to load India GeoJSON: $e');
      return [];
    }
  }

  void _openIndiaMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          final indiaCenter = const LatLng(22.9734, 78.6569);
          final controller = MapController();
          final sellers = _nearbySellers(categories: _selectedCategories.isNotEmpty ? _selectedCategories : null);
          return Scaffold(
            backgroundColor: const Color(0xFFFAF7F0),
            appBar: AppBar(
              elevation: 0,
              backgroundColor: const Color(0xFFFAF7F0),
              foregroundColor: const Color(0xFF1A1A1A),
              title: Text('India Map', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            body: FutureBuilder<List<Polygon>>(
              future: _loadIndiaPolygons(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final polygons = snapshot.data!;
                return Stack(
                  children: [
                    FlutterMap(
                      mapController: controller,
                      options: MapOptions(
                        initialCenter: indiaCenter,
                        initialZoom: 4.5,
                        minZoom: 3.0,
                        maxZoom: 18.0,
                        interactionOptions: const InteractionOptions(
                          enableScrollWheel: true,
                          enableMultiFingerGestureRace: true,
                        ),
                        onMapEvent: (event) {
                          final c = controller.camera.center;
                          const minLat = 6.0, minLng = 68.0, maxLat = 37.5, maxLng = 97.0;
                          double clampedLat = c.latitude;
                          double clampedLng = c.longitude;
                          if (c.latitude < minLat) clampedLat = minLat;
                          if (c.latitude > maxLat) clampedLat = maxLat;
                          if (c.longitude < minLng) clampedLng = minLng;
                          if (c.longitude > maxLng) clampedLng = maxLng;
                          if (clampedLat != c.latitude || clampedLng != c.longitude) {
                            controller.move(LatLng(clampedLat, clampedLng), controller.camera.zoom);
                          }
                        },
                      ),
                      children: [
                        PolygonLayer(polygons: polygons),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition,
                              width: 64,
                              height: 64,
                              child: const Icon(
                                Icons.my_location,
                                size: 24,
                                color: Color(0xFFFF5252),
                              ),
                            ),
                            ...sellers.map((s) => Marker(
                                  point: s.position,
                                  width: 64,
                                  height: 64,
                                  child: const Icon(
                                    Icons.location_on,
                                    size: 22,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                )),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          _zoomButton(Icons.add, () {
                            final currentZoom = controller.camera.zoom;
                            final newZoom = math.min(18.0, currentZoom + 1);
                            controller.move(controller.camera.center, newZoom);
                          }),
                          const SizedBox(height: 8),
                          _zoomButton(Icons.remove, () {
                            final currentZoom = controller.camera.zoom;
                            final newZoom = math.max(3.0, currentZoom - 1);
                            controller.move(controller.camera.center, newZoom);
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Combined Filter Bottom Sheet
  void _showCombinedFilterSheet({String? parentCategory}) {
    // Ensure root categories are loaded if opening root filter
    if (parentCategory == null && _apiCategories.isEmpty && !_apiCatsLoading) {
      _fetchApiCategories();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        
        // Local State
        final Set<String> tempSelectedCategories = Set.from(_selectedCategories);
        final List<int> tempSelectedCategoryIds = List.from(_selectedCategoryIds);
        double? tempDistance = _distanceLimitKm;
        
        // Cache for loaded tabs to avoid refetching
        final Map<String, List<_CategoryNode>> allowedChildrenCache = {};
        
        return StatefulBuilder(
          builder: (context, sbSetState) {
             
             // Initialization: Ensure we have a selected root
             // If parentCategory is passed, that is our selected root.
             // If not, we default to the first available root category.
             // We use _apiCategories for the Left Panel (Tabs).
             
             String activeRoot = parentCategory ?? (_apiCategories.isNotEmpty ? _apiCategories.first : '');
             
             return _FilterSheetContent(
               initialTab: activeRoot,
               rootCategories: _apiCategories,
               apiCatIds: _apiCatIds,
               apiCatCodes: _apiCatCodes,
               sellers: _sellers,
               rawCategories: _allRawCategories,
               tempSelectedCategories: tempSelectedCategories,
               tempSelectedCategoryIds: tempSelectedCategoryIds,
               distance: tempDistance,
               onApply: (selectedCats, selectedIds, dist) {
                 Navigator.pop(context);
                 setState(() {
                   _selectedCategories = selectedCats;
                   _selectedCategoryIds = selectedIds;
                   _distanceLimitKm = dist;
                 });
                 print('APPLIED: Categories=$_selectedCategories');
                 _loadSellersForCategories();
               },
             );
          },
        );
      },
    );
  }


  void _showFilterDrawer() {
     _showCombinedFilterSheet();
  }

  void _showDistanceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) {
        int selectedIndex = -1; // Default to none (Custom)
        final limit = _distanceLimitKm;
        
        if (limit == null) {
          selectedIndex = 3; // Any
        } else if (limit < 1.0) {
          selectedIndex = 0; // < 1 km
        } else if ((limit - 1.0).abs() < 0.1) {
          selectedIndex = 1; // 1 km
        } else if ((limit - 5.0).abs() < 0.1) {
          selectedIndex = 2; // 5 km
        }
        return StatefulBuilder(
          builder: (context, sbSetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distance', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _distanceChip('< 1 km', selectedIndex == 0, () { sbSetState(() { selectedIndex = 0; }); }),
                        const SizedBox(width: 8),
                        _distanceChip('1 km', selectedIndex == 1, () { sbSetState(() { selectedIndex = 1; }); }),
                        const SizedBox(width: 8),
                        _distanceChip('5 km', selectedIndex == 2, () { sbSetState(() { selectedIndex = 2; }); }),
                        const SizedBox(width: 8),
                        _distanceChip('All', selectedIndex == 3, () { sbSetState(() { selectedIndex = 3; }); }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _distanceLimitKm = null;
                              });
                              _loadSellersForCategories();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
                              backgroundColor: const Color(0xFFFAF7F0),
                            ),
                            child: Text('Clear', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                switch (selectedIndex) {
                                  case 0:
                                    _distanceLimitKm = 0.99;
                                    break;
                                  case 1:
                                    _distanceLimitKm = 1.0;
                                    break;
                                  case 2:
                                    _distanceLimitKm = 5.0;
                                    break;
                                  case 3:
                                    _distanceLimitKm = null;
                                    break;
                                }
                              });
                              _loadSellersForCategories();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCDDC39),
                              foregroundColor: const Color(0xFF1A1A1A),
                            ),
                            child: Text('Apply', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _distanceChip(String label, bool selected, VoidCallback onSelected) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFCDDC39).withOpacity(0.25) : const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
        ),
        child: Text(label, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
      ),
    );
  }

  Future<void> _expandSearch() async {
    if (_distanceLimitKm == null) return;
    _expandingSearch = true;
    setState(() {});
    final base = _distanceLimitKm ?? 5.0;
    final List<double> stages;
    if (base < 1.0) {
      stages = [1.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0];
    } else if (base == 1.0) {
      stages = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0];
    } else if (base == 5.0) {
      stages = [10.0, 15.0, 20.0, 25.0, 30.0];
    } else {
      stages = [10.0, 15.0, 20.0, 25.0, 30.0].where((s) => s > base).toList();
    }
    for (final km in stages) {
      setState(() { _distanceLimitKm = km; });
      await _loadSellersForCategories();
      final sellers = _nearbySellers(categories: _selectedCategories.isNotEmpty ? _selectedCategories : null);
      if (sellers.isNotEmpty) break;
    }
    _expandingSearch = false;
    setState(() {});
  }
  Seller _findOrCreateSellerByName(String title) {
    final cleaned = _clean(title);
    final match = _sellers.firstWhere(
      (s) => _clean(s.name).toLowerCase() == cleaned.toLowerCase(),
      orElse: () => Seller(id: null, name: cleaned, category: 'Shop', position: _currentPosition),
    );
    return match;
  }


  double _pageBottomInset(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  double _navBarPadding(BuildContext context) {
    return 58.0 + MediaQuery.of(context).padding.bottom + 6.0;
  }

  Widget _bottomBlurOverlay() {
    return IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: _navBarPadding(context),
            color: const Color(0xFFFAF7F0).withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  List<Seller> _nearbySellers({Set<String>? categories}) {
    final d = Distance();
    // We rely on backend filtering for categories AND distance.
    // Only support local text search for instant filtering UX.
    // Don't re-filter by distance here as API already returned distance-filtered results.
    
    final filtered = _sellers.where((s) {
      final name = _clean(s.name);
      // Only filter by search query if user typed something
      final okQuery = _searchQuery.isEmpty || 
          name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          _clean(s.category).toLowerCase().contains(_searchQuery.toLowerCase());
      return okQuery;
    }).toList();
    
    // Sort by distance from user
    filtered.sort((a, b) => d.as(LengthUnit.Meter, _currentPosition, a.position)
        .compareTo(d.as(LengthUnit.Meter, _currentPosition, b.position)));
    return filtered;
  }

  Future<void> _updateDistanceBasedOnMapBounds() async {
    // Get visible bounds
    final bounds = _mapController.camera.visibleBounds;
    final center = _mapController.camera.center;
    final northEast = bounds.northEast;

    // Calculate distance from center to corner (radius of view)
    final distance = const Distance().as(LengthUnit.Kilometer, center, northEast);
    
    // Logic: 
    // Bidirectional update: If user zooms/pans, update the filter to match the view.
    // This allows exploring beyond OR within the initial/manual filter.
    
    // Safety check: If currently in "All" mode (> 10000 km), don't shrink it.
    final currentLimit = _distanceLimitKm ?? 20000.0;
    if (currentLimit > 10000.0) return;
    
    // Only update if significantly different (> 15% change or > 5km) to avoid constant reloads
    // on small movements.
    final diff = (distance - currentLimit).abs();
    final isSignificant = diff > (currentLimit * 0.15) || diff > 5.0;

    if (isSignificant) {
      print('🗺️ Map interaction detected. Updating search radius to ${distance.toStringAsFixed(1)} km (was ${currentLimit.toStringAsFixed(1)} km)');
      
      // Update filter to match view (with buffer). 
      // This allows the map view to drive the search radius.
      setState(() {
        _distanceLimitKm = distance + (distance * 0.1); // +10% buffer
        // Maintain a reasonable minimum
        if (_distanceLimitKm! < 1.0) _distanceLimitKm = 1.0;
        _sellersLoading = true;
      });
      
      // Load sellers with the new distance limit
      await _loadArtisansNearby();
      if (mounted) {
        setState(() {
          _sellersLoading = false;
        });
      }
    }
  }


  // Helper to check if an image URL is a default placeholder
  bool _isDefaultPlaceholder(String? url) {
    if (url == null || url.isEmpty) return true;
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('default.jpg') || 
           lowerUrl.contains('default.svg') || 
           lowerUrl.contains('default.png') ||
           lowerUrl.contains('/default');
  }

  Marker _buildSellerMarker(Seller s, {LatLng? position}) {
    final isSelected = _selectedSeller == s;
    final currentZoom = _mapController.camera.zoom;
    final isZoomedOut = currentZoom < 13.0;
    
    // Dynamic Dot Size
    // Zoom 3 -> ~4px. Zoom 13 -> ~18px.
    final dotSize = math.max(4.0, (currentZoom - 2) * 1.6);
    final cappedSize = math.min(22.0, dotSize);
    
    // Construct full image URL if needed (for shop profile picture)
    // Skip default placeholder images
    String? imageUrl = s.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }
    if (_isDefaultPlaceholder(imageUrl)) {
      imageUrl = null;
    }
    
    // Construct full category image URL if needed
    // Skip default placeholder images
    String? categoryImageUrl = s.categoryImageUrl;
    if (categoryImageUrl != null && !categoryImageUrl.startsWith('http')) {
      categoryImageUrl = 'https://www.jayantslist.com$categoryImageUrl';
    }
    if (_isDefaultPlaceholder(categoryImageUrl)) {
      categoryImageUrl = null;
    }

    return Marker(
      point: position ?? s.position,
      width: isZoomedOut ? cappedSize + 16 : 150, // Slightly larger bounding box for touch target
      height: isZoomedOut ? cappedSize + 16 : 100,
      alignment: isZoomedOut ? Alignment.center : Alignment.bottomCenter,
      child: isZoomedOut 
        ? GestureDetector(
              onTap: () {
                _mapController.move(s.position, 15.0); // Zoom in on tap
                setState(() {
                  _selectedSeller = s;
                });
              },
              child: Center(
                child: Container(
                  width: cappedSize,
                  height: cappedSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A), // Black
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                ),
              ),
            )
        : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            SizedBox(
              width: 140,
              height: 54,
              child: InkWell(
                onTap: () async {
                  final isSaved = _savedBiz.contains(s.name);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SellerDetailScreen(
                        seller: s,
                        isSaved: isSaved,
                        userPosition: _currentPosition,
                      ),
                    ),
                  );
                  _loadSavedBiz();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null 
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                    style: GoogleFonts.lato(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                style: GoogleFonts.lato(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                    ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _clean(s.name),
                            style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _clean(s.category),
                            style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF333333)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Text('More Info', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSeller = s;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDDC39),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Show category image if available, otherwise show storefront icon
                child: (categoryImageUrl != null && categoryImageUrl.isNotEmpty && !categoryImageUrl.endsWith('.svg')) // explicit svg check just in case
                    ? ClipOval(
                        child: Image.network(
                          categoryImageUrl,
                          width: 18,
                          height: 18,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.storefront,
                              size: 14,
                              color: Color(0xFF1A1A1A),
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.storefront,
                        size: 14,
                        color: Color(0xFF1A1A1A),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper to build marker at a custom position (for handling overlapping markers)
  Marker _buildSellerMarkerAt(Seller s, LatLng position) {
    final isSelected = _selectedSeller == s;
    
    // Construct full image URL if needed (for shop profile picture)
    // Skip default placeholder images
    String? imageUrl = s.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }
    if (_isDefaultPlaceholder(imageUrl)) {
      imageUrl = null;
    }
    
    // Construct full category image URL if needed
    // Skip default placeholder images
    String? categoryImageUrl = s.categoryImageUrl;
    if (categoryImageUrl != null && !categoryImageUrl.startsWith('http')) {
      categoryImageUrl = 'https://www.jayantslist.com$categoryImageUrl';
    }
    if (_isDefaultPlaceholder(categoryImageUrl)) {
      categoryImageUrl = null;
    }

    return Marker(
      point: position, // Use provided position (may be offset)
      width: 150,
      height: 100,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            SizedBox(
              width: 140,
              height: 54,
              child: InkWell(
                onTap: () async {
                  final isSaved = _savedBiz.contains(s.name);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SellerDetailScreen(
                        seller: s,
                        isSaved: isSaved,
                        userPosition: _currentPosition,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile picture with proper error handling
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE5E7EB),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: (imageUrl != null && imageUrl.isNotEmpty)
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                      style: GoogleFonts.lato(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.lato(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _clean(s.name),
                              style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _clean(s.category),
                              style: GoogleFonts.lato(fontSize: 9, color: const Color(0xFF4A4A4A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Text('More Info', style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSeller = s;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCDDC39),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Show category image if available, otherwise show storefront icon
                child: (categoryImageUrl != null && categoryImageUrl.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          categoryImageUrl,
                          width: 18,
                          height: 18,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.storefront,
                              size: 14,
                              color: Color(0xFF1A1A1A),
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.storefront,
                        size: 14,
                        color: Color(0xFF1A1A1A),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _fetchApiCategories() async {
    if (_apiCatsLoading) return;
    _apiCatsLoading = true;
    _apiCatsError = null;
    setState(() {});
    try {
      final list = await ApiService().getCategories();
      _apiCatCodes.clear();
      _apiCatIds.clear();
      _apiCatImages.clear();
      _allRawCategories = List<Map<String, dynamic>>.from(list);
      final names = <String>[];
      
      for (final e in list) {
        final name = e['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        
        final h = e['hcode']?.toString();
        // Categorize logic: Root categories have no dots in hcode (e.g. "1", "2"). 
        // Subcategories have dots (e.g. "1.2").
        // We only add roots to the main list for now.
        final isRoot = (h != null && !h.contains('.'));
        
        if (isRoot) {
           names.add(name);
        }

        if (h != null && h.isNotEmpty) {
          _apiCatCodes[_norm(name)] = h;
        }
        if (e['id'] != null) {
          _apiCatIds[_norm(name)] = int.tryParse(e['id'].toString()) ?? 0;
        }
        if (e['picture_url'] != null) {
           _apiCatImages[_norm(name)] = e['picture_url'].toString();
        }
      }
      _apiCategories = names;
      print('✅ Categories loaded: ${names.length} roots, ${_apiCatIds.length} IDs, ${_apiCatCodes.length} HCodes, ${_allRawCategories.length} raw');
      try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_categories', json.encode(names));
          await prefs.setString('cached_categories_v2', json.encode(list));
      } catch (_) {}
    } catch (_) {
      _apiCatsError = 'Unable to fetch categories';
    }
    _apiCatsLoading = false;
    setState(() {});
  }

  Future<void> _fetchGridCategories({int? parentId, String? parentName}) async {
    if (_gridCatsLoading) return;
    _gridCatsLoading = true;
    setState(() {});
    
    try {
      final list = await ApiService().getCategories(parentId: parentId);
      final mapped = list.map((e) => {
        'id': e['id'],
        'name': e['name'],
      }).toList();

      if (parentId == null) {
        // Update API categories for filter drawer as well
        _apiCategories = mapped.map((e) => e['name'].toString()).toList();
        _currentGridParentId = null;
        _currentGridParentName = null;
        // Also cache names
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_categories', json.encode(_apiCategories));
        } catch (_) {}
      } else {
        _currentGridParentId = parentId;
        _currentGridParentName = parentName;
      }
      
      _gridCategories = mapped;
    } catch (e) {
      print('Error loading grid categories: $e');
    }
    
    _gridCatsLoading = false;
    setState(() {});
  }

  Future<void> _loadArtisansNearby() async {
    try {
      // If _distanceLimitKm is null (User selected "All"), we use a global radius (20,000 km)
      final double searchRadius = (_distanceLimitKm ?? 20000.0) * 1000;
      print('🔍 Loading artisans nearby... distance: ${_distanceLimitKm == null ? "Unlimited" : "$_distanceLimitKm km"}');
      print('📍 Current position: $_currentPosition');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Try /sellers/nearby-sellers first (Authenticated)
      List<dynamic> entries = [];
      String? errorMessage;
      
      try {
        // Update location first as per API requirement
        await ApiService().updateLocation(_currentPosition.latitude, _currentPosition.longitude);

        // Collect HCodes for optimized fetching, and list of names for fallback search
        final Map<String, String> categoryHcodes = {}; // hcode -> category name
        final List<String> categoriesNeedsSearch = [];

        if (_selectedCategories.isNotEmpty) {
          for (final cat in _selectedCategories) {
            // First try main category codes map
            String? hcode = _apiCatCodes[_norm(cat)];
            
            // If not found, search in loaded sellers for this category
            if (hcode == null) {
              for (final s in _sellers) {
                if (s.category.toLowerCase().trim() == cat.toLowerCase().trim() && s.hcode != null) {
                  hcode = s.hcode;
                  // Cache it for future use
                  _apiCatCodes[_norm(cat)] = hcode!;
                  if (s.categoryId != null) {
                    _apiCatIds[_norm(cat)] = s.categoryId!;
                  }
                  break;
                }
              }
            }
            
            // Also try static fallback
            if (hcode == null) {
              final staticMatch = _allRawCategories.firstWhere(
                (e) => _norm(e['name'].toString()) == _norm(cat), orElse: () => {});
              if (staticMatch.isNotEmpty) hcode = staticMatch['hcode']?.toString();
            }
            
            if (hcode != null && hcode.isNotEmpty) {
              categoryHcodes[hcode] = cat;
            } else {
              // No HCode found? Mark for fallback search
              categoriesNeedsSearch.add(cat);
            }
          }
        }
        
        // Make API calls for all selected categories (or one call with no filter if none selected)
        if (categoryHcodes.isEmpty && categoriesNeedsSearch.isEmpty) {
          // No categories selected - fetch all nearby sellers
          entries = await ApiService().getNearbySellers(
            maxDistance: searchRadius,
          );
          print('✅ Fetched ${entries.length} sellers (no category filter)');
        } else {
          // Multiple categories selected - fetch for each and merge
          print('📌 selection: $_selectedCategories');
          print('📌 hcodes map: $categoryHcodes');
          print('📌 needs search: $categoriesNeedsSearch');
          
          final List<Future<List<dynamic>>> futures = [];
          
          // 1. Fetch by HCode (with Per-Category Fallback to Search)
          for (final hcode in categoryHcodes.keys) {
             final catName = categoryHcodes[hcode]!;
             futures.add(Future(() async {
                try {
                  print('🌐 Requesting HCode: $hcode for "$catName"');
                  var result = await ApiService().getNearbySellers(
                    maxDistance: searchRadius,
                    catHcode: hcode,
                  );
                  
                  if (result.isNotEmpty) {
                    print('✅ HCode $hcode returned ${result.length} sellers');
                    return result;
                  } else {
                    // Start Per-Category Fallback: If strict ID returns 0, try text search for this category
                    print('⚠️ HCode $hcode returned 0. 🔁 Trying fallback search for "$catName"...');
                    try {
                       final searchResult = await ApiService().search(catName, maxDistance: searchRadius);
                       final rawShops = searchResult['shops'] ?? [];
                       
                       // Post-Filter: Ensure the result actually relates to the category we searched for
                       // This prevents "Goldsmithing Techniques" search from returning generic "Tailors" if the API is fuzzy.
                       final List<dynamic> filteredShops = [];
                       for (final shop in rawShops) {
                          String sCat = '';
                          if (shop['category'] != null) {
                             if (shop['category'] is Map) sCat = shop['category']['name']?.toString() ?? '';
                             else sCat = shop['category'].toString();
                          }
                          // Also check service_name or description if category is generic
                          final String sDesc = (shop['description'] ?? '').toString();
                          final String sName = (shop['shop_name'] ?? shop['name'] ?? '').toString();
                          
                          // Loose matching: if category name, title, or description contains the query
                          if (sCat.toLowerCase().contains(catName.toLowerCase()) || 
                              sDesc.toLowerCase().contains(catName.toLowerCase()) ||
                              sName.toLowerCase().contains(catName.toLowerCase())) {
                              filteredShops.add(shop);
                          }
                       }
                       
                       print('✅ Fallback Search "$catName" returned ${rawShops.length} raw -> ${filteredShops.length} filtered sellers');
                       return filteredShops;
                    } catch (e2) {
                       print('❌ Fallback search for "$catName" also failed: $e2');
                       return <dynamic>[];
                    }
                  }
                } catch (e) {
                  print('⚠️ Failed to fetch for hcode $hcode: $e');
                  // On error, also try fallback
                   try {
                       print('🔁 Error fallback: Searching for "$catName"...');
                       final searchResult = await ApiService().search(catName, maxDistance: searchRadius);
                       final shops = searchResult['shops'] ?? [];
                       return shops;
                    } catch (e3) {
                       return <dynamic>[];
                    }
                }
             }));
          }
          
          // 2. Fetch by Search (Fallback for missing HCode)
          for (final catQuery in categoriesNeedsSearch) {
             futures.add(Future(() async {
                try {
                  print('🌐 Requesting Search: "$catQuery"');
                  final searchResult = await ApiService().search(catQuery, maxDistance: searchRadius);
                  final shops = searchResult['shops'] ?? [];
                  print('✅ Search "$catQuery" returned ${shops.length} sellers');
                  return shops;
                } catch (e) {
                  print('⚠️ Failed to search for "$catQuery": $e');
                  return <dynamic>[];
                }
             }));
          }
          
          final results = await Future.wait(futures);
          
          // Merge all results
          for (final result in results) {
            entries.addAll(result);
          }
          print('✅ Total merged sellers: ${entries.length}');
        }
        
        /* 
        // Global Fallback is now DEPRECATED because we have per-category fallback with strict filtering.
        // Keeping this enabled causes "junk" results (like Tailors) to appear when searching for specific EMPTY categories,
        // because the global fallback doesn't apply the strict name match filter.
        
        if (entries.isEmpty && _selectedCategories.isNotEmpty) {
          try {
            print('🔁 Fallback: Using search API for all categories...');
            for (final cat in _selectedCategories) {
              final searchResult = await ApiService().search(cat, maxDistance: (_distanceLimitKm ?? 50.0) * 1000);
              final shops = searchResult['shops'] ?? [];
              entries.addAll(shops);
              print('🔁 Fallback search for "$cat" returned ${shops.length} shops');
            }
          } catch (e3) {
            print('❌ Fallback search failed: $e3');
          }
        } 
        */
      } catch (e) {
        print('⚠️ Failed to load nearby sellers (Authenticated): $e');
        errorMessage = e.toString();
        print('🔄 Falling back to search API...');
        try {
          // Try search with selected category name as query if available
          final query = _selectedCategories.isNotEmpty ? _selectedCategories.first : '';
          final searchResult = await ApiService().search(query, maxDistance: (_distanceLimitKm ?? 50.0) * 1000);
          entries = searchResult['shops'] ?? [];
          print('✅ Search API returned ${entries.length} shops');
          errorMessage = null; // Clear error if search succeeds
        } catch (e2) {
          print('❌ Failed to load sellers via search: $e2');
          errorMessage = e2.toString();
          // Note: /artisans endpoint returns 404, so we don't use it as fallback
          print('⚠️ All seller APIs failed. Backend may be experiencing issues.');
        }
      }
      
      final d = Distance();
      final List<Seller> artisans = [];
      
      for (final e in entries) {
        // Parse location
        double? lat;
        double? lon;
        
        // Handle various location formats
        if (e['latitude'] != null && e['longitude'] != null) {
          lat = double.tryParse(e['latitude']?.toString() ?? '');
          lon = double.tryParse(e['longitude']?.toString() ?? '');
        } else if (e['lat'] != null && e['lon'] != null) {
          lat = double.tryParse(e['lat']?.toString() ?? '');
          lon = double.tryParse(e['lon']?.toString() ?? '');
        }
        
        if (lat == null || lon == null) continue;
        
        final pos = LatLng(lat, lon);
        // API already filters by distance, no need to re-filter locally
        // This was causing mismatch since _currentPosition might differ from backend's stored location
        
        // Parse Name
        String name = (e['shop_name'] ?? e['business_name'] ?? e['artisan_name'] ?? e['name'] ?? '').toString();
        if (name.isEmpty) name = 'Shop';
        
        // Parse Category details
        String cat = 'Service';
        String? categoryImageUrl;
        int? catId;
        String? catHcode;
        
        if (e['categories'] != null && (e['categories'] as List).isNotEmpty) {
          // Authenticated API format
          final c = e['categories'][0];
          cat = c['name']?.toString() ?? 'Service';
          categoryImageUrl = c['picture_url']?.toString();
          if (c['id'] != null) catId = int.tryParse(c['id'].toString());
          catHcode = c['hcode']?.toString();
        } else if (e['service_category'] != null) {
          // Public API format: service_category object
          final sc = e['service_category'];
          if (sc is Map) {
             cat = sc['serviceCategoryName']?.toString() ?? 'Service';
             categoryImageUrl = sc['picture_url']?.toString();
             if (sc['id'] != null) catId = int.tryParse(sc['id'].toString());
             catHcode = sc['hcode']?.toString();
          }
        } else {
          final rawCat = e['category'];
          if (rawCat is Map) {
            cat = rawCat['name']?.toString() ?? 'Service';
            categoryImageUrl = rawCat['picture_url']?.toString();
            if (rawCat['id'] != null) catId = int.tryParse(rawCat['id'].toString());
            catHcode = rawCat['hcode']?.toString();
          } else {
            cat = (rawCat ?? e['service_name'] ?? 'Service').toString();
          }
        }
        
        // Do not hard-filter locally by category; rely on backend filtering
        
        // Parse ID
        int? id;
        if (e['id'] != null) id = int.tryParse(e['id'].toString());
        if (id == null && e['seller_shop_id'] != null) id = int.tryParse(e['seller_shop_id'].toString());
        if (id == null && e['shop_id'] != null) id = int.tryParse(e['shop_id'].toString());

        // Parse additional details
        String? phone = (e['contact_no'] ?? e['mobile_number'] ?? e['phone_number'] ?? e['phone'] ?? e['contact_number'])?.toString();
        String? desc = (e['description'] ?? e['about'] ?? e['bio'])?.toString();
        String? imageUrl = (e['picture_url'] ?? e['profile_image_url'] ?? e['image_url'] ?? e['photo'] ?? e['image'])?.toString();

        artisans.add(Seller(
          id: id, 
          name: name, 
          category: cat, 
          position: pos,
          imageUrl: imageUrl,
          phoneNumber: phone,
          description: desc,
          categoryImageUrl: categoryImageUrl,
          categoryId: catId,
          hcode: catHcode,
        ));
      }
      
      // Remove duplicates based on ID or Name+Location
      final uniqueArtisans = <String, Seller>{};
      for (final a in artisans) {
        final key = a.id != null ? 'id_${a.id}' : '${a.name}_${a.position.latitude}_${a.position.longitude}';
        uniqueArtisans[key] = a;
      }
      
      final finalSellers = uniqueArtisans.values.toList();

      finalSellers.sort((a, b) => d.as(LengthUnit.Meter, _currentPosition, a.position)
          .compareTo(d.as(LengthUnit.Meter, _currentPosition, b.position)));
          
      _sellers = finalSellers;
      print('✅ Loaded ${_sellers.length} unique sellers after filtering (from ${entries.length} API entries)');
      
      // Force UI update
      if (mounted) setState(() {});
      
      // Show error notification if backend failed and no sellers found
      if (_sellers.isEmpty && errorMessage != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to load sellers',
                    style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFF5252),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 200,
                left: 20,
                right: 20,
              ),
            ),
          );
        });
      }
    } catch (e, stackTrace) {
      print('Error loading artisans: $e');
      print('Stack trace: $stackTrace');
      _sellers = [];
      
      // Show error toast
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error loading sellers',
                style: GoogleFonts.lato(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFFF5252),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 180,
                left: 20,
                right: 20,
              ),
            ),
          );
        });
      }
    }
  }

  Future<void> _loadSellersForCategories() async {
    if (_sellersLoading) return;
    
    setState(() {
      _sellersLoading = true;
      // Don't clear sellers immediately to prevent map flicker
      // _sellers = []; 
    });

    final lat = _currentPosition.latitude;
    final lon = _currentPosition.longitude;
    final cats = _selectedCategories.isEmpty ? {'shop', 'amenity'} : _selectedCategories;

    await _loadArtisansNearby();
    
    if (mounted) {
      setState(() {
        _sellersLoading = false;
        _lastFetchedCategories = Set<String>.from(_selectedCategories);
      });
      
      // Only fit to sellers if we have results and we are in map view
      /* 
      // Disabled Auto-Fit to prevent map jumping when filters change (User Request).
      if (_sellers.isNotEmpty && _locationViewIndex == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final sellers = _nearbySellers(categories: _selectedCategories.isNotEmpty ? _selectedCategories : null);
          _fitToSellers(sellers);
        });
      }
      */
    }
  }

  @override
  void initState() {
    super.initState();
    _locationViewIndex = widget.initialLocationViewIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: const [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    _checkLocationPermission();
    _loadRole();
    _loadCachedCategories();
    _fetchApiCategories(); // Fetch fresh categories to populate ID/HCode maps
    _loadSavedBiz();
    _fetchGridCategories();
    // Load sellers when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSellersForCategories();
      // Don't move map controller here - it's not initialized yet
      // Map will auto-center to initialCenter in MapOptions
      setState(() {});
    });
  }

  Future<void> _loadSavedBiz() async {
    final savedSellers = await UserPreferences().getSavedSellers();
    setState(() {
      _savedBiz = savedSellers.map((s) => s.name).toList();
    });
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'user';
    setState(() {
      _isSeller = role.toLowerCase() == 'seller';
    });
  }

  Future<void> _loadCachedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    // Try v2 (full objects) first
    final cachedV2 = prefs.getString('cached_categories_v2');
    if (cachedV2 != null) {
       try {
          final List<dynamic> list = json.decode(cachedV2);
          final names = <String>[];
          _apiCatCodes.clear();
          _apiCatIds.clear();
          _apiCatImages.clear();
          _allRawCategories = List<Map<String, dynamic>>.from(list);
          
          for (final e in list) {
             final name = e['name']?.toString() ?? '';
             if (name.isEmpty) continue;
             
             final h = e['hcode']?.toString();
             final isRoot = (h != null && !h.contains('.'));
             if (isRoot) names.add(name);
             
             if (h != null && h.isNotEmpty) _apiCatCodes[_norm(name)] = h;
             if (e['id'] != null) _apiCatIds[_norm(name)] = int.tryParse(e['id'].toString()) ?? 0;
             if (e['picture_url'] != null) _apiCatImages[_norm(name)] = e['picture_url'].toString();
          }
           setState(() {
             _apiCategories = names;
           });
           return; 
       } catch (_) {}
    }

    // Fallback to v1 (names only)
    final cached = prefs.getString('cached_categories');
    if (cached != null) {
      try {
        final List<dynamic> arr = json.decode(cached);
        setState(() {
          _apiCategories = arr.map((e) => e.toString()).toList();
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _locationDebounce?.cancel();
    _sellerLoadDebounce?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: const [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getPlaceSuggestions(String input) async {
    if (input.isEmpty) return [];
    
    try {
      // Using OpenStreetMap Nominatim API (free, no API key needed)
      final String baseUrl = 'https://nominatim.openstreetmap.org/search';
      final String request = '$baseUrl?q=$input&format=json&addressdetails=1&limit=5&countrycodes=in';
      
      final response = await http.get(
        Uri.parse(request),
        headers: {
          'User-Agent': 'JayantsList/1.0',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((place) {
          return {
            'description': place['display_name'] ?? '',
            'lat': place['lat'] ?? '',
            'lon': place['lon'] ?? '',
            'place_id': place['place_id']?.toString() ?? '',
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
    
    return [];
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() {
        _currentLocation = 'Location not enabled';
      });
      // Show location permission popup after a short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showLocationPermissionPopup();
        }
      });
    }
  }

  void _showLocationSearchPopup() {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredLocations = [];
    bool isLoading = false;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: MediaQuery.of(context).padding.bottom + 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                'Change Location',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              
              // Subtitle
              Text(
                'Search and select your location',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: const Color(0xFF4A4A4A),
                ),
              ),
              const SizedBox(height: 18),
              
              // Search Field
              TextField(
                controller: searchController,
                onChanged: (value) async {
                  _locationDebounce?.cancel();
                  _locationDebounce = Timer(const Duration(milliseconds: 400), () async {
                    if (value.isEmpty) {
                      setModalState(() {
                        filteredLocations = [];
                        isLoading = false;
                      });
                    } else {
                      setModalState(() { isLoading = true; });
                      final suggestions = await _getPlaceSuggestions(value);
                      setModalState(() {
                        filteredLocations = suggestions;
                        isLoading = false;
                      });
                    }
                  });
                },
                style: GoogleFonts.lato(
                  color: const Color(0xFF1A1A1A),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter city, state or country',
                  hintStyle: GoogleFonts.lato(
                    color: const Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF4A4A4A),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: const Color(0xFF1A1A1A).withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFCDDC39),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              
              // Loading Indicator
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCDDC39)),
                      ),
                    ),
                  ),
                ),
              
              // Suggestions List
              if (!isLoading && filteredLocations.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1A1A1A).withOpacity(0.1),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredLocations.length,
                    itemBuilder: (context, index) {
                      final location = filteredLocations[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on,
                          size: 18,
                          color: Color(0xFFCDDC39),
                        ),
                        title: Text(
                          location['description'] ?? '',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        onTap: () {
                          final lat = double.tryParse(location['lat'] ?? '0') ?? 0;
                          final lon = double.tryParse(location['lon'] ?? '0') ?? 0;
                          
                          setState(() {
                            _currentLocation = location['description'] ?? '';
                            _currentPosition = LatLng(lat, lon);
                          });
                          
                          _mapController.move(_currentPosition, 14.0);
                          
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 18),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(
                            color: Color(0xFF1A1A1A),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                      onPressed: () async {
                        final input = searchController.text.trim();
                        if (input.isEmpty) return;
                        try {
                          final locs = await locationFromAddress(input);
                          if (locs.isNotEmpty) {
                            final loc = locs.first;
                            setState(() {
                              _currentPosition = LatLng(loc.latitude, loc.longitude);
                              _currentLocation = input;
                            });
                            _mapController.move(_currentPosition, 14.0);
                            await _loadSellersForCategories();
                          }
                        } catch (_) {
                          setState(() { _currentLocation = input; });
                        }
                        Navigator.pop(context);
                      },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCDDC39),
                          foregroundColor: const Color(0xFF1A1A1A),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          'Set Location',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
          );
        },
      ),
    );
  }

  void _showLocationPermissionPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F0),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 16.0,
          bottom: MediaQuery.of(context).padding.bottom + 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCDDC39).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                size: 32,
                color: Color(0xFFCDDC39),
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Enable Location',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              'Allow access to your location to find nearby listings and sellers',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: const Color(0xFF4A4A4A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentLocation = 'Location not enabled';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(
                          color: Color(0xFF1A1A1A),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        'Not Now',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _requestLocationPermission();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCDDC39),
                        foregroundColor: const Color(0xFF1A1A1A),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        'Allow',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Future<void> _requestLocationPermission() async {
    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        bool requested = await Geolocator.openLocationSettings();
        if (!requested) {
           _showSnackbar('Location services are disabled. Please enable them.', action: 'Settings', onTap: Geolocator.openLocationSettings);
        }
      }
      setState(() {
        _currentLocation = 'Location services disabled';
      });
      return;
    }

    // 2. Check current status
    var status = await Permission.locationWhenInUse.status;
    
    if (status.isGranted) {
      await _getCurrentLocation();
      return;
    }
    
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSnackbar(
          'Location permission is permanently denied. Please enable it in settings.',
          action: 'Settings',
          onTap: openAppSettings,
        );
      }
      setState(() {
        _currentLocation = 'Location permission denied';
      });
      return;
    }

    // 3. Request permission
    // Note: On iOS, if the user has previously denied permission, requesting it again
    // might immediately return permanentlyDenied without showing the dialog.
    status = await Permission.locationWhenInUse.request();
    
    if (status.isGranted) {
      await _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSnackbar(
          'Location permission is permanently denied. Please enable it in settings.',
          action: 'Settings',
          onTap: openAppSettings,
        );
      }
      setState(() {
        _currentLocation = 'Location permission denied';
      });
    } else {
      // Denied but not permanently (e.g. "Don't Allow" this time)
      setState(() {
        _currentLocation = 'Location permission denied';
      });
    }
  }

  void _showSnackbar(String message, {String? action, VoidCallback? onTap}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
        action: action != null ? SnackBarAction(label: action, textColor: Colors.white, onPressed: onTap ?? () {}) : null,
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _currentLocation = 'Getting location...';
      });

      Position? position;
      // Auto-retry mechanism (2 attempts)
      for (int i = 0; i < 2; i++) {
         try {
           // High accuracy
           position = await Geolocator.getCurrentPosition(
             desiredAccuracy: LocationAccuracy.high,
             timeLimit: const Duration(seconds: 10),
           );
         } catch (e) {
             print('Attempt ${i+1} high accuracy failed: $e');
             // Fallback to last known
             try {
               position = await Geolocator.getLastKnownPosition();
             } catch(_) {}
         }
         
         if (position != null) break;
         
         // Medium accuracy fallback if high failed and last known failed
         try {
           position = await Geolocator.getCurrentPosition(
             desiredAccuracy: LocationAccuracy.medium,
             timeLimit: const Duration(seconds: 10),
           );
         } catch(e) {
             print('Attempt ${i+1} medium accuracy failed: $e');
         }
         
         if (position != null) break;
         
         // If we are retrying, wait a bit
         if (i == 0) await Future.delayed(const Duration(seconds: 2));
      }

      if (position == null) {
        // Silently handle or keep previous location if available? 
        // User said: "Retry kr do...". If it fails after 2 tries, we must show something or just keep "Getting location..."? 
        // Throwing exception shows "Unable to retrieve...". 
        // But let's try 3rd time? No user said 2nd time works.
        // If null after retries, throw.
        throw Exception('Unable to retrieve location');
      }
      
      final validPosition = position!;
      setState(() {
        _currentPosition = LatLng(validPosition.latitude, validPosition.longitude);
        _mapLoading = false;
      });
      
      // Update location on backend FIRST
      try {
        print('Updating location on backend: ${position.latitude}, ${position.longitude}');
        await ApiService().updateLocation(position.latitude, position.longitude);
        print('Location updated successfully');
      } catch (e) {
        print('Failed to update location on backend: $e');
        
        // Check if session expired (401/403 errors)
        if (e.toString().contains('Invalid or Expired Access Token') || 
            e.toString().contains('Session expired')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Session expired. Redirecting to login...',
                  style: GoogleFonts.lato(fontSize: 13),
                ),
                backgroundColor: const Color(0xFFFF5252),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 180,
                  left: 20,
                  right: 20,
                ),
              ),
            );
            
            // Navigate to login after short delay
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            });
          }
          return; // Stop processing
        }
        // Even if update fails for other reasons, we might still want to try loading sellers
      }
      
      _mapController.move(_currentPosition, 14.0);
      
      // NOW load sellers, after location is potentially updated
      await _loadSellersForCategories(); 
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String location = '';
        
        if (place.locality != null && place.locality!.isNotEmpty) {
          location = place.locality!;
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          if (location.isNotEmpty) {
            location += ', ${place.administrativeArea!}';
          } else {
            location = place.administrativeArea!;
          }
        }
        if (place.country != null && place.country!.isNotEmpty) {
          if (location.isNotEmpty && !location.contains(place.country!)) {
            location += ', ${place.country!}';
          } else if (location.isEmpty) {
            location = place.country!;
          }
        }
        
        setState(() {
          _currentLocation = location.isNotEmpty ? location : 'Unknown location';
        });
      }
    } catch (e) {
      setState(() {
        _currentLocation = 'Tap Change to set location';
      });
      // Offer the permission/location chooser to help user fix quickly
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () => _showLocationPermissionPopup());
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: (_selectedIndex == 3) ? null : AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // For Android (dark icons)
          statusBarBrightness: Brightness.light, // For iOS (dark icons)
          systemNavigationBarColor: Color(0xFFFAF7F0), // Match app background
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        title: Text(
          'Jayantslist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: const Color(0xFFFAF7F0),
        surfaceTintColor: Colors.transparent, // Remove Material 3 tint
        scrolledUnderElevation: 0, // Remove elevation color change on scroll
        elevation: 0,
        toolbarHeight: 44,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            /*
            child: InkWell(
              onTap: _showNotifications,
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.notifications_none,
                      size: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFAF7F0), width: 1),
                      ),
                      child: Text(
                        '$_notificationCount',
                        style: GoogleFonts.lato(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            */
          ),
        ],
      ),
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
        child: Column(
          children: [
            if (_selectedIndex == 1)
            const SizedBox(height: 12),
            // Location Bar
            if (_selectedIndex != 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF1A1A1A).withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Location Icon
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: Color(0xFFCDDC39),
                  ),
                  const SizedBox(width: 6),
                  
                  // Location Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Location',
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentLocation,
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: const Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // GPS Icon Button
                  GestureDetector(
                    onTap: () async {
                      final status = await Permission.location.status;
                      if (status.isGranted) {
                        _getCurrentLocation();
                      } else {
                        _showLocationPermissionPopup();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDDC39).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        size: 18,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Change Button
                  GestureDetector(
                    onTap: () async {
                      final status = await Permission.location.status;
                      if (status.isGranted) {
                        _showLocationSearchPopup();
                      } else {
                        _showLocationPermissionPopup();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFCDDC39),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Change',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedIndex == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: _showFilterDrawer,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDDC39).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune, color: Color(0xFF1A1A1A), size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                          if (!mounted) return;
                          setState(() => _searchQuery = v.trim());
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search nearby sellers',
                        hintStyle: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF6B7280)),
                        prefixIcon: const Icon(Icons.search_outlined, size: 18, color: Color(0xFF6B7280)),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFFCDDC39), width: 1.4),
                        ),
                      ),
                      style: GoogleFonts.lato(fontSize: 12),
                    ),
                  ),
                  // Distance selector removed
                ],
              ),
            ),
            // Swappable page content; profile hides top bars
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                // Keep incoming/outgoing children aligned to top instead of center
                layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final bool isIncoming = child.key == ValueKey<int>(_selectedIndex);
                  final bool isForward = _selectedIndex >= _previousIndex;

                  final Animatable<Offset> inTween = Tween<Offset>(
                    begin: isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOut));

                  final Animatable<Offset> outTween = Tween<Offset>(
                    begin: isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeIn));

                  final Animation<Offset> offsetAnimation = isIncoming
                      ? animation.drive(inTween)
                      : animation.drive(outTween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: _buildPageContent(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 0),
        child: Container(
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F0),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: CustomPaint(
              painter: _CurvedNavBarPainter(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(1, Icons.home_outlined, 'Home'),
                  _buildNavItem(2, Icons.grid_view, 'Categories'),
                  _buildNavItem(3, Icons.person_outline, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF7F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDDC39).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCDDC39), width: 1.2),
                      ),
                      child: Text(
                        '$_notificationCount new',
                        style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.notifications, size: 18, color: Color(0xFF1A1A1A)),
                    title: Text(
                      _notifications[index],
                      style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Builds page content based on selected index while keeping topbar/location fixed
  Widget _buildPageContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildMapCard();
      case 1:
        return _buildLocationTab();
      case 2:
        return _buildCategoriesGrid();
      case 3:
        return const ProfileScreen();
      default:
        return _buildMapCard();
    }
  }

  // Extracted Map card content (initial view for index 0)
  Widget _buildMapCard() {
    return SafeArea(
      left: false,
      right: false,
      top: false,
      bottom: true,
      minimum: EdgeInsets.only(bottom: _navBarPadding(context)),
      child: SizedBox.expand(
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 14.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (_, __) { if (_selectedSeller != null) setState(() => _selectedSeller = null); },
              onMapEvent: (event) { 
                if (_selectedSeller != null) setState(() => _selectedSeller = null); 
              },
              onPositionChanged: (position, hasGesture) {
                setState(() {}); // Rebuild for zoom-dependent marker changes
                if (!hasGesture) return;
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  _updateDistanceBasedOnMapBounds();
                });
              },
              interactionOptions: const InteractionOptions(
                enableScrollWheel: true,
                enableMultiFingerGestureRace: true,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.jayantslist',
              ),
              // User's current location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition,
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location,
                          size: 28,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Seller markers from API data
              Builder(
                builder: (context) {
                  final sellers = _nearbySellers(
                    categories: _selectedCategories.isNotEmpty ? _selectedCategories : null,
                  );
                  print('🗺️ Rendering ${sellers.length} markers on map (from ${_sellers.length} sellers)');
                  
                  // Track positions to detect overlaps and add small offset
                  final Map<String, int> positionCount = {};
                  final List<Marker> markers = [];
                  
                  for (int i = 0; i < sellers.length; i++) {
                    final s = sellers[i];
                    final posKey = '${s.position.latitude.toStringAsFixed(4)}_${s.position.longitude.toStringAsFixed(4)}';
                    final count = positionCount[posKey] ?? 0;
                    positionCount[posKey] = count + 1;
                    
                    // Add small offset for overlapping markers
                    LatLng adjustedPos = s.position;
                    if (count > 0) {
                      // Spiral offset for overlapping markers
                      final angle = count * 0.8;
                      final radius = 0.0008 * count; // ~80 meters per step
                      adjustedPos = LatLng(
                        s.position.latitude + radius * math.cos(angle),
                        s.position.longitude + radius * math.sin(angle),
                      );
                    }
                    
                    markers.add(_buildSellerMarker(s, position: adjustedPos));
                  }
                  
                  return MarkerLayer(markers: markers);
                },
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                _zoomButton(Icons.add, () {
                  final currentZoom = _mapController.camera.zoom;
                  final newZoom = math.min(18.0, currentZoom + 1);
                  _mapController.move(_mapController.camera.center, newZoom);
                  // Explicitly trigger update since onPositionChanged ignores non-gestures
                  Future.delayed(const Duration(milliseconds: 300), _updateDistanceBasedOnMapBounds);
                }),
                const SizedBox(height: 8),
                _zoomButton(Icons.remove, () {
                  final currentZoom = _mapController.camera.zoom;
                  final newZoom = math.max(3.0, currentZoom - 1);
                  _mapController.move(_mapController.camera.center, newZoom);
                  // Explicitly trigger update since onPositionChanged ignores non-gestures
                  Future.delayed(const Duration(milliseconds: 300), _updateDistanceBasedOnMapBounds);
                }),
                const SizedBox(height: 8),
                // Center on user location
                _zoomButton(Icons.my_location, () {
                  _mapController.move(_currentPosition, 14.0);
                }),
                const SizedBox(height: 8),
                // Fit to show all sellers
                _zoomButton(Icons.fit_screen, () {
                  /*
                  // Removed auto-fit on map ready to prevent persistent zooming out.
                  // User must manually click "Fit Screen" if they want to see all sellers.
                  if (sellers.isNotEmpty) {
                    _fitToSellers(sellers, isManual: true);
                  }
                  */
                }),
              ],
            ),
          ),
          // Seller count indicator
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, size: 14, color: Color(0xFFCDDC39)),
                  const SizedBox(width: 6),
                  Text(
                    '${_nearbySellers(categories: _selectedCategories.isNotEmpty ? _selectedCategories : null).length} sellers',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mapLoading)
            Container(
              color: const Color(0xFFFAF7F0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCDDC39)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: GoogleFonts.lato(
                        color: const Color(0xFF4A4A4A),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  // Simple placeholder pages for other tabs
  Widget _buildPlaceholderPage({required String title, required String subtitle, required IconData icon}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF6B7280)),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: const Color(0xFF4A4A4A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_gridCatsLoading && _gridCategories.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCDDC39)));
    }
    
    // Init if empty
    if (_gridCategories.isEmpty && _currentGridParentId == null) {
      if (_apiCategories.isNotEmpty) {
          // Sync from cache if available? Or just show retry button
      }
      return Center(
        child: TextButton.icon(
            onPressed: () => _fetchGridCategories(), 
            icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
            label: Text('Load Categories', style: GoogleFonts.lato(color: const Color(0xFF1A1A1A)))
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentGridParentId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InkWell(
              onTap: () => _fetchGridCategories(parentId: null),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 16, color: Color(0xFF1A1A1A)),
                    const SizedBox(width: 8),
                    Text(
                      'Back to ${_currentGridParentName ?? 'All'}',
                      style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, _pageBottomInset(context)),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _gridCategories.length,
            itemBuilder: (context, index) {
              final cat = _gridCategories[index];
              final name = cat['name'].toString();
              final isSelected = _selectedCategories.contains(name);
              
              return InkWell(
                onTap: () {
                   // Toggle logic
                   if (isSelected) {
                     setState(() {
                       _selectedCategories.remove(name);
                     });
                     ScaffoldMessenger.of(context).hideCurrentSnackBar();
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         content: Text('Selection cleared', style: GoogleFonts.lato()),
                         duration: const Duration(milliseconds: 500),
                         behavior: SnackBarBehavior.floating,
                         backgroundColor: const Color(0xFF1A1A1A),
                       ),
                     );
                   } else {
                     ScaffoldMessenger.of(context).hideCurrentSnackBar();
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         content: Text('Opening $name...', style: GoogleFonts.lato()),
                         duration: const Duration(seconds: 1),
                         behavior: SnackBarBehavior.floating,
                         backgroundColor: const Color(0xFF1A1A1A),
                       ),
                     );

                     setState(() {
                       _selectedCategories.clear(); 
                       _selectedCategories.add(name);
                       
                       // Switch to Home tab (Index 1 for Main Home Screen)
                       _selectedIndex = 1; 
                     });
                     _sellerLoadDebounce?.cancel();
                     _sellerLoadDebounce = Timer(const Duration(milliseconds: 350), () async { await _loadSellersForCategories(); });
                   }
                },
                // Optional: Long press to drill down if needed
                onLongPress: () async {
                   setState(() => _gridCatsLoading = true);
                   try {
                       final sub = await ApiService().getCategories(parentId: cat['id']);
                       if (sub.isNotEmpty) {
                           _fetchGridCategories(parentId: cat['id'], parentName: name);
                       } else {
                           setState(() => _gridCatsLoading = false);
                           ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('No subcategories'))
                           );
                       }
                   } catch (e) {
                       setState(() => _gridCatsLoading = false);
                   }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFCDDC39).withOpacity(0.25) : const Color(0xFFFAF7F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFCDDC39) : const Color(0xFF1A1A1A).withOpacity(0.15),
                      width: isSelected ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isSelected ? 0.12 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _gridCatsLoading && _gridCategories.contains(cat) // This logic is flawed, but simple loading is fine
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
 

  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search here',
              hintStyle: GoogleFonts.lato(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
              prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF6B7280), size: 20),
              filled: true,
              fillColor: const Color(0xFFFAF7F0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCDDC39), width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Recently Viewed',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: Stack(
              children: [
                ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _recentlyViewed.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _storyItem(_recentlyViewed[index]);
                  },
                ),
                Positioned(left: 0, top: 0, bottom: 0, child: _scrollGradient(true)),
                Positioned(right: 0, top: 0, bottom: 0, child: _scrollGradient(false)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Saved Biz',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _savedBiz.length,
            itemBuilder: (context, index) {
              return _savedBizGridCard(_savedBiz[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    // Logic to reload sellers if categories changed or placeholders exist should be handled in state management,
    // not directly in the build method to avoid infinite loops and fluctuations.
    // We rely on _loadSellersForCategories being called when filters change.

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: _pageBottomInset(context) + 58.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Nearby Sellers',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1),
                    bottom: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _locationViewIndex = 0),
                        icon: const Icon(Icons.grid_on, size: 16, color: Color(0xFF1A1A1A)),
                        label: Text('List', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          side: const BorderSide(color: Colors.transparent, width: 0),
                          backgroundColor: _locationViewIndex == 0 ? const Color(0xFFCDDC39).withOpacity(0.2) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _locationViewIndex = 1);
                        },
                        icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF1A1A1A)),
                        label: Text('Map', style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          side: const BorderSide(color: Colors.transparent, width: 0),
                          backgroundColor: _locationViewIndex == 1 ? const Color(0xFFCDDC39).withOpacity(0.2) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
          if (_selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 34,
                child: Builder(
                  builder: (context) {
                    // Group categories by Root Category (Level 1 Ancestor)
                    final Map<String, List<String>> branchGroups = {};
                    
                    for (final cat in _selectedCategories) {
                      String? hcode = _apiCatCodes[_norm(cat)];
                      if (hcode == null) {
                         final staticMatch = _allRawCategories.firstWhere(
                            (e) => _norm(e['name'].toString()) == _norm(cat), orElse: () => {});
                         if (staticMatch.isNotEmpty) hcode = staticMatch['hcode']?.toString();
                      }
                      if (hcode == null) {
                         for (final s in _sellers) { if (_norm(s.category) == _norm(cat)) { hcode = s.hcode; break; } }
                      }

                      String key;
                      if (hcode != null && hcode.isNotEmpty && hcode.contains('.')) {
                          // Group by ROOT category (e.g. '1' from '1.7')
                          key = hcode.split('.').first;
                      } else {
                          // Root or unknown or top-level itself
                          key = hcode ?? 'root_${cat}';
                      }
                      branchGroups.putIfAbsent(key, () => []).add(cat);
                    }
                    
                    final sortedKeys = branchGroups.keys.toList();
                    sortedKeys.sort((k1, k2) {
                        final List<String> l1 = branchGroups[k1]!;
                        final List<String> l2 = branchGroups[k2]!;
                        l1.sort(); l2.sort(); // Sort inside for consistent firstName
                        return l1.first.toLowerCase().compareTo(l2.first.toLowerCase());
                    });
                    
                    final List<Widget> breadcrumbChips = [];
                    
                    for (int i = 0; i < sortedKeys.length; i++) {
                      final cats = branchGroups[sortedKeys[i]]!;
                      
                      cats.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      final firstName = cats.first;
                      final extraCount = cats.length - 1;
                      
                      // Build the display text
                      String displayText = firstName;
                      if (extraCount > 0) {
                        displayText = '$firstName +$extraCount';
                      }
                      
                      // Prefix Root if valid root ID
                      final rootId = sortedKeys[i];
                      // Check if key is a simple integer (Root ID)
                      if (int.tryParse(rootId) != null) {
                          final rMatch = _allRawCategories.firstWhere((e) => e['hcode'].toString() == rootId, orElse: () => {});
                          if (rMatch.isNotEmpty) {
                              final rName = rMatch['name'];
                              if (rName != null && _norm(rName) != _norm(firstName)) {
                                  // Ensure we don't repeat if the category IS the root
                                  displayText = '$rName > $displayText';
                              }
                          }
                      }
                      
                      // Add separator before (except first)
                      if (i > 0) {
                        breadcrumbChips.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
                          ),
                        );
                      }
                      
                      // Determine what to open when tapped
                      // Always show subcategories of the first selected category at this level
                      
                      breadcrumbChips.add(
                        InkWell(
                          onTap: () {
                             // Find the root category for the selected item to open the correct tab
                             String targetTab = _apiCategories.isNotEmpty ? _apiCategories.first : 'Artisan';
                             String? hcode = _apiCatCodes[_norm(firstName)];
                             
                             if (hcode == null) {
                                final staticMatch = _allRawCategories.firstWhere(
                                   (e) => _norm(e['name'].toString()) == _norm(firstName), orElse: () => {});
                                if (staticMatch.isNotEmpty) hcode = staticMatch['hcode']?.toString();
                             }
                             
                             if (hcode == null) {
                                 for (final s in _sellers) {
                                    if (_norm(s.category) == _norm(firstName)) {
                                       hcode = s.hcode; break;
                                    }
                                 }
                             }

                             if (hcode != null) {
                                final rootId = hcode.split('.').first;
                                final rootMatch = _allRawCategories.firstWhere(
                                   (e) => e['hcode'].toString() == rootId, orElse: () => {});
                                if (rootMatch.isNotEmpty) {
                                   final rName = rootMatch['name'].toString();
                                   if (_apiCategories.contains(rName)) targetTab = rName;
                                }
                             }
                             
                             _showCombinedFilterSheet(parentCategory: targetTab);
                          },
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: const Color(0xFFCDDC39), width: 1.1),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.label_important_outline, size: 15, color: Color(0xFF6B7280)),
                                const SizedBox(width: 5),
                                Text(displayText, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      children: breadcrumbChips,
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final sellers = _nearbySellers(categories: _selectedCategories.isNotEmpty ? _selectedCategories : null);
              const crossAxisCount = 4;
              const spacing = 10.0;
              const aspect = 1.0;
              final tileWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
              final tileHeight = tileWidth / aspect;
              final safeBottom = MediaQuery.of(context).padding.bottom + 58.0;
              final headerApprox = 120 + (_selectedCategories.isNotEmpty ? 32 : 0);
              final limitHeight = MediaQuery.of(context).size.height - safeBottom - headerApprox;
              final gridHeight = math.max(tileHeight * 3 + spacing * 2, limitHeight);
              if (_locationViewIndex == 0) {
                if (!_sellersLoading && sellers.isEmpty) {
                  return SizedBox(
                    height: gridHeight,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.store_outlined, size: 64, color: const Color(0xFF6B7280).withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No Sellers Found',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try changing filters or expanding the area',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 16),
                        if (_distanceLimitKm != null)
                          SizedBox(
                            height: 38,
                            child: ElevatedButton.icon(
                              onPressed: _expandSearch,
                              icon: const Icon(Icons.zoom_out_map, size: 18),
                              label: Text('Expand Area', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCDDC39),
                                foregroundColor: const Color(0xFF1A1A1A),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  );
                }
                return SizedBox(
                  height: gridHeight,
                  child: Stack(
                    children: [
                      GridView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          childAspectRatio: aspect,
                        ),
                        itemCount: sellers.length,
                        itemBuilder: (context, index) {
                          final s = sellers[index];
                          final isSaved = _savedBiz.contains(s.name);
                          return InkWell(
                            onTap: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SellerDetailScreen(
                                    seller: s,
                                    isSaved: isSaved,
                                    userPosition: _currentPosition,
                                  ),
                                ),
                              );
                              if (result == 'save') {
                                setState(() {
                                  if (!_savedBiz.contains(s.name)) {
                                    _savedBiz = List<String>.from(_savedBiz)..add(s.name);
                                  }
                                });
                              } else if (result == 'unsave') {
                                setState(() {
                                  _savedBiz = List<String>.from(_savedBiz)..remove(s.name);
                                });
                              }
                            },
                            child: SizedBox.expand(child: _sellerGridTile(s, index)),
                          );
                        },
                      ),
                      Positioned(left: 0, right: 0, top: 0, child: _verticalScrollGradient(true)),
                      Positioned(left: 0, right: 0, bottom: 0, child: _bottomBlurOverlay()),
                    ],
                  ),
                );
              } else {
                // Always show map, even if sellers list is empty
                return SizedBox(
                  height: gridHeight,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentPosition,
                          initialZoom: 13.0,
                          minZoom: 3.0,
                          maxZoom: 18.0,
                          onTap: (_, __) { if (_selectedSeller != null) setState(() => _selectedSeller = null); },
                          onMapEvent: (event) { if (_selectedSeller != null) setState(() => _selectedSeller = null); },
                  onPositionChanged: (p, hasGesture) {
                     // Trigger rebuild on zoom change to update markers
                     setState(() {});
                     
                     // Debounce map updates to avoid spamming API
                     if (hasGesture) {
                       _sellerLoadDebounce?.cancel();
                       _sellerLoadDebounce = Timer(const Duration(milliseconds: 600), () {
                         _updateDistanceBasedOnMapBounds();
                       });
                     }
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.jayantslist',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _currentPosition,
                                width: 64,
                                height: 64,
                                child: const Icon(
                                  Icons.my_location,
                                  size: 24,
                                  color: Color(0xFFFF5252),
                                ),
                              ),
                              ...sellers.where((s) => s != _selectedSeller).map(_buildSellerMarker),
                              if (_selectedSeller != null && sellers.contains(_selectedSeller!))
                                _buildSellerMarker(_selectedSeller!),
                            ],
                          ),
                        ],
                      ),
                      
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(
                          children: [
                            _zoomButton(Icons.add, () {
                              final currentZoom = _mapController.camera.zoom;
                              final newZoom = math.min(18.0, currentZoom + 1);
                              _mapController.move(_mapController.camera.center, newZoom);
                              // Explicitly trigger update since onPositionChanged ignores non-gestures
                              Future.delayed(const Duration(milliseconds: 300), _updateDistanceBasedOnMapBounds);
                            }),
                            const SizedBox(height: 8),
                            _zoomButton(Icons.remove, () {
                              final currentZoom = _mapController.camera.zoom;
                              final newZoom = math.max(3.0, currentZoom - 1);
                              _mapController.move(_mapController.camera.center, newZoom);
                              // Explicitly trigger update since onPositionChanged ignores non-gestures
                              Future.delayed(const Duration(milliseconds: 300), _updateDistanceBasedOnMapBounds);
                            }),
                          ],
                        ),
                      ),
                      Positioned(left: 0, right: 0, bottom: 0, child: _bottomBlurOverlay()),

                    ],
                  ),
                );
              }
            },
          ),
          
        ],
      ),
        ),
        if (_sellersLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCDDC39)),
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Fetching new Sellers..',
                        style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sellerCard(Seller s) {
    final dn = _clean(s.name);
    final dc = _clean(s.category);
    final showCat = dc.isNotEmpty && dc.toLowerCase() != dn.toLowerCase();
    // Construct full image URL if needed
    String? imageUrl = s.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFCDDC39).withOpacity(0.25),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.hardEdge,
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.storefront, size: 16, color: Color(0xFF1A1A1A)));
                  },
                )
              : const Center(child: Icon(Icons.storefront, size: 16, color: Color(0xFF1A1A1A))),
        ),
        const SizedBox(height: 6),
        Text(
          dn,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 2),
        if (showCat)
          Text(
            dc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lato(fontSize: 10, color: const Color(0xFF6B7280)),
          ),
      ],
    );
  }

  Widget _sellerGridTile(Seller s, int index) {
    final dn = _clean(s.name);
    final dc = _clean(s.category);
    final showCat = dc.isNotEmpty && dc.toLowerCase() != dn.toLowerCase();
    
    // Construct full image URL if needed
    // Skip default placeholder images
    String? imageUrl = s.imageUrl;
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl = 'https://www.jayantslist.com$imageUrl';
    }
    if (_isDefaultPlaceholder(imageUrl)) {
      imageUrl = null;
    }

    return GestureDetector(
      onTap: () async {
        // Add to recently viewed
        await UserPreferences().addToRecentlyViewed(s);
        
        final isSaved = _savedBiz.contains(s.name);
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerDetailScreen(
              seller: s,
              isSaved: isSaved,
              userPosition: _currentPosition,
            ),
          ),
        );
        
        if (result == 'save') {
          if (s.id != null) {
             try {
               await ApiService().pinSeller(s.id!);
             } catch (e) {
               print('Failed to pin seller: $e');
             }
          }
          await UserPreferences().toggleSavedSeller(s);
          setState(() {
            if (!_savedBiz.contains(s.name)) {
              _savedBiz = List<String>.from(_savedBiz)..add(s.name);
            }
          });
        } else if (result == 'unsave') {
          if (s.id != null) {
             try {
               await ApiService().unpinSeller(s.id!);
             } catch (e) {
               print('Failed to unpin seller: $e');
             }
          }
          await UserPreferences().toggleSavedSeller(s);
          setState(() {
            _savedBiz = List<String>.from(_savedBiz)..remove(s.name);
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Centered Image
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9DF),
                    shape: BoxShape.circle,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1A1A)),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            dn.isNotEmpty ? dn[0].toUpperCase() : '?',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A)),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
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
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
            // Heart Icon
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () async {
                  // Toggle save - stop propagation to parent gesture detector
                  final isSaved = _savedBiz.contains(s.name);
                  if (isSaved) {
                    // Unsave
                    if (s.id != null) {
                       try {
                         await ApiService().unpinSeller(s.id!);
                       } catch (e) {
                         print('Failed to unpin seller: $e');
                       }
                    }
                    await UserPreferences().toggleSavedSeller(s);
                    setState(() {
                      _savedBiz = List<String>.from(_savedBiz)..remove(s.name);
                    });
                  } else {
                    // Save
                    if (s.id != null) {
                       try {
                         await ApiService().pinSeller(s.id!);
                       } catch (e) {
                         print('Failed to pin seller: $e');
                       }
                    }
                    await UserPreferences().toggleSavedSeller(s);
                    setState(() {
                      _savedBiz = List<String>.from(_savedBiz)..add(s.name);
                    });
                  }
                },
                child: Icon(
                  _savedBiz.contains(s.name) ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: _savedBiz.contains(s.name) ? const Color(0xFFCDDC39) : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _locationCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A1A1A).withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFCDDC39).withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.place_outlined, size: 14, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(String title, {double width = 120, double fontSize = 11, double iconSize = 14, double iconBox = 24, double extraRightPadding = 0}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A1A1A).withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 8, right: 8 + extraRightPadding, top: 6, bottom: 6),
        child: Row(
          children: [
            Container(
              height: iconBox,
              width: iconBox,
              decoration: BoxDecoration(
                color: const Color(0xFFCDDC39).withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.storefront, size: iconSize, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedBizCard(String title) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _miniCard(title, extraRightPadding: 18),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () {
              _showSavedBizEditOptions(title);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, size: 14, color: Color(0xFF4A4A4A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scrollGradient(bool isLeft) {
    return IgnorePointer(
      child: Container(
        width: 20,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [
              Color(0xFFFAF7F0),
              Color(0xFFFAF7F0),
              Color(0xFFFAF7F0),
              Color(0x00FAF7F0),
            ],
            stops: const [0.0, 0.2, 0.4, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _verticalScrollGradient(bool isTop) {
    return IgnorePointer(
      child: Container(
        height: 18,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: const [
              Color(0xFFFAF7F0),
              Color(0xFFFAF7F0),
              Color(0x00FAF7F0),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }

  void _fitToSellers(List<Seller> sellers, {bool isManual = false}) {
    if (sellers.isEmpty) return;
    if (!isManual) return; // Only fit if explicitly requested by user (button click)
    final points = <LatLng>[];
    points.add(_currentPosition);
    points.addAll(sellers.map((s) => s.position));
    if (points.length < 2) return;
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
  }



  void _showSavedBizEditOptions(String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F0),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                title: Text(
                  'Remove from Saved Biz',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _savedBiz = List<String>.from(_savedBiz)..remove(title);
                  });
                },
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF4A4A4A)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _storyItem(String title) {
    final initials = title.isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return InkWell(
      onTap: () async {
        final s = _findOrCreateSellerByName(title);
        final isSaved = _savedBiz.contains(s.name);
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerDetailScreen(
              seller: s,
              isSaved: isSaved,
              userPosition: _currentPosition,
            ),
          ),
        );
        if (result == 'save') {
          setState(() {
            if (!_savedBiz.contains(s.name)) {
              _savedBiz = List<String>.from(_savedBiz)..add(s.name);
            }
          });
        } else if (result == 'unsave') {
          setState(() {
            _savedBiz = List<String>.from(_savedBiz)..remove(s.name);
          });
        }
      },
      borderRadius: BorderRadius.circular(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFCDDC39), Color(0xFFB0C926)]),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFFAF7F0),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEDE9DF),
                child: Text(initials, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Widget _savedBizGridCard(String title) {
    final initials = title.isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9DF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(initials, style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () { _showSavedBizEditOptions(title); },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A).withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit, size: 12, color: Color(0xFF4A4A4A)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sellerChip(Seller s) {
    final dn = _clean(s.name);
    return InkWell(
      onTap: () async {
        final isSaved = _savedBiz.contains(s.name);
        
        // Add to recently viewed
        await UserPreferences().addToRecentlyViewed(s);

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SellerDetailScreen(
              seller: s,
              isSaved: isSaved,
              userPosition: _currentPosition,
            ),
          ),
        );
        if (result == 'save') {
          if (s.id != null) {
             try {
               await ApiService().pinSeller(s.id!);
             } catch (e) {
               print('Failed to pin seller: $e');
             }
          }
          await UserPreferences().toggleSavedSeller(s);
          setState(() {
            if (!_savedBiz.contains(s.name)) {
              _savedBiz = List<String>.from(_savedBiz)..add(s.name);
            }
          });
        } else if (result == 'unsave') {
          if (s.id != null) {
             try {
               await ApiService().unpinSeller(s.id!);
             } catch (e) {
               print('Failed to unpin seller: $e');
             }
          }
          await UserPreferences().toggleSavedSeller(s);
          setState(() {
            _savedBiz = List<String>.from(_savedBiz)..remove(s.name);
          });
        }
      },
      borderRadius: BorderRadius.circular(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEDE9DF),
            child: Text(dn.isNotEmpty ? dn[0].toUpperCase() : '?', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(dn, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 11, color: const Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _previousIndex = _selectedIndex;
          _selectedIndex = index;
        });
        
        // Reload saved sellers when returning from Profile to Cards or Home
        if (_previousIndex == 3 && (index == 2 || index == 1)) {
          _loadSavedBiz();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFCDDC39) : const Color(0xFF6B7280),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CurvedNavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFAF7F0)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Notch parameters
    final notchRadius = 32.0;
    final centerX = size.width / 2;
    
    // Start from left
    path.moveTo(0, 0);
    path.lineTo(centerX - notchRadius - 20, 0);
    
    // Left curve of the notch
    path.quadraticBezierTo(
      centerX - notchRadius - 10,
      0,
      centerX - notchRadius,
      10,
    );
    
    // Top curve around the button
    path.arcToPoint(
      Offset(centerX + notchRadius, 10),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    
    // Right curve of the notch
    path.quadraticBezierTo(
      centerX + notchRadius + 10,
      0,
      centerX + notchRadius + 20,
      0,
    );
    
    // Complete the rectangle
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Helper classes for the hierarchical filter tree
class _CategoryNode {
  final String name;
  final String? id;
  final String? hcode;
  final String? imageUrl;
  bool isExpanded;
  List<_CategoryNode>? children;
  bool isLoading;

  _CategoryNode({
    required this.name,
    this.id,
    this.hcode,
    this.imageUrl,
    this.isExpanded = false,
    this.children,
    this.isLoading = false,
  });
}

// Private widget to handle the complex state of the Split-View Filter Sheet
class _FilterSheetContent extends StatefulWidget {
  final String initialTab;
  final List<String> rootCategories;
  final Map<String, int> apiCatIds;
  final Map<String, String> apiCatCodes;
  final List<Seller> sellers;
  final List<dynamic> rawCategories;
  final Set<String> tempSelectedCategories;
  final List<int> tempSelectedCategoryIds;
  final double? distance;
  final Function(Set<String>, List<int>, double?) onApply;

  const _FilterSheetContent({
    required this.initialTab,
    required this.rootCategories,
    required this.apiCatIds,
    required this.apiCatCodes,
    required this.sellers,
    required this.rawCategories,
    required this.tempSelectedCategories,
    required this.tempSelectedCategoryIds,
    required this.distance,
    required this.onApply,
  });

  @override
  _FilterSheetContentState createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  late String _currentTab;
  // Cache for tab children: TabName -> List<Node>
  final Map<String, List<_CategoryNode>> _tabCache = {};
  bool _isLoadingTab = false;
  double? _currentDistance;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _currentDistance = widget.distance;
    
    // Load initial tab immediately
    if (_currentTab.isNotEmpty) {
      _loadTab(_currentTab);
    }
  }

  void _loadTab(String tabName) {
    if (_tabCache.containsKey(tabName)) return;

    setState(() => _isLoadingTab = true);

    final int? pId = widget.apiCatIds[_norm(tabName)];
    final String? pHcode = widget.apiCatCodes[_norm(tabName)];

    fetchChildrenFor(tabName, pHcode, pId).then((nodes) {
      if (mounted) {
        setState(() {
          _tabCache[tabName] = nodes;
          _isLoadingTab = false;
          _autoExpandDeepMatches(nodes);
        });
      }
    });
  }

  // Reuse the dynamic fetch logic
  Future<List<_CategoryNode>> fetchChildrenFor(String pName, String? pHcode, int? pId) async {
      // 1. Sellers
      final Set<String> foundNames = {};
      final List<_CategoryNode> results = [];
      
      if (pHcode != null) {
         final prefix = '$pHcode.';
         for (final s in widget.sellers) {
            final sHcode = s.hcode;
            if (sHcode != null && sHcode.startsWith(prefix)) {
               if (sHcode.split('.').length == pHcode.split('.').length + 1) {
                  final sCatName = s.category;
                   if (!foundNames.contains(sCatName)) {
                      foundNames.add(sCatName);
                      results.add(_CategoryNode(
                         name: sCatName,
                         id: s.categoryId?.toString(),
                         hcode: s.hcode,
                         imageUrl: s.categoryImageUrl
                      ));
                   }
               }
            }
         }
      }
      
      // 2. Static
      if (pHcode != null) {
          final prefix = '$pHcode.';
          final staticSubs = widget.rawCategories.where((e) {
             final h = e['hcode']?.toString();
             return h != null && h.startsWith(prefix) && h.split('.').length == pHcode.split('.').length + 1;
          });
          for (final sub in staticSubs) {
              final name = sub['name']?.toString();
              if (name != null && !foundNames.contains(name)) {
                  foundNames.add(name);
                  results.add(_CategoryNode(
                     name: name,
                     id: sub['id']?.toString(),
                     hcode: sub['hcode']?.toString(),
                     imageUrl: sub['picture_url']?.toString()
                  ));
              }
          }
      }
      
      // 3. API - Always fetch to ensure we find all server-side categories
      if (pId != null) {
          try {
             final list = await ApiService().getCategories(parentId: pId);
             for (final e in list) {
                 final name = e['name']?.toString() ?? '';
                 if (name.isNotEmpty && !foundNames.contains(name)) {
                     // Update parent maps? - Modifying widget props isn't possible directly,
                     // but these maps are refs to the HomeScreen state maps. 
                     // We can't modify them safely if they are final in widget?
                     // They are passed by reference, so modifying the CONTENT of the map is okay.
                     if (e['hcode'] != null) widget.apiCatCodes[_norm(name)] = e['hcode'].toString();
                     if (e['id'] != null) widget.apiCatIds[_norm(name)] = int.tryParse(e['id'].toString()) ?? 0;
                     
                     results.add(_CategoryNode(
                        name: name,
                        id: e['id']?.toString(),
                        hcode: e['hcode']?.toString(),
                        imageUrl: e['picture_url']?.toString()
                     ));
                 }
             }
          } catch (e) {
             print('Error fetching subcats: $e');
          }
      }
      
      results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return results;
  }
  
  // Normalization helper
  String _norm(String s) => s.toLowerCase().trim();

  void _autoExpandDeepMatches(List<_CategoryNode> nodes) {
    if (widget.tempSelectedCategories.isEmpty) return;

    for (final node in nodes) {
       final nodeHcode = node.hcode;
       if (nodeHcode == null) continue;
       
       // Check if this node is an ancestor of any selected category
       bool isAncestor = false;
       for (final selected in widget.tempSelectedCategories) {
          final sHcode = widget.apiCatCodes[_norm(selected)];
          if (sHcode != null && sHcode.startsWith('$nodeHcode.') && sHcode != nodeHcode) {
             isAncestor = true;
             break;
          }
       }
       
       if (isAncestor) {
          setState(() => node.isExpanded = true);
          if (node.children == null || node.children!.isEmpty) {
             setState(() => node.isLoading = true);
             fetchChildrenFor(node.name, node.hcode, int.tryParse(node.id ?? '0')).then((children) {
                 if (mounted) {
                    setState(() {
                       node.children = children;
                       node.isLoading = false;
                    });
                    _autoExpandDeepMatches(children);
                 }
             });
          } else {
             _autoExpandDeepMatches(node.children!);
          }
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // We use scrollController for the Right Panel (content)
        
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                   // Back button if in deep view? No, tabs handle top level.
                  Text("Filters", style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content Row (Split View)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Panel: Navigation Tabs
                  Container(
                    width: 130, // Fixed width for master list
                    color: const Color(0xFFF7F7F7),
                    child: ListView.builder(
                      itemCount: widget.rootCategories.length,
                      itemBuilder: (context, index) {
                        final tabName = widget.rootCategories[index];
                        final isSelected = tabName == _currentTab;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _currentTab = tabName;
                              _loadTab(tabName);
                            });
                          },
                          child: Container(
                            color: isSelected ? Colors.white : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            child: Row(
                              children: [
                                // Indicator strip
                                if (isSelected)
                                  Container(width: 4, height: 24, decoration: BoxDecoration(color: const Color(0xFFCDDC39), borderRadius: BorderRadius.circular(2))),
                                if (isSelected) const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tabName,
                                    style: GoogleFonts.lato(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.black : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Right Panel: Subcategories Tree
                  Expanded(
                    child: _isLoadingTab 
                        ? const Center(child: CircularProgressIndicator())
                        : _tabCache[_currentTab] == null || _tabCache[_currentTab]!.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.category_outlined, size: 40, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      Text("No sub-categories", style: GoogleFonts.lato(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                )
                              : ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(0),
                                  children: _buildTreeNodes(_tabCache[_currentTab]!, 0),
                                ),
                  ),
                ],
              ),
            ),
            
            // Footer
            Container(
               padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
               decoration: const BoxDecoration(
                 color: Colors.white,
                 border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   // Distance Filter (Chips style)
                   Row(
                     children: [
                       Text('Distance:', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold)),
                       const SizedBox(width: 12),
                       Expanded(
                         child: SingleChildScrollView(
                           scrollDirection: Axis.horizontal,
                           child: Row(
                             children: [5, 10, 15, 25, 50, null].map((dist) {
                               final bool isSelected;
                               if (dist == null) {
                                 isSelected = _currentDistance == null;
                               } else {
                                 isSelected = _currentDistance != null && (_currentDistance! - dist).abs() < 1.0;
                               }
                               
                               return Padding(
                                 padding: const EdgeInsets.only(right: 8),
                                 child: InkWell(
                                   onTap: () => setState(() => _currentDistance = dist?.toDouble()),
                                   borderRadius: BorderRadius.circular(16),
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                     decoration: BoxDecoration(
                                       color: isSelected ? const Color(0xFFCDDC39) : const Color(0xFFF5F5F5),
                                       borderRadius: BorderRadius.circular(16),
                                       border: Border.all(color: isSelected ? const Color(0xFFB0C926) : Colors.transparent),
                                     ),
                                     child: Text(
                                       dist == null ? 'All' : '< $dist km',
                                       style: GoogleFonts.lato(
                                         fontSize: 11,
                                         fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                         color: const Color(0xFF1A1A1A),
                                       ),
                                     ),
                                   ),
                                 ),
                               );
                             }).toList(),
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   
                   // Action Buttons
                   Row(
                     children: [
                       Expanded(
                         child: OutlinedButton(
                           onPressed: () {
                             setState(() {
                                widget.tempSelectedCategories.clear();
                                widget.tempSelectedCategoryIds.clear();
                                _currentDistance = 50.0;
                             });
                           },
                           style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              minimumSize: const Size(0, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                           child: Text("Clear All", style: GoogleFonts.lato(fontSize: 13, color: Colors.black)),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: ElevatedButton(
                           onPressed: () => widget.onApply(widget.tempSelectedCategories, widget.tempSelectedCategoryIds, _currentDistance),
                           style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCDDC39),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              minimumSize: const Size(0, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                           ),
                           child: Text("Apply filters", style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold)),
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
            ),
          ],
        );
      },
    );
  }

  // Recursive Tree Builder for Right Panel
  List<Widget> _buildTreeNodes(List<_CategoryNode> nodes, int level) {
      final List<Widget> widgets = [];
      for (final node in nodes) {
          final bool isSelected = widget.tempSelectedCategories.contains(node.name);
          
          widgets.add(
             InkWell(
               onTap: () {
                   // Prevent expansion for deep nodes (Level 3+)
                   if (node.hcode != null && node.hcode!.split('.').length >= 3) return;

                   // Expand/Collapse logic for Right Panel items
                   setState(() {
                      node.isExpanded = !node.isExpanded;
                      if (node.isExpanded && node.children == null) {
                         node.isLoading = true;
                         // Fetch deeper children
                         int? pId = node.id != null ? int.tryParse(node.id!) : widget.apiCatIds[_norm(node.name)];
                         fetchChildrenFor(node.name, node.hcode, pId).then((children) {
                            if (mounted) {
                               setState(() {
                                  node.children = children;
                                  node.isLoading = false;
                               });
                            }
                         });
                      }
                   });
               },
               child: Container(
                 padding: EdgeInsets.only(left: 12.0 + (level * 16.0), top: 12, bottom: 12, right: 12),
                 decoration: BoxDecoration(
                    color: node.isExpanded ? const Color(0xFFF9F9F9) : Colors.transparent,
                    border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                 ),
                 child: Row(
                   children: [
                     // Checkbox for selection
                     SizedBox(
                       width: 20, height: 20,
                       child: Checkbox(
                         value: isSelected,
                         activeColor: const Color(0xFFCDDC39),
                         checkColor: Colors.black,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                         onChanged: (val) {
                           setState(() {
                              if (val == true) {
                                widget.tempSelectedCategories.add(node.name);
                                int? i = node.id != null ? int.tryParse(node.id!) : widget.apiCatIds[_norm(node.name)];
                                if (i != null) widget.tempSelectedCategoryIds.add(i);
                              } else {
                                widget.tempSelectedCategories.remove(node.name);
                                int? i = node.id != null ? int.tryParse(node.id!) : widget.apiCatIds[_norm(node.name)];
                                if (i != null) widget.tempSelectedCategoryIds.remove(i);
                              }
                           });
                         },
                       ),
                     ),
                     const SizedBox(width: 10),
                     // Name
                     Expanded(
                       child: Text(
                         node.name,
                         style: GoogleFonts.lato(fontSize: 13, color: Colors.black87, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                       ),
                     ),
                     // Expand arrow
                      if (node.isLoading)
                         const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (node.hcode != null && node.hcode!.split('.').length >= 3)
                         const SizedBox(width: 18) 
                      else
                         Icon(node.isExpanded ? Icons.expand_less : Icons.keyboard_arrow_right, size: 18, color: Colors.grey),
                   ],
                 ),
               ),
             )
          );
          
          if (node.isExpanded && node.children != null) {
              if (node.children!.isEmpty) {
                 widgets.add(Padding(
                    padding: EdgeInsets.only(left: 28.0 + ((level+1)*16), top:8, bottom:8),
                    child: Text("No further sub-categories", style: GoogleFonts.lato(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                 ));
              } else {
                 widgets.addAll(_buildTreeNodes(node.children!, level + 1));
              }
          }
      }
      return widgets;
  }
}










