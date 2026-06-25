import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  Future<String?> read(String key) async => _storage.read(key: key);

  Future<void> write(String key, String value) async =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) async => _storage.delete(key: key);
}
