import 'dart:convert';
import '../core/constants.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;


/// REST API client stub
class ApiService {
  // TODO: Implement actual API calls

  static Future<void> register({
    required String userId,
    required String username,
    required String publicKey,
    required String password,
    DateTime? bday,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.serverUrl}/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'username': username,
          'publicKey': publicKey,
          'password': password,
          if (bday != null) 'bday': bday.toIso8601String(),
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Registration failed: ${response.body}');
      }
      
      print('✅ User registered successfully');
    } catch (e) {
      print('❌ Registration error: $e');
      rethrow;
    }
  }

  static Future<String> getPublicKey(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/public-key/$userId'),
      );
      
      if (response.statusCode == 404) {
        throw Exception('User $userId not found');
      }
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get public key: ${response.body}');
      }
      
      final data = jsonDecode(response.body);
      return data['publicKey'] as String;
    } catch (e) {
      print('❌ Get public key error: $e');
      rethrow;
    }
  }

  static Future<List<AppUser>> getUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get users: ${response.body}');
      }
      
      final data = jsonDecode(response.body);
      final List<dynamic> usersList = data['users'];
      
      return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Get users error: $e');
      rethrow;
    }
  }

  static Future<List<AppUser>> getOnlineUsers(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/online-users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Get online users failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> usersList = data['onlineUsers'];
    return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getPresence(String token, String userId) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/presence/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Get presence failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> updateStatus(String token, bool status) async {
    final response = await http.put(
      Uri.parse('${Constants.serverUrl}/api/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Update status failed: ${response.body}');
    }
  }

  static Future<String> login(String userId, String password) async {
    final response = await http.post(
      Uri.parse('${Constants.serverUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['token'] as String;
  }

  static Future<String> requestSocketToken(String userId, String password) async {
    // Backwards compatibility: token endpoint still accepts password for security.
    final response = await http.post(
      Uri.parse('${Constants.serverUrl}/api/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Socket auth failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['token'] as String;
  }
}

