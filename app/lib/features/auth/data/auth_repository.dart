import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/token_store.dart';

class Me {
  final String id;
  final String email;
  final String nickname;

  const Me(this.id, this.email, this.nickname);

  factory Me.fromJson(Map<String, dynamic> j) =>
      Me(j['id'] as String, j['email'] as String, j['nickname'] as String);

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'nickname': nickname};
}

/// 오프라인에서도 로그인 상태를 유지하려고 마지막 사용자 정보를 저장한다.
abstract class MeStore {
  Future<Me?> read();
  Future<void> save(Me me);
  Future<void> clear();
}

class SecureMeStore implements MeStore {
  static const _key = 'me';
  final FlutterSecureStorage _storage;

  const SecureMeStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<Me?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return Me.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // 깨진 값은 없는 것으로 본다
    }
  }

  @override
  Future<void> save(Me me) =>
      _storage.write(key: _key, value: jsonEncode(me.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// 인증 API 호출. 실패는 [ApiError]로 던진다.
class AuthRepository {
  final Dio _dio;
  final TokenStore _tokens;
  final MeStore _meStore;

  AuthRepository(this._dio, this._tokens, this._meStore);

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      final err = e.error;
      throw err is ApiError
          ? err
          : const ApiError(null, 'NETWORK', '서버에 연결할 수 없습니다.');
    }
  }

  Future<Me> signup({
    required String email,
    required String password,
    required String nickname,
    required String inviteCode,
    required bool consentHealthData,
  }) =>
      _issueSession('/auth/signup', {
        'email': email,
        'password': password,
        'nickname': nickname,
        'inviteCode': inviteCode,
        'consentHealthData': consentHealthData,
      });

  Future<Me> login(String email, String password) =>
      _issueSession('/auth/login', {'email': email, 'password': password});

  Future<Me> _issueSession(String path, Map<String, dynamic> body) async {
    final res = await _call(() => _dio.post<Map>(path, data: body));
    await _tokens.save(Tokens(
      res.data!['accessToken'] as String,
      res.data!['refreshToken'] as String,
    ));
    return me();
  }

  /// 서버에서 내 정보를 받아 저장해 둔다.
  Future<Me> me() async {
    final res = await _call(() => _dio.get<Map>('/me'));
    final me = Me.fromJson(Map<String, dynamic>.from(res.data!));
    await _meStore.save(me);
    return me;
  }

  Future<bool> hasSession() async => await _tokens.read() != null;

  Future<Me?> storedMe() => _meStore.read();

  Future<void> clearMe() => _meStore.clear();

  /// 서버 로그아웃은 실패해도 기기의 로그인 정보는 지운다.
  Future<void> logout() async {
    final t = await _tokens.read();
    if (t != null) {
      try {
        await _call(() =>
            _dio.post('/auth/logout', data: {'refreshToken': t.refreshToken}));
      } on ApiError catch (_) {}
    }
    await _tokens.clear();
    await _meStore.clear();
  }
}
