import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  final String accessToken;
  final String refreshToken;

  const Tokens(this.accessToken, this.refreshToken);
}

abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> save(Tokens tokens);
  Future<void> clear();
}

/// flutter_secure_storage에 토큰을 저장한다.
class SecureTokenStore implements TokenStore {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<Tokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return Tokens(access, refresh);
  }

  @override
  Future<void> save(Tokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
