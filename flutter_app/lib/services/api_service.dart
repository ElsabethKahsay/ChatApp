/// REST API client stub
class ApiService {
  // TODO: Implement actual API calls
  
  static Future<void> register({
    required String userId,
    required String username,
    required String publicKey,
  }) async {
    // TODO: Connect to backend
    await Future.delayed(const Duration(seconds: 1));
  }

  static Future<String> getPublicKey(String userId) async {
    // TODO: Fetch from backend
    await Future.delayed(const Duration(seconds: 1));
    return 'placeholder_public_key';
  }

  static Future<List<AppUser>> getUsers() async {
    // TODO: Fetch from backend
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }
}
