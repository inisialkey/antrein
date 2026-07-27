import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Stable per-install device identity, sent with login (`device` payload) and
/// registered via `PUT /me/devices/{deviceId}`. Generated once and kept in
/// secure storage; a reinstall gets a fresh id and the backend moves the row.
@lazySingleton
class DeviceIdStore {
  const DeviceIdStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'device_id';
  // Crockford base32, matching the backend's ULID alphabet for familiarity.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Read the persisted id, generating and persisting one on first use.
  Future<String> obtain() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final suffix = List.generate(
      26,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
    final id = 'dev_$suffix';
    await _storage.write(key: _key, value: id);
    return id;
  }
}
