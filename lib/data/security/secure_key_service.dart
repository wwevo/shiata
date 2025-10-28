import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages generation and retrieval of the database encryption key.
class SecureKeyService {
  SecureKeyService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'db_key_v1';

  final FlutterSecureStorage _storage;

  /// Returns a stable 256-bit (32 bytes) key encoded as base64.
  Future<String> obtainKey() async {
    var existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final keyB64 = _generateKeyBase64();
    await _storage.write(key: _keyName, value: keyB64);
    return keyB64;
  }

  /// Deletes the stored key (use with caution).
  Future<void> resetKey() async {
    await _storage.delete(key: _keyName);
  }

  /// Generate a cryptographically secure random 256-bit key and return base64.
  String _generateKeyBase64() {
    final rnd = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Convenience to get raw bytes from stored base64 key.
  static Uint8List keyBytesFromBase64(String b64) => base64Decode(b64);

  @visibleForTesting
  FlutterSecureStorage get storage => _storage;
}
