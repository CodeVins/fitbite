import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<AuthState> _start(FakeAuthRepository repo) async {
  final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  c.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c.read(authControllerProvider);
}

void main() {
  test('restore_noToken_signedOut', () async {
    expect(await _start(FakeAuthRepository(session: false)),
        isA<AuthSignedOut>());
  });

  test('restore_networkFailure_keepsStoredMe', () async {
    final s = await _start(FakeAuthRepository(
        stored: testMe, meResult: const ApiError(null, 'NETWORK', 'x')));
    expect(s, isA<AuthSignedIn>());
    expect((s as AuthSignedIn).me.nickname, '테스터');
  });

  test('restore_serverError_keepsStoredMe', () async {
    final s = await _start(FakeAuthRepository(
        stored: testMe, meResult: const ApiError(503, 'UNKNOWN', 'x')));
    expect(s, isA<AuthSignedIn>());
  });

  test('restore_unauthorized_signsOut', () async {
    final repo = FakeAuthRepository(
        stored: testMe, meResult: const ApiError(401, 'UNAUTHORIZED', 'x'));
    expect(await _start(repo), isA<AuthSignedOut>());
    expect(repo.stored, isNull);
  });

  test('restore_success_signedIn', () async {
    expect(await _start(FakeAuthRepository()), isA<AuthSignedIn>());
  });

  test('restore_unexpectedError_fallsBackToStoredMe', () async {
    final s = await _start(
        FakeAuthRepository(stored: testMe, meResult: Exception('boom')));
    expect(s, isA<AuthSignedIn>());
  });

  test('restore_unexpectedError_noStoredMe_signedOut', () async {
    final s = await _start(FakeAuthRepository(meResult: Exception('boom')));
    expect(s, isA<AuthSignedOut>());
  });
}
