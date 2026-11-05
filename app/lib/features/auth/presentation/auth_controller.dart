import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  final Me me;
  const AuthSignedIn(this.me);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(ref.watch(dioProvider), ref.watch(tokenStoreProvider),
        const SecureMeStore()));

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthLoading();
  }

  /// 앱 시작 시 저장된 세션을 확인한다.
  /// 서버가 토큰을 거부(401)하면 로그아웃, 네트워크/서버 장애면 저장된 사용자로
  /// 로그인 상태를 유지해 오프라인에서도 운동을 시작할 수 있게 한다.
  Future<void> _restore() async {
    if (!await _repo.hasSession()) {
      state = const AuthSignedOut();
      return;
    }
    try {
      await _enterSignedIn(await _repo.me());
    } catch (e) {
      if (e is ApiError && e.status == 401) {
        await sessionExpired();
        return;
      }
      // 예상 못 한 오류(저장소, 파싱 등)도 로딩에 멈추지 않도록 저장된 사용자로 대체한다.
      Me? stored;
      try {
        stored = await _repo.storedMe();
      } catch (_) {}
      // 저장된 사용자가 없으면 보여 줄 사용자가 없어 로그인 화면으로 보낸다(토큰은 유지).
      if (stored == null) {
        state = const AuthSignedOut();
      } else {
        await _enterSignedIn(stored);
      }
    }
  }

  Future<void> login(String email, String password) async =>
      _enterSignedIn(await _repo.login(email, password));

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
    required String inviteCode,
    required bool consentHealthData,
  }) async =>
      _enterSignedIn(await _repo.signup(
        email: email,
        password: password,
        nickname: nickname,
        inviteCode: inviteCode,
        consentHealthData: consentHealthData,
      ));

  /// 로그인 상태로 바꾸고 동기화를 시작한다. 동기화는 인증을 기다리게 하지 않는다.
  Future<void> _enterSignedIn(Me me) async {
    var ownerReady = true;
    try {
      // 다른 계정의 미전송 기록이 섞여 올라가지 않도록 가장 먼저 소유자를 맞춘다.
      await ref.read(workoutStoreProvider).ensureOwner(me.id);
    } catch (e) {
      ownerReady = false;
      debugPrint('ensureOwner failed: ${e.runtimeType}');
    }
    state = AuthSignedIn(me);
    if (ownerReady) unawaited(_syncAfterSignIn());
  }

  Future<void> _syncAfterSignIn() async {
    try {
      final sync = ref.read(syncServiceProvider);
      await sync.refreshCatalog();
      await sync.push();
      if (state is AuthSignedIn) sync.start();
    } catch (e) {
      debugPrint('sign-in sync failed: ${e.runtimeType}');
    }
  }

  void _stopSync() {
    try {
      ref.read(syncServiceProvider).stop();
    } catch (e) {
      debugPrint('stop sync failed: ${e.runtimeType}');
    }
  }

  /// 확정된 로그아웃. 폰에 남은 기록도 지운다(화면에서 먼저 확인을 받는다).
  Future<void> logout() async {
    _stopSync();
    await _repo.logout();
    try {
      await ref.read(workoutStoreProvider).clearAll();
    } catch (e) {
      debugPrint('clearAll failed: ${e.runtimeType}');
    }
    state = const AuthSignedOut();
  }

  /// 토큰 재발급까지 거부되어 api 클라이언트가 로그아웃시켰을 때 불린다.
  /// 폰의 기록은 지우지 않는다. 같은 계정으로 다시 로그인하면 전송된다.
  Future<void> sessionExpired() async {
    _stopSync();
    await _repo.clearMe();
    state = const AuthSignedOut();
  }
}

/// 서버 오류 코드를 화면에 보일 한국어 문구로 바꾼다.
String authErrorMessage(Object e) {
  if (e is! ApiError) return '잠시 후 다시 시도해 주세요.';
  return switch (e.code) {
    'NETWORK' => '서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.',
    'INVALID_CREDENTIALS' => '이메일 또는 비밀번호가 올바르지 않습니다.',
    'INVALID_INVITE_CODE' => '초대 코드가 올바르지 않습니다.',
    'EMAIL_TAKEN' => '이미 가입된 이메일입니다.',
    'CONSENT_REQUIRED' => '건강 정보 수집·이용에 동의해 주세요.',
    'VALIDATION_ERROR' => '입력값을 확인해 주세요. 비밀번호는 8자 이상이어야 합니다.',
    _ => '잠시 후 다시 시도해 주세요.',
  };
}
