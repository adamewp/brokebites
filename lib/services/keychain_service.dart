import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeychainService {
  static const _storage = FlutterSecureStorage();
  
  // Keys for storing different types of data
  static const String _emailKey = 'user_email';
  static const String _usernameKey = 'username';
  static const String _passwordKey = 'password';

  // Save user credentials
  Future<void> saveCredentials({
    required String email,
    required String password,
    String? username,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
    if (username != null) {
      await _storage.write(key: _usernameKey, value: username);
    }
  }

  // Get saved email
  Future<String?> getSavedEmail() async {
    return await _storage.read(key: _emailKey);
  }

  // Get saved username
  Future<String?> getSavedUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  // Get saved password
  Future<String?> getSavedPassword() async {
    return await _storage.read(key: _passwordKey);
  }

  // Delete all saved credentials
  Future<void> deleteAllCredentials() async {
    await _storage.deleteAll();
  }

  // Check if credentials exist
  Future<bool> hasStoredCredentials() async {
    final email = await getSavedEmail();
    final password = await getSavedPassword();
    return email != null && password != null;
  }
} 