import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitbite/core/api/api_client.dart';
import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/core/auth/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  Tokens? tokens;
  MemoryTokenStore([this.tokens]);
  @override
  Future<Tokens?> read() async => tokens;
  @override
  Future<void> save(Tokens t) async => tokens = t;
  @override
  Future<void> clear() async => tokens = null;
}

typedef Handler = FutureOr<ResponseBody> Function(RequestOptions o);

class FakeAdapter implements HttpClientAdapter {
  final Handler handler;
  final calls = <RequestOptions>[];
  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    calls.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

const refreshPath = '/api/v1/auth/refresh';
const base = 'http://test/api/v1';

String? bearer(RequestOptions o) => o.headers['Authorization'] as String?;

void main() {
  late MemoryTokenStore store;
  late int signedOut;
  late FakeAdapter api;
  late FakeAdapter refresh;

  setUp(() {
    store = MemoryTokenStore(const Tokens('old-a', 'old-r'));
    signedOut = 0;
  });

  Dio build(Handler apiHandler, Handler refreshHandler) {
    api = FakeAdapter(apiHandler);
    refresh = FakeAdapter(refreshHandler);
    return buildApiClient(
      baseUrl: base,
      tokens: store,
      onSignedOut: () => signedOut++,
      adapter: api,
      refreshAdapter: refresh,
    );
  }

  ResponseBody okRefresh(RequestOptions o) => json(200, {
        'accessToken': 'new-a',
        'refreshToken': 'new-r',
        'expiresInSeconds': 900,
      });

  // 토큰이 new-a일 때만 성공하는 API
  ResponseBody guarded(RequestOptions o) => bearer(o) == 'Bearer new-a'
      ? json(200, {'ok': true})
      : json(401, {'code': 'UNAUTHORIZED', 'detail': 'expired'});

  test('attachesBearerToken', () async {
    final dio = build((o) => json(200, {'ok': true}), okRefresh);
    await dio.get('/me');
    expect(bearer(api.calls.single), 'Bearer old-a');
  });

  test('on401_refreshesOnce_andRetries', () async {
    final dio = build(guarded, okRefresh);
    final r = await dio.get('/me');
    expect(r.statusCode, 200);
    expect(refresh.calls.length, 1);
    expect(api.calls.length, 2);
    expect(bearer(api.calls.last), 'Bearer new-a');
    expect(store.tokens!.accessToken, 'new-a');
    expect(store.tokens!.refreshToken, 'new-r');
  });

  test('concurrent401s_refreshOnlyOnce', () async {
    final dio = build(guarded, (o) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return okRefresh(o);
    });
    final rs = await Future.wait([dio.get('/a'), dio.get('/b'), dio.get('/c')]);
    expect(rs.every((r) => r.statusCode == 200), isTrue);
    expect(refresh.calls.length, 1);
  });

  test('refreshFails401_clearsTokens_andCallsOnSignedOut', () async {
    final dio = build(
      guarded,
      (o) => json(401, {'code': 'INVALID_REFRESH_TOKEN', 'detail': 'bad'}),
    );
    await expectLater(dio.get('/me'), throwsA(isA<DioException>()));
    expect(store.tokens, isNull);
    expect(signedOut, 1);
  });

  test('refreshNetworkFailure_keepsTokens', () async {
    final dio = build(guarded, (o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError));
    await expectLater(
      dio.get('/me'),
      throwsA(predicate((e) =>
          e is DioException &&
          e.error is ApiError &&
          (e.error as ApiError).code == 'NETWORK')),
    );
    expect(store.tokens!.refreshToken, 'old-r');
    expect(signedOut, 0);
  });

  test('refresh5xx_keepsTokens_andSurfacesError', () async {
    final dio = build(
      guarded,
      (o) => json(503, {'code': 'UNAVAILABLE', 'detail': 'down'}),
    );
    await expectLater(
      dio.get('/me'),
      throwsA(predicate((e) =>
          e is DioException &&
          e.error is ApiError &&
          (e.error as ApiError).status == 503)),
    );
    expect(store.tokens!.refreshToken, 'old-r');
    expect(signedOut, 0);
  });

  test('login401_doesNotRefresh', () async {
    final dio = build(
      (o) => json(401, {'code': 'INVALID_CREDENTIALS', 'detail': 'wrong'}),
      okRefresh,
    );
    await expectLater(
      dio.post('/auth/login', data: {'email': 'a'}),
      throwsA(predicate((e) =>
          e is DioException &&
          (e.error as ApiError).code == 'INVALID_CREDENTIALS')),
    );
    expect(refresh.calls, isEmpty);
    expect(signedOut, 0);
    expect(store.tokens, isNotNull);
  });

  test('retryAlso401_signsOutWithoutLooping', () async {
    final dio = build(
      (o) => json(401, {'code': 'UNAUTHORIZED', 'detail': 'no'}),
      okRefresh,
    );
    await expectLater(dio.get('/me'), throwsA(isA<DioException>()));
    expect(api.calls.length, 2);
    expect(refresh.calls.length, 1);
    expect(signedOut, 1);
    expect(store.tokens, isNull);
  });

  test('lateStale401_retriesWithoutSecondRefresh', () async {
    // C는 옛 토큰으로 나갔고, 401은 A의 재발급이 끝난 뒤에 도착한다.
    final dio = build((o) async {
      if (o.path == '/c' && bearer(o) != 'Bearer new-a') {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return json(401, {'code': 'UNAUTHORIZED', 'detail': 'expired'});
      }
      return guarded(o);
    }, (o) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return okRefresh(o);
    });
    final rs = await Future.wait([dio.get('/a'), dio.get('/c')]);
    expect(rs.every((r) => r.statusCode == 200), isTrue);
    expect(refresh.calls.length, 1);
    expect(bearer(api.calls.last), 'Bearer new-a');
    expect(signedOut, 0);
  });

  test('problemDetail_mapsToApiError', () async {
    final dio = build(
      (o) => json(400, {'code': 'VALIDATION_FAILED', 'detail': 'weight must be positive'}),
      okRefresh,
    );
    try {
      await dio.get('/x');
      fail('should throw');
    } on DioException catch (e) {
      final err = e.error as ApiError;
      expect(err.status, 400);
      expect(err.code, 'VALIDATION_FAILED');
      expect(err.message, 'weight must be positive');
    }
  });

  test('noConnection_mapsToNetworkApiError', () async {
    final dio = build((o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError), okRefresh);
    try {
      await dio.get('/x');
      fail('should throw');
    } on DioException catch (e) {
      final err = e.error as ApiError;
      expect(err.status, isNull);
      expect(err.code, 'NETWORK');
    }
  });
}
