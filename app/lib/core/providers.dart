import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import 'api/api_client.dart';
import 'auth/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => const SecureTokenStore());

/// 모든 서버 호출이 거치는 dio. 로그아웃이 확정되면 인증 상태를 바꾼다.
final dioProvider = Provider<Dio>((ref) => buildApiClient(
      baseUrl: apiBaseUrl,
      tokens: ref.watch(tokenStoreProvider),
      onSignedOut: () =>
          ref.read(authControllerProvider.notifier).sessionExpired(),
    ));
