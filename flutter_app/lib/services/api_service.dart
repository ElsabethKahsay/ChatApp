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
      final url = '${Constants.serverUrl}/api/login';
      print('API Login: Attempting login to $url');
      print('   Username: $username');
      print('   Server URL: ${Constants.serverUrl}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(_timeout);

      print('API Login: Response status: ${response.statusCode}');
      print('API Login: Response body: ${response.body}');

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
      print('API Login: Format exception - invalid server response');
      throw Exception('Invalid server response. Please try again.');
    } catch (e) {
      print('API Login: Exception - $e');
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<String> getPublicKey(String userId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/public-key/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['publicKey'] as String;
      }

      if (response.statusCode == 404) {
        throw Exception('User not found');
      }

      if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      }

      throw Exception('Failed to get public key: HTTP ${response.statusCode}');
    } on FormatException catch (_) {
      throw Exception('Invalid server response');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<List<AppUser>> getUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/users'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersList = data['users'];
        return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      }

      throw Exception('Failed to load users: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<List<AppUser>> getOnlineUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/online-users'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersList = data['onlineUsers'];
        return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      }

      throw Exception('Failed to load online users: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<List<AppUser>> searchUsers(String token, String query) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/users/search?q=$query'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> usersList = data['users'];
        return usersList.map((json) => AppUser.fromJson(json as Map<String, dynamic>)).toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      }

      throw Exception('Failed to search users: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<void> registerFcmToken(String token, String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.serverUrl}/api/fcm-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': fcmToken}),
      ).timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      }

      throw Exception('Failed to register FCM token: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  static Future<void> updateStatus(String token, bool status) async {
    try {
      final response = await http.put(
        Uri.parse('${Constants.serverUrl}/api/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return;
      }

      if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please log in again.');
      }

      throw Exception('Failed to update status: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  // ── Saved Messages Endpoints ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSavedMessages(String token) async {
    try {
      final url = '${Constants.serverUrl}/api/saved-messages';
      print('API: Getting saved messages from $url');
      print('   Token length: ${token.length}');
      print('   Token preview: ${token.substring(0, 20)}...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      print('API: Saved messages response status: ${response.statusCode}');
      print('API: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }

      if (response.statusCode == 404) {
        print('API: No saved messages found (404)');
        return []; // No saved messages yet
      }

      final error = jsonDecode(response.body)['error'] ?? 'Failed to load saved messages';
      print('API: Error loading saved messages: $error');
      throw Exception(error);
    } on FormatException catch (_) {
      print('API: Format exception in saved messages response');
      throw Exception('Invalid server response');
    } catch (e) {
      print('API: Exception in saved messages: $e');
      if (e is Exception) rethrow;
      throw Exception('Network error');
    }
  }

  static Future<void> deleteSavedMessage({
    required String token,
    required String messageId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${Constants.serverUrl}/api/saved-messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return;
      }

      if (response.statusCode == 404) {
        throw Exception('Message not found');
      }

      final error = jsonDecode(response.body)['error'] ?? 'Failed to delete message';
      throw Exception(error);
    } on FormatException catch (_) {
      throw Exception('Invalid server response');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error');
    }
  }

  // ── Group Messaging Endpoints ───────────────────────────────────────────

  static Future<void> createGroup({
    required String token,
    required String name,
    required List<String> members,
    required Map<String, Map<String, String>> encryptedKeys,
  }) async {
    final response = await http.post(
      Uri.parse('${Constants.serverUrl}/api/groups'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'members': members,
        'encryptedKeys': encryptedKeys,
      }),
    ).timeout(_timeout);

    if (response.statusCode != 201) {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getGroups(String token) async {
    final response = await http.get(
      Uri.parse('${Constants.serverUrl}/api/groups'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load groups');
  }

  static Future<void> createSavedMessage({
    required String token,
    required Map<String, dynamic> content, // Expects { ciphertext, nonce, mac }
    String? label,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.serverUrl}/api/saved-messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
          'label': label,
        }),
      ).timeout(_timeout);

      if (response.statusCode != 201) {
        throw Exception('Failed to save message: ${response.body}');
      }
    } on FormatException catch (_) {
      throw Exception('Invalid server response');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error');
    }
  }
}
