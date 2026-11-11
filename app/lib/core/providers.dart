import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/workout/data/local_db.dart';
import '../features/workout/data/sync_service.dart';
import '../features/workout/data/workout_api.dart';
import '../features/workout/data/workout_store.dart';
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

/// 운동 기록의 폰 저장소. 앱 전용 문서 폴더의 SQLite 파일을 처음 쓸 때 연다.
final workoutStoreProvider = Provider<WorkoutStore>((ref) {
  final db = LocalDb(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'fitbite.sqlite')));
  }));
  ref.onDispose(db.close);
  return WorkoutStore(db);
});

final workoutApiProvider =
    Provider<WorkoutApi>((ref) => WorkoutApi(ref.watch(dioProvider)));

final syncServiceProvider = Provider<SyncService>((ref) {
  final sync = SyncService(
    ref.watch(workoutStoreProvider),
    ref.watch(workoutApiProvider),
    isSignedIn: () => ref.read(authControllerProvider) is AuthSignedIn,
  );
  ref.onDispose(sync.stop);
  return sync;
});

/// 지금 시각. 테스트에서 바꿔 끼운다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
