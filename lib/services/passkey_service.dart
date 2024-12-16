import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasskeyService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isPasskeyAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveCredentialsWithPasskey({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final bool isAvailable = await isPasskeyAvailable();
      if (!isAvailable) return false;

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Save your credentials securely with Passkey',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuthenticate) {
        // Save credentials securely
        await _storage.write(key: 'passkey_email', value: email);
        await _storage.write(key: 'passkey_password', value: password);
        if (username != null) {
          await _storage.write(key: 'passkey_username', value: username);
        }
        return true;
      }
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<Map<String, String?>> getCredentialsWithPasskey() async {
    try {
      final bool isAvailable = await isPasskeyAvailable();
      if (!isAvailable) return {};

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to access your saved credentials',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuthenticate) {
        final email = await _storage.read(key: 'passkey_email');
        final password = await _storage.read(key: 'passkey_password');
        final username = await _storage.read(key: 'passkey_username');

        return {
          'email': email,
          'password': password,
          'username': username,
        };
      }
      return {};
    } on PlatformException {
      return {};
    }
  }

  Future<void> clearPasskeyCredentials() async {
    await _storage.delete(key: 'passkey_email');
    await _storage.delete(key: 'passkey_password');
    await _storage.delete(key: 'passkey_username');
  }
}
