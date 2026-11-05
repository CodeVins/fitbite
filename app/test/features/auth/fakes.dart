import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/core/theme.dart';
import 'package:fitbite/features/auth/data/auth_repository.dart';
import 'package:fitbite/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const testMe = Me('u1', 'a@test.com', '테스터');

/// 지정한 오류를 던지거나 testMe를 돌려주는 가짜 저장소.
class FakeAuthRepository implements AuthRepository {
  ApiError? error;
  bool session;
  Me? stored;
  Object? meResult; // Me 또는 ApiError

  FakeAuthRepository(
      {this.error, this.session = true, this.stored, this.meResult});

  @override
  Future<Me> login(String email, String password) async =>
      error != null ? throw error! : testMe;

  @override
  Future<Me> signup({
    required String email,
    required String password,
    required String nickname,
    required String inviteCode,
    required bool consentHealthData,
  }) async =>
      error != null ? throw error! : testMe;

  @override
  Future<Me> me() async {
    final r = meResult;
    if (r is ApiError) throw r;
    if (r is Exception) throw r;
    return (r as Me?) ?? testMe;
  }

  @override
  Future<bool> hasSession() async => session;
  @override
  Future<Me?> storedMe() async => stored;
  @override
  Future<void> clearMe() async => stored = null;
  @override
  Future<void> logout() async {}
}

/// 화면 하나를 테마와 함께 띄운다. 가입 화면이 길어 화면을 크게 잡는다.
Future<void> pumpScreen(WidgetTester tester, Widget screen,
    {required AuthRepository repo}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: buildAppTheme(), home: screen),
  ));
}
