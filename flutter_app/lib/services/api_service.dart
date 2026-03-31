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

  static Future<List<AppUser>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.serverUrl}/api/users'),
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
}
