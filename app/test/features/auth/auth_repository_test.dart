import 'package:fitbite/core/api/api_client.dart';
import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api_client_test.dart' show FakeAdapter, MemoryTokenStore, json;

class _MemoryMeStore implements MeStore {
  Me? me;
  @override
  Future<Me?> read() async => me;
  @override
  Future<void> save(Me m) async => me = m;
  @override
  Future<void> clear() async => me = null;
}

void main() {
  test('login_meFails_clearsTokensAndRethrows', () async {
    final tokens = MemoryTokenStore();
    var signedOutCalls = 0;
    final api = FakeAdapter((o) => o.path.endsWith('/auth/login')
        ? json(200, {
            'accessToken': 'a',
            'refreshToken': 'r',
            'expiresInSeconds': 900
          })
        : json(500, {'code': 'INTERNAL', 'detail': 'x'}));
    final dio = buildApiClient(
        baseUrl: 'http://test/api/v1',
        tokens: tokens,
        onSignedOut: () => signedOutCalls++,
        adapter: api);
    final meStore = _MemoryMeStore();
    final repo = AuthRepository(dio, tokens, meStore);

    await expectLater(repo.login('a@test.com', 'password1'),
        throwsA(isA<ApiError>()));
    expect(await tokens.read(), isNull);
    expect(meStore.me, isNull);
    expect(signedOutCalls, 0);
  });
}
