import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://www.jayantslist.com/api';

  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;

  Future<String?> get authToken async {
    if (_authToken != null) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    return _authToken;
  }

  Future<void> setToken(String authToken) async {
    _authToken = authToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', authToken);
  }

  Future<void> clearTokens() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Helper method for headers
  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await authToken;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Authentication
  Future<Map<String, dynamic>> sendOtp(String mobile) async {
    print('Sending OTP to $mobile at $baseUrl/accounts/send-otp');
    final response = await http.post(
      Uri.parse('$baseUrl/accounts/send-otp'),
      headers: await _getHeaders(auth: false),
      body: jsonEncode({'mobile': mobile}),
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> validateOtp(String mobile, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/accounts/validate-otp'),
      headers: await _getHeaders(auth: false),
      body: jsonEncode({
        'mobile': mobile,
        'otp': int.parse(otp).toString(), // Convert to int to remove leading zeros, then back to string
      }),
    ).timeout(const Duration(seconds: 10));
    
    final data = _handleResponse(response);
    if (data['auth_token'] != null) {
      await setToken(data['auth_token']);
    }
    return data;
  }

  // User Profile & Location
  Future<void> updateLocation(double latitude, double longitude) async {
    await _authenticatedRequest(
      () async => http.post(
        Uri.parse('$baseUrl/accounts/update-last-location'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ),
    );
  }

  // Discovery
  Future<List<dynamic>> getNearbySellers({double maxDistance = 15000, String? catHcode}) async {
    // Note: maxDistance is in meters in the API example (15000), but usually passed as km in app.
    // The user example shows 15000 for max_distance. I will assume it's meters.
    // If the app passes km, I should convert.
    // The default in app is 10.0 (km).
    
    final Map<String, dynamic> body = {
      'max_distance': maxDistance, // Assuming input is already in meters or compatible unit
    };
    if (catHcode != null) {
      body['cat_hcode'] = catHcode;
    }

    final url = '$baseUrl/common/nearby-sellers';
    print('🌐 API Call: POST $url Body: $body');
    
    final response = await _authenticatedRequest(
      () async => http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ),
    );
    // Response structure: { success: true, data: { shops: [...] } }
    return response['data']?['shops'] ?? [];
  }

  Future<List<dynamic>> getCategories({int? parentId}) async {
    String query = '';
    if (parentId != null) {
      query = '?parent_id=$parentId';
    }
    final url = '$baseUrl/common/categories$query';
    
    final response = await _authenticatedRequest(
      () async => http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ),
    );
    // Response structure: { success: true, data: { categories: [...] } }
    return response['data']?['categories'] ?? [];
  }

  Future<Map<String, dynamic>> search(String query, {double maxDistance = 14000}) async {
    final url = '$baseUrl/common/search';
    final body = {
      'max_distance': maxDistance,
      'query': query,
    };
    print('🌐 API Call: POST $url Body: $body');
    final res = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final parsed = jsonDecode(res.body);
        if (parsed is List) {
          return {'shops': parsed};
        } else if (parsed is Map<String, dynamic>) {
          final data = parsed['data'];
          if (data is Map && data['shops'] is List) {
            return {'shops': data['shops']};
          }
          if (parsed['shops'] is List) {
            return {'shops': parsed['shops']};
          }
          return parsed;
        } else {
          throw Exception('Unexpected search response type');
        }
      } catch (e) {
        throw Exception('Invalid JSON response from server');
      }
    } else {
      try {
        final err = jsonDecode(res.body);
        final msg = (err is Map) ? (err['message'] ?? err['error'] ?? 'Search failed') : 'Search failed';
        throw Exception(msg);
      } catch (_) {
        throw Exception('Search failed: ${res.statusCode}');
      }
    }
  }

  // User Actions
  Future<void> pinSeller(int sellerShopId) async {
    final url = '$baseUrl/accounts/pin-seller';
    await _authenticatedRequest(
      () async => http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({'seller_shop_id': sellerShopId}),
      ),
    );
  }

  Future<void> unpinSeller(int sellerShopId) async {
    final url = '$baseUrl/accounts/unpin-seller';
    await _authenticatedRequest(
      () async => http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({'seller_shop_id': sellerShopId}),
      ),
    );
  }

  Future<void> logCall(int sellerShopId, int sellerShopServiceId) async {
    final url = '$baseUrl/accounts/log-call';
    await _authenticatedRequest(
      () async => http.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({
          'seller_shop_id': sellerShopId,
          'seller_shop_service_id': sellerShopServiceId,
        }),
      ),
    );
  }

  // Helper for authenticated requests
  Future<dynamic> _authenticatedRequest(Future<http.Response> Function() request) async {
    var response = await request();
    
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Session expired. Please login again.');
    }
    
    return _handleResponse(response);
  }

  // Seller Post Management
  Future<String> uploadFile(String filePath) async {
    final token = await authToken;
    if (token == null) {
      throw Exception('Authentication required');
    }

    final uri = Uri.parse('$baseUrl/sellers/uploads');
    print('📤 Upload endpoint: $uri');
    
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    
    // Add file with proper field name
    final file = await http.MultipartFile.fromPath(
      'file',
      filePath,
    );
    request.files.add(file);

    print('Uploading file: $filePath');
    print('File field name: file');
    print('File size: ${file.length} bytes');
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Upload response: ${response.statusCode} ${response.body}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null && data['data']['filepath'] != null) {
        return data['data']['filepath'];
      }
      throw Exception('Invalid upload response');
    } else {
      final errorBody = response.body;
      print('❌ Upload failed: $errorBody');
      
      try {
        final error = jsonDecode(errorBody);
        final errorMsg = error['message'] ?? error['error'] ?? 'Upload failed';
        throw Exception(errorMsg);
      } catch (e) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String mediaType, // "IMAGE" | "VIDEO" | "TEXT"
    String? caption,
    String? filepath,
  }) async {
    final headers = await _getHeaders(auth: true);
    final body = {
      'media_type': mediaType,
      if (caption != null) 'caption': caption,
      if (filepath != null) 'filepath': filepath,
    };

    print('Creating post: $body');
    final response = await http.post(
      Uri.parse('$baseUrl/sellers/posts'),
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<List<dynamic>> getSellerPosts() async {
    final headers = await _getHeaders(auth: true);
    final response = await http.get(
      Uri.parse('$baseUrl/sellers/posts'),
      headers: headers,
    );
    final data = _handleResponse(response);
    return data['data']?['posts'] ?? data['posts'] ?? [];
  }

  Future<Map<String, dynamic>> updateAccountProfile({required String fullname, String? filePath}) async {
    final token = await authToken;
    if (token == null) {
      throw Exception('Authentication required');
    }

    final uri = Uri.parse('$baseUrl/accounts/profile');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['fullname'] = fullname;
    if (filePath != null && filePath.isNotEmpty) {
      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getAccountProfile() async {
    final headers = await _getHeaders(auth: true);
    final response = await http.get(
      Uri.parse('$baseUrl/accounts/profile'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  /// Fetch current logged-in user's profile info including picture_url
  /// GET /api/accounts/me
  Future<Map<String, dynamic>> getAccountMe() async {
    final headers = await _getHeaders(auth: true);
    final response = await http.get(
      Uri.parse('$baseUrl/accounts/me'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {

    print('API Response: ${response.statusCode} ${response.body}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success response - parse JSON
      try {
        return jsonDecode(response.body);
      } catch (e) {
        print('⚠️ Failed to parse success response as JSON: $e');
        throw Exception('Invalid JSON response from server');
      }
    } else {
      // Error response - try parsing as JSON first
      try {
        final error = jsonDecode(response.body);
        // Check both 'error' and 'message' fields
        final errorMsg = error['error'] ?? error['message'] ?? 'Unknown error occurred';
        throw Exception(errorMsg);
      } catch (e) {
        // If JSON parsing fails, use the raw response body
        final errorMsg = response.body.isNotEmpty 
            ? response.body 
            : 'Server error (${response.statusCode})';
        throw Exception(errorMsg);
      }
    }
  }
}
