import 'dart:convert';
import '../core/constants.dart';
import '../models/user.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const Duration _timeout = Duration(seconds: 30);

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
      ).timeout(_timeout);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return;
      }
      
      if (response.statusCode == 409) {
        final error = jsonDecode(response.body)['error'] ?? 'Username already taken';
        throw Exception(error);
      }
      
      if (response.statusCode == 400) {
        final error = jsonDecode(response.body)['error'] ?? 'Invalid input';
        throw Exception(error);
      }
      
      final error = jsonDecode(response.body)['error'] ?? 'Registration failed (HTTP ${response.statusCode})';
      throw Exception(error);
    } on FormatException catch (_) {
      throw Exception('Invalid server response. Please try again.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.serverUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      
      if (response.statusCode == 401) {
        final error = jsonDecode(response.body)['error'] ?? 'Invalid username or password';
        throw Exception(error);
      }
      
      if (response.statusCode == 400) {
        final error = jsonDecode(response.body)['error'] ?? 'Please enter username and password';
        throw Exception(error);
      }

      final error = jsonDecode(response.body)['error'] ?? 'Login failed (HTTP ${response.statusCode})';
      throw Exception(error);
    } on FormatException catch (_) {
      throw Exception('Invalid server response. Please try again.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<String> getPublicKey(String userId, String token) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/public-key/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get public key');
    }

    final data = jsonDecode(response.body);
    return data['publicKey'] as String;
  }

  static Future<List<AppUser>> getUsers(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load users');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> usersList = data['users'];
    return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<List<AppUser>> getOnlineUsers(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/online-users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load online users');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> usersList = data['onlineUsers'];
    return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<List<AppUser>> searchUsers(String token, String query) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/users/search?q=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to search users');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> usersList = data['users'];
    return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<void> registerFcmToken(String token, String fcmToken) async {
    final response = await http.post(
      Uri.parse('${Constants.serverUrl}/api/fcm-token'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'token': fcmToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to register FCM token');
    }
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
      throw Exception('Failed to update status');
    }
  }
}
