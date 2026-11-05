import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitbite/core/api/api_client.dart';
import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/core/auth/token_store.dart';
import 'package:fitbite/core/providers.dart';
import 'package:fitbite/features/auth/data/auth_repository.dart';
import 'package:fitbite/features/auth/presentation/auth_controller.dart';
import 'package:fitbite/features/workout/data/local_db.dart';
import 'package:fitbite/features/workout/data/sync_service.dart';
import 'package:fitbite/features/workout/data/workout_api.dart';
import 'package:fitbite/features/workout/data/workout_store.dart';
import 'package:fitbite/features/workout/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api_client_test.dart' show FakeAdapter, MemoryTokenStore, json;
import '../auth/fakes.dart';
import 'sync_fakes.dart';

const network = ApiError(null, 'NETWORK', 'x');
ApiError status(int s) => ApiError(s, 'X', 'x');

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LocalDb db;
  late WorkoutStore store;
  late FakeWorkoutApi api;
  late SyncService sync;
  late DateTime clock;
  var signedIn = true;

  setUp(() {
    clock = DateTime.utc(2026, 1, 1, 9);
    signedIn = true;
    db = LocalDb(NativeDatabase.memory());
    // 호출할 때마다 1분씩 흘러 세션 순서가 정해진다.
    store = WorkoutStore(db,
        now: () => clock = clock.add(const Duration(minutes: 1)));
    api = FakeWorkoutApi();
    sync = SyncService(store, api, isSignedIn: () => signedIn);
    addTearDown(() async {
      sync.stop();
      await db.close();
    });
  });

  group('push', () {
    test('push_sendsCustomExercisesBeforeSessions', () async {
      final ex = await store.addCustomExercise('내 운동', 'band', 'CORE');
      final sid = await finishedSession(store, exerciseId: ex.id);

      await sync.push();

      expect(api.calls, ['putExercise:${ex.id}', 'putWorkout:$sid']);
      expect(await store.pendingExercises(), isEmpty);
    });

    test('push_success_removesSessionFromLocal', () async {
      await finishedSession(store);
      await sync.push();
      expect(await store.pendingSessions(), isEmpty);
      expect(await db.select(db.localSessions).get(), isEmpty);
      expect(await db.select(db.localSets).get(), isEmpty);
      // 지난 기록 캐시는 남는다.
      expect(await store.lastSets('e1'), hasLength(1));
    });

    test('push_networkError_keepsPending_stopsWithoutError', () async {
      final a = await finishedSession(store);
      await finishedSession(store);
      api.failWith = (_) => network;

      await sync.push(); // 던지지 않는다

      expect(api.callsOf('putWorkout'), [a]); // 첫 실패에서 멈춘다
      expect(await store.pendingSessions(), hasLength(2));
    });

    for (final s in [500, 503, 401]) {
      test('push_status${s}_keepsPending_stops', () async {
        final a = await finishedSession(store);
        await finishedSession(store);
        api.failWith = (_) => status(s);

        await sync.push();

        expect(api.callsOf('putWorkout'), [a]);
        expect(await store.pendingSessions(), hasLength(2));
        expect((await sessionRow(db, a)).syncState, SessionSyncState.pending);
      });
    }

    for (final s in [400, 404, 409]) {
      test('push_${s}_marksFailed_keepsData_otherSessionsContinue', () async {
        final a = await finishedSession(store);
        final b = await finishedSession(store);
        api.failWith = (c) => c == 'putWorkout:$a' ? status(s) : null;

        await sync.push();

        final row = await sessionRow(db, a);
        expect(row.syncState, SessionSyncState.failed);
        expect(row.failureMessage, isNotEmpty);
        expect(await db.select(db.localSets).get(), hasLength(1)); // a의 세트만 남음
        expect(api.callsOf('putWorkout'), [a, b]);
        expect(await store.pendingSessions(), isEmpty);
      });
    }

    test('push_failedSessions_notRetriedAutomatically', () async {
      final a = await finishedSession(store);
      api.failWith = (_) => status(400);
      await sync.push();
      await sync.push();
      expect(api.callsOf('putWorkout'), [a]);
    });

    test('push_exerciseRejected_staysPending_sessionsStillSent', () async {
      final ex = await store.addCustomExercise('내 운동', 'band', 'CORE');
      final sid = await finishedSession(store, exerciseId: 'other');
      api.failWith = (c) => c.startsWith('putExercise') ? status(400) : null;

      await sync.push();

      expect((await store.pendingExercises()).map((e) => e.id), [ex.id]);
      expect(api.callsOf('putWorkout'), [sid]);
    });

    test('push_concurrentCalls_sendOnce', () async {
      await finishedSession(store);
      final gate = Completer<void>();
      api.gate = gate.future;

      final f1 = sync.push();
      final f2 = sync.push();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await Future.wait([f1, f2]);

      expect(api.callsOf('putWorkout'), hasLength(1));
    });

    test('push_serverSeesSameIdOnRetry', () async {
      final sid = await finishedSession(store);
      api.failWith = (_) => network; // 응답을 잃은 것처럼 실패
      await sync.push();
      api.failWith = null;
      await sync.push();
      expect(api.callsOf('putWorkout'), [sid, sid]);
      expect(await store.pendingSessions(), isEmpty);
    });

    test('push_whenSignedOut_sendsNothing', () async {
      await finishedSession(store);
      signedIn = false;
      await sync.push();
      expect(api.calls, isEmpty);
      expect(await store.pendingSessions(), hasLength(1));
    });
  });

  group('refreshCatalog', () {
    test('refreshCatalog_replacesExercises_keepsPendingCustom', () async {
      await db.into(db.localExercises).insert(LocalExercisesCompanion.insert(
          id: 'old', name: '옛 운동', equipment: 'x', bodyPart: 'CHEST'));
      final mine = await store.addCustomExercise('내 운동', 'band', 'CORE');
      api.exercises = const [
        Exercise(id: 's1', name: '서버 운동', equipment: 'barbell', bodyPart: 'LEGS')
      ];

      await sync.refreshCatalog();

      final names = (await store.searchExercises('')).map((e) => e.name);
      expect(names, unorderedEquals(['서버 운동', '내 운동']));
      expect((await store.pendingExercises()).single.id, mine.id);
    });

    test('refreshCatalog_keepsNewerLocalLastPerformance', () async {
      await finishedSession(store, exerciseId: 'e1', weightKg: 80); // 미전송
      api.last = {
        'e1': const [LastSet(weightKg: 50, reps: 5)],
        'e2': const [LastSet(weightKg: 30, reps: 8)],
      };

      await sync.refreshCatalog();

      expect((await store.lastSets('e1')).single.weightKg, 80);
      expect((await store.lastSets('e2')).single.weightKg, 30);
    });

    test('refreshCatalog_networkError_keepsCache', () async {
      await db.into(db.localExercises).insert(LocalExercisesCompanion.insert(
          id: 'old', name: '옛 운동', equipment: 'x', bodyPart: 'CHEST'));
      await finishedSession(store);
      api.catalogError = network;

      await sync.refreshCatalog(); // 던지지 않는다

      expect(await store.searchExercises('옛'), hasLength(1));
      expect(await store.lastSets('e1'), hasLength(1));
    });
  });

  group('stop과 타이머', () {
    test('stop_duringPutWorkout_remainingSessionsNotSent', () async {
      final a = await finishedSession(store);
      await finishedSession(store);
      final gate = Completer<void>();
      api.gate = gate.future;

      final run = sync.push();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      sync.stop(); // 로그아웃 등으로 중단
      gate.complete();
      await run;

      expect(api.callsOf('putWorkout'), [a]);
      expect(await store.pendingSessions(), hasLength(1));
    });

    test('stop_duringRefreshCatalog_discardsResult', () async {
      final gate = Completer<void>();
      api.catalogGate = gate.future;
      api.exercises = const [
        Exercise(id: 's1', name: '서버 운동', equipment: 'barbell', bodyPart: 'LEGS')
      ];
      api.last = {'s1': const [LastSet(weightKg: 30, reps: 8)]};

      final run = sync.refreshCatalog();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      sync.stop();
      gate.complete();
      await run;

      expect(await store.searchExercises(''), isEmpty);
      expect(await store.lastSets('s1'), isEmpty);
    });

    test('lateUnauthorized_afterAccountSwitch_doesNotResendUnderNewAccount',
        () async {
      final sid = await finishedSession(store);
      final tokens = MemoryTokenStore(const Tokens('a-old', 'a-r'));
      final late401 = Completer<void>();
      final adapter = FakeAdapter((o) async {
        await late401.future; // A의 요청이 서버에서 늦게 401로 돌아온다
        return json(401, {'code': 'UNAUTHORIZED', 'detail': 'x'});
      });
      final dio = buildApiClient(
          baseUrl: 'http://test/api/v1',
          tokens: tokens,
          onSignedOut: () {},
          adapter: adapter,
          refreshAdapter: FakeAdapter((_) => json(500, {})));
      final real = SyncService(store, WorkoutApi(dio), isSignedIn: () => true);
      addTearDown(real.stop);

      final run = real.push();
      for (var i = 0; i < 100 && adapter.calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(adapter.calls, hasLength(1));
      // A가 나가고 B가 로그인해 토큰이 바뀐 뒤에 401이 도착한다.
      real.stop();
      await tokens.save(const Tokens('b-new', 'b-r'));
      late401.complete();
      await run;

      expect(adapter.calls, hasLength(1)); // B 토큰으로 다시 보내지 않는다
      expect(adapter.calls.single.path, contains(sid));
      expect(await store.pendingSessions(), hasLength(1));
    });

    SyncService timed() {
      final s = SyncService(store, api,
          isSignedIn: () => signedIn,
          interval: const Duration(milliseconds: 20));
      addTearDown(s.stop);
      return s;
    }

    test('timer_noPendingWork_makesNoCalls', () async {
      timed().start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.calls, isEmpty);
    });

    test('timer_pendingWork_pushes', () async {
      await finishedSession(store);
      timed().start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.callsOf('putWorkout'), hasLength(1));
      expect(await store.pendingSessions(), isEmpty);
    });

    test('timer_afterStop_sendsNothing', () async {
      final s = timed()..start();
      s.stop();
      await finishedSession(store);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.calls, isEmpty);
    });
  });

  group('계정 전환', () {
    late ProviderContainer c;
    late FakeAuthRepository repo;
    const other = Me('u2', 'b@test.com', '다른사람');

    setUp(() {
      repo = FakeAuthRepository(session: false);
      c = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        workoutStoreProvider.overrideWithValue(store),
        workoutApiProvider.overrideWithValue(api),
      ]);
      addTearDown(c.dispose);
    });

    // 로그인 직후 컨트롤러가 띄운 동기화가 끝나기를 기다린다.
    Future<void> settled() async {
      await c.read(syncServiceProvider).push();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    Future<void> loginAs(Me me) async {
      repo.loginAs = me;
      await c.read(authControllerProvider.notifier).login('a', 'b');
      await settled();
    }

    test('signedOutByExpiry_keepsPending', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await loginAs(testMe);
      final sid = await finishedSession(store);
      api.failWith = (_) => status(401);
      await c.read(syncServiceProvider).push();

      await c.read(authControllerProvider.notifier).sessionExpired();
      expect(c.read(authControllerProvider), isA<AuthSignedOut>());
      expect(await store.pendingSessions(), hasLength(1));

      api.failWith = null;
      api.calls.clear();
      await loginAs(testMe); // 같은 사용자

      expect(api.callsOf('putWorkout'), [sid]);
      expect(await store.pendingSessions(), isEmpty);
    });

    test('loginAsOtherUser_doesNotUploadPreviousData', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await loginAs(testMe);
      await finishedSession(store);
      await store.addCustomExercise('내 운동', 'band', 'CORE');
      await c.read(authControllerProvider.notifier).sessionExpired();
      api.calls.clear();

      await loginAs(other);

      expect(api.callsOf('putWorkout'), isEmpty);
      expect(api.callsOf('putExercise'), isEmpty);
      expect(await store.hasUnsent(), isFalse);
    });

    test('login_neverBlocksOnCatalogFailure', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      api.catalogError = network;
      await loginAs(testMe);
      expect(c.read(authControllerProvider), isA<AuthSignedIn>());
      expect(api.calls, contains('listExercises'));
    });

    test('restore_offlineWithStoredMe_stillEnsuresOwner', () async {
      await store.ensureOwner('someone-else');
      await finishedSession(store);
      repo
        ..session = true
        ..stored = testMe
        ..meResult = network;
      c.read(authControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(c.read(authControllerProvider), isA<AuthSignedIn>());
      expect(await store.hasUnsent(), isFalse); // 다른 사용자의 기록은 지워졌다
    });
  });
}
