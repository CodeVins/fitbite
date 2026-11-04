import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import 'api_error.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1',
);

const _retriedKey = 'retried';
const _noRefreshPaths = ['/auth/login', '/auth/signup', '/auth/refresh'];

ApiError _toApiError(DioException e) {
  final data = e.response?.data;
  if (e.response != null && data is Map) {
    return ApiError(
      e.response!.statusCode,
      data['code']?.toString() ?? 'UNKNOWN',
      data['detail']?.toString() ?? '',
    );
  }
  if (e.response != null) {
    return ApiError(e.response!.statusCode, 'UNKNOWN', '');
  }
  return ApiError(null, 'NETWORK', '서버에 연결할 수 없습니다.');
}

DioException _withApiError(DioException e) => e.copyWith(error: _toApiError(e));

/// 모든 서버 호출이 거치는 dio 클라이언트.
/// 실패는 DioException으로 던져지며, `e.error`가 [ApiError]다.
/// [adapter], [refreshAdapter]는 테스트용 주입 지점이다.
Dio buildApiClient({
  required String baseUrl,
  required TokenStore tokens,
  required void Function() onSignedOut,
  HttpClientAdapter? adapter,
  HttpClientAdapter? refreshAdapter,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  if (adapter != null) dio.httpClientAdapter = adapter;

  // 재발급 요청은 인터셉터 없는 별도 Dio로 보낸다.
  final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
  if (refreshAdapter != null) refreshDio.httpClientAdapter = refreshAdapter;

  Future<void> signOut() async {
    if (await tokens.read() == null) return; // 동시 요청이 여러 번 부르지 않게
    await tokens.clear();
    onSignedOut();
  }

  Future<bool>? inflight;

  /// true: 재발급 성공, false: 서버가 거부해 로그아웃함.
  /// 네트워크/5xx 실패는 토큰을 유지한 채 DioException(error: ApiError)을 던진다.
  Future<bool> refresh() => inflight ??= () async {
        try {
          final current = await tokens.read();
          if (current == null) return false;
          final res = await refreshDio.post<Map>(
            '/auth/refresh',
            data: {'refreshToken': current.refreshToken},
          );
          await tokens.save(Tokens(
            res.data!['accessToken'] as String,
            res.data!['refreshToken'] as String,
          ));
          return true;
        } on DioException catch (e) {
          if (e.response?.statusCode == 401) {
            await signOut();
            return false;
          }
          throw _withApiError(e);
        } finally {
          inflight = null;
        }
      }();

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final t = await tokens.read();
      if (t != null) options.headers['Authorization'] = 'Bearer ${t.accessToken}';
      handler.next(options);
    },
    onError: (e, handler) async {
      final mapped = _withApiError(e);
      final o = e.requestOptions;
      if (e.response?.statusCode != 401 ||
          _noRefreshPaths.any(o.path.contains)) {
        return handler.next(mapped);
      }
      if (o.extra[_retriedKey] == true) {
        await signOut(); // 재시도도 401이면 한 번만 로그아웃
        return handler.next(mapped);
      }
      try {
        // 이미 다른 요청이 재발급을 끝냈다면(보낸 토큰 != 저장된 토큰) 재발급 없이 재시도한다.
        final cur = await tokens.read();
        final stale = cur != null &&
            o.headers['Authorization'] != 'Bearer ${cur.accessToken}';
        if (!stale && !await refresh()) return handler.next(mapped);
      } on DioException catch (re) {
        return handler.next(re);
      }
      try {
        o.extra[_retriedKey] = true;
        handler.resolve(await dio.fetch(o));
      } on DioException catch (re) {
        handler.next(re);
      }
    },
  ));
  return dio;
}
