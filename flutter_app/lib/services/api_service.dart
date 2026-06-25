import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../crypto/key_store.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 20);

  /// GAP-FILL: Fetches the last 24 hours of messages from the server.
  static Future<List<Map<String, dynamic>>> getMessageHistory(String peerId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('${Constants.serverUrl}/api/messages/$peerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Gap-Fill Sync Error: $e');
      return [];
    }
  }

  /// GAP-FILL: Fetches the last 24 hours of group messages from the server.
  static Future<List<Map<String, dynamic>>> getGroupHistory(String groupId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('${Constants.serverUrl}/api/groups/$groupId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Group Gap-Fill Error: $e');
      return [];
    }
  }

  /// V1 PERFECTION: Media presign endpoint
  static Future<Map<String, dynamic>> getPresignedUrl(String token, String extension) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/presign'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'extension': extension}),
    ).timeout(_timeout);

    if (response.statusCode != 200) throw Exception('Failed to get upload link');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.toLowerCase().trim(), 'password': password}),
    );
    if (response.statusCode != 200) throw Exception(jsonDecode(response.body)['error'] ?? 'Login Failed');
    return jsonDecode(response.body);
  }

  static Future<void> register({
    required String userId,
    required String username,
    required String publicKey,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'username': username.toLowerCase().trim(),
        'publicKey': publicKey,
        'password': password,
      }),
    );
    if (response.statusCode != 201) throw Exception(jsonDecode(response.body)['error'] ?? 'Registration Failed');
  }

  static Future<String> getPublicKey(String userId, String token) async {
    final response = await _client.get(
      Uri.parse('${Constants.serverUrl}/api/public-key/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Peer Key Unavailable');
    return jsonDecode(response.body)['publicKey'];
  }

  static Future<List<AppUser>> getUsers(String token) async {
    final response = await _client.get(
      Uri.parse('${Constants.serverUrl}/api/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) return [];
    final List<dynamic> users = jsonDecode(response.body)['users'];
    return users.map((u) => AppUser.fromJson(u)).toList();
  }

  static Future<void> createGroup({
    required String token,
    required String name,
    required List<String> members,
    required Map<String, Map<String, String>> encryptedKeys,
    required String creatorPublicKey,
  }) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/groups'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'members': members,
        'encryptedKeys': encryptedKeys,
        'creatorPublicKey': creatorPublicKey,
      }),
    );
    if (response.statusCode != 201) throw Exception('Failed to create group');
  }

  static Future<List<Map<String, dynamic>>> getGroups(String token) async {
    final response = await _client.get(
      Uri.parse('${Constants.serverUrl}/api/groups'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    return [];
  }

  static Future<void> updatePublicKey(String token, String publicKey, {required String password}) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/keys/update'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'publicKey': publicKey, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Key update failed');
    }
  }

  static Future<List<AppUser>> getOnlineUsers(String token) async {
    final response = await _client.get(
      Uri.parse('${Constants.serverUrl}/api/online-users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) return [];
    final List<dynamic> users = jsonDecode(response.body)['onlineUsers'];
    return users.map((u) => AppUser.fromJson(u)).toList();
  }

  static Future<void> registerFcmToken(String token, String fcmToken) async {
    await _client.post(
      Uri.parse('${Constants.serverUrl}/api/fcm-token'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'token': fcmToken}),
    );
  }

  static Future<List<AppUser>> searchUsers(String token, String query) async {
    final response = await _client.get(
      Uri.parse('${Constants.serverUrl}/api/users/search?q=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> users = jsonDecode(response.body)['users'];
      return users.map((u) => AppUser.fromJson(u)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createSavedMessage({
    required String token,
    required Map<String, String> content,
    String? label,
  }) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/saved-messages'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'content': content, 'label': label}),
    );
    if (response.statusCode != 201) throw Exception('Failed to save message');
    return jsonDecode(response.body);
  }

  static Future<List<Map<String, dynamic>>> getSavedMessages(String token) async {
    final response = await _client.get(
      Uri.parse('${Constants.serverUrl}/api/saved-messages'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['messages'] ?? []);
    }
    return [];
  }

  static Future<void> addGroupMember(String groupId, String memberId, Map<String, String> encryptedKey, String token) async {
    final response = await _client.post(
      Uri.parse('${Constants.serverUrl}/api/groups/$groupId/members'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'members': [memberId], 'encryptedKeys': {memberId: encryptedKey}}),
    );
    if (response.statusCode != 200) throw Exception('Failed to add member');
  }

  static Future<void> leaveGroup(String groupId, String token) async {
    final userId = await KeyStore.getUserId();
    final response = await _client.delete(
      Uri.parse('${Constants.serverUrl}/api/groups/$groupId/members/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) throw Exception('Failed to leave group');
  }

  /// Reset HTTP client (for testing)
  static void resetHttpClient([http.Client? newClient]) {
    _client.close();
    if (newClient != null) _client = newClient;
  }
}
