import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitbite/app.dart';
import 'package:fitbite/core/notifications.dart';
import 'package:fitbite/core/providers.dart';
import 'package:fitbite/core/theme.dart';
import 'package:fitbite/features/auth/presentation/auth_controller.dart';
import 'package:fitbite/features/workout/data/local_db.dart';
import 'package:fitbite/features/workout/data/sync_service.dart';
import 'package:fitbite/features/workout/data/workout_store.dart';
import 'package:fitbite/features/workout/domain/models.dart';
import 'package:fitbite/features/workout/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/fakes.dart';
import 'sync_fakes.dart';

/// 호출을 기록한다. fail이면 권한 거부처럼 모든 호출이 던진다.
class FakeRestNotifier implements RestNotifier {
  final calls = <String>[];
  bool fail = false;

  void _record(String c) {
    calls.add(c);
    if (fail) throw Exception('permission denied');
  }

  @override
  Future<void> prepare() async => _record('prepare');
  @override
  Future<void> schedule(DateTime endsAt) async =>
      _record('schedule:${endsAt.toUtc().toIso8601String()}');
  @override
  Future<void> cancel() async => _record('cancel');
}

class _FixedAuth extends AuthController {
  @override
  AuthState build() => const AuthSignedIn(testMe);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DateTime clock;
  late LocalDb db;
  late WorkoutStore store;
  late FakeRestNotifier notifier;
  late FakeWorkoutApi api;

  String iso(DateTime t) => t.toUtc().toIso8601String();

  setUp(() async {
    clock = DateTime.utc(2026, 1, 1, 9);
    db = LocalDb(NativeDatabase.memory());
    store = WorkoutStore(db, now: () => clock);
    notifier = FakeRestNotifier();
    api = FakeWorkoutApi();
    await store.replaceExercises(const [
      Exercise(id: 'e1', name: '벤치 프레스', equipment: '바벨', bodyPart: 'CHEST'),
      Exercise(id: 'e2', name: '스쿼트', equipment: '바벨', bodyPart: 'LEGS'),
    ]);
    await store.replaceLastPerformance(const {
      'e1': [
        LastSet(weightKg: 60, reps: 10),
        LastSet(weightKg: 60, reps: 8),
        LastSet(weightKg: 57.5, reps: 8),
      ],
    });
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
        workoutStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => clock),
        restNotifierProvider.overrideWithValue(notifier),
        syncServiceProvider.overrideWith((ref) =>
            SyncService(store, api, isSignedIn: () => true)),
      ];

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// 진행 중 운동이 있는 상태로 운동 진행 화면만 띄운다.
  Future<void> pumpScreen(WidgetTester tester) async {
    bigView(tester);
    await store.startWorkout();
    final router = GoRouter(initialLocation: '/workout/active', routes: [
      GoRoute(
          path: '/workout/active',
          builder: (_, _) => const ActiveWorkoutScreen()),
      GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String name) async {
    final open = find.text('운동 선택');
    await tapText(
        tester, open.evaluate().isNotEmpty ? '운동 선택' : '운동 바꾸기');
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text(name)));
    await tester.pumpAndSettle();
  }

  /// 시계를 옮기고 1초 표시 타이머가 다시 계산하게 한다.
  Future<void> advance(WidgetTester tester, int seconds) async {
    clock = clock.add(Duration(seconds: seconds));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('sameAsLastTime_recordsWithOneTap', (tester) async {
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');
    expect(find.text('바벨 · 가슴'), findsOneWidget);
    expect(find.textContaining('60×10 · 60×8 · 57.5×8'), findsOneWidget);
    expect(textOf(tester, 'weightValue'), '60');
    expect(textOf(tester, 'repsValue'), '10');
    expect(find.text('1세트 · 지난번 1세트 값으로 채움'), findsOneWidget);

    await tapText(tester, '세트 완료');

    final sets = (await store.activeWorkout())!.sets;
    expect(sets, hasLength(1));
    expect(sets.single.exerciseId, 'e1');
    expect(sets.single.weightKg, 60);
    expect(sets.single.reps, 10);
    expect(find.text('60 kg × 10회'), findsOneWidget);
  });

  testWidgets('completeSet_showsTimer_andSchedulesNotification',
      (tester) async {
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');
    await tapText(tester, '세트 완료');

    expect(find.text('휴식 · 90초 중'), findsOneWidget);
    expect(textOf(tester, 'restRemaining'), '1:30');
    expect(find.text('다른 운동 추가'), findsOneWidget);
    expect(find.text('세트 완료'), findsNothing);
    final ends = clock.add(const Duration(seconds: 90));
    expect(notifier.calls, ['schedule:${iso(ends)}']);
    expect((await store.activeWorkout())!.restEndsAt, ends);

    await advance(tester, 6);
    expect(textOf(tester, 'restRemaining'), '1:24');
    await advance(tester, 200);
    expect(textOf(tester, 'restRemaining'), '0:00');
  });

  testWidgets('nextSetStart_savesRest_cancelsNotification_hidesTimer',
      (tester) async {
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');
    await tapText(tester, '세트 완료');
    await advance(tester, 75);
    await tapText(tester, '다음 세트 시작');

    final w = (await store.activeWorkout())!;
    expect(w.sets.single.restSeconds, 75);
    expect(w.restEndsAt, isNull);
    expect(notifier.calls.last, 'cancel');
    expect(find.textContaining('휴식'), findsNothing);
    expect(find.text('세트 완료'), findsOneWidget);
    expect(find.text('2세트 · 지난번 2세트 값으로 채움'), findsOneWidget);
    expect(textOf(tester, 'repsValue'), '8');
  });

  testWidgets('adjustTimer_plusMinus30_clampsAt30_remembersLength',
      (tester) async {
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');
    await tapText(tester, '세트 완료');
    final done = clock;

    await tapText(tester, '+30초');
    expect(find.text('휴식 · 120초 중'), findsOneWidget);
    expect(textOf(tester, 'restRemaining'), '2:00');
    expect((await store.activeWorkout())!.restEndsAt,
        done.add(const Duration(seconds: 120)));
    expect(notifier.calls.last,
        'schedule:${iso(done.add(const Duration(seconds: 120)))}');
    expect(await store.restLengthSeconds(), 120);

    for (var i = 0; i < 5; i++) {
      await tapText(tester, '-30초');
    }
    expect(find.text('휴식 · 30초 중'), findsOneWidget);
    expect((await store.activeWorkout())!.restEndsAt,
        done.add(const Duration(seconds: 30)));
    expect(await store.restLengthSeconds(), 30);

    // 다음 세트도 마지막으로 쓴 길이로 시작한다.
    await tapText(tester, '다음 세트 시작');
    await tapText(tester, '세트 완료');
    expect(find.text('휴식 · 30초 중'), findsOneWidget);
    expect(notifier.calls.last,
        'schedule:${iso(clock.add(const Duration(seconds: 30)))}');
  });

  testWidgets('prefill_appliedAfterExerciseSelect', (tester) async {
    await pumpScreen(tester);
    expect(find.text('세트 완료'), findsNothing);

    await pick(tester, '스쿼트');
    expect(find.text('지난번 기록 없음'), findsOneWidget);
    expect(textOf(tester, 'weightValue'), '0');
    expect(textOf(tester, 'repsValue'), '10');
    expect(find.text('1세트'), findsOneWidget);

    await pick(tester, '벤치 프레스');
    expect(textOf(tester, 'weightValue'), '60');
    await tapText(tester, '+1');
    expect(find.text('1세트'), findsOneWidget); // 바꾸면 "채움" 표시가 사라진다
    await tapText(tester, '세트 완료');
    await tapText(tester, '다음 세트 시작');

    // 다른 운동으로 갔다 돌아와도 오늘 기록을 반영한다.
    await pick(tester, '스쿼트');
    await pick(tester, '벤치 프레스');
    expect(textOf(tester, 'weightValue'), '60');
    expect(textOf(tester, 'repsValue'), '11');
    expect(find.text('2세트 · 직전 세트 값으로 채움'), findsOneWidget);
  });

  testWidgets('notifierThrows_stillRecordsSetAndRunsTimer', (tester) async {
    notifier.fail = true;
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');
    await tapText(tester, '세트 완료');

    expect((await store.activeWorkout())!.sets, hasLength(1));
    expect(textOf(tester, 'restRemaining'), '1:30');
    await advance(tester, 10);
    expect(textOf(tester, 'restRemaining'), '1:20');
    await tapText(tester, '+30초');
    expect(find.text('휴식 · 120초 중'), findsOneWidget);
    await tapText(tester, '다음 세트 시작');
    expect(find.text('세트 완료'), findsOneWidget);
    expect((await store.activeWorkout())!.sets.single.restSeconds, 10);
  });

  testWidgets('reopen_restoresScreenAndTimer', (tester) async {
    bigView(tester);
    // 강제 종료 전 상태: 세트 하나 완료, 휴식 중.
    await store.startWorkout();
    await store.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    await store.setRestEndsAt(clock.add(const Duration(seconds: 90)));
    clock = clock.add(const Duration(seconds: 30));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...overrides(),
        authControllerProvider.overrideWith(_FixedAuth.new),
      ],
      child: const App(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveWorkoutScreen), findsOneWidget);
    expect(find.text('벤치 프레스'), findsOneWidget);
    expect(find.text('60 kg × 10회'), findsOneWidget);
    expect(textOf(tester, 'restRemaining'), '1:00');
    await advance(tester, 15);
    expect(textOf(tester, 'restRemaining'), '0:45');
  });

  testWidgets('finishWithNoSets_discardsWithoutPending', (tester) async {
    await pumpScreen(tester);
    await tapText(tester, '운동 종료');
    expect(find.textContaining('저장되지 않습니다'), findsOneWidget);
    await tapText(tester, '종료');

    expect(await store.activeWorkout(), isNull);
    expect(await store.hasUnsent(), isFalse);
    expect(api.callsOf('putWorkout'), isEmpty);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('finish_triggersPush_andReturnsHome', (tester) async {
    await pumpScreen(tester);
    final id = (await store.activeWorkout())!.id;
    await pick(tester, '벤치 프레스');
    await tapText(tester, '세트 완료');
    await tapText(tester, '운동 종료');
    await tapText(tester, '종료');

    expect(api.callsOf('putWorkout'), [id]);
    expect(await store.activeWorkout(), isNull);
    expect(notifier.calls.last, 'cancel');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('editAndDeleteSet_duringWorkout', (tester) async {
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');
    await tapText(tester, '세트 완료');
    await tapText(tester, '다음 세트 시작');
    await tapText(tester, '세트 완료');

    await tapText(tester, '60 kg × 10회');
    await tester.enterText(find.byKey(const Key('editWeight')), '62.5');
    await tester.enterText(find.byKey(const Key('editReps')), '9');
    await tapText(tester, '저장');
    var sets = (await store.activeWorkout())!.sets;
    expect(sets.first.weightKg, 62.5);
    expect(sets.first.reps, 9);
    expect(sets.first.restSeconds, 0); // 휴식 기록은 그대로 둔다
    expect(find.text('62.5 kg × 9회'), findsOneWidget);

    await tapText(tester, '60 kg × 8회');
    await tapText(tester, '삭제');
    sets = (await store.activeWorkout())!.sets;
    expect(sets, hasLength(1));
    expect(find.text('60 kg × 8회'), findsNothing);
  });

  testWidgets('weightInput_acceptsDecimal_rejectsNegative', (tester) async {
    await pumpScreen(tester);
    await pick(tester, '벤치 프레스');

    await tester.tap(find.byKey(const Key('weightValue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('numberInput')), '62.5');
    await tapText(tester, '확인');
    expect(textOf(tester, 'weightValue'), '62.5');

    await tester.tap(find.byKey(const Key('weightValue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('numberInput')), '-5');
    expect(find.textContaining('-5'), findsNothing);
    await tapText(tester, '확인');
    expect(textOf(tester, 'weightValue'), '62.5');

    await tester.tap(find.byKey(const Key('weightValue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('numberInput')), '2');
    await tapText(tester, '확인');
    await tapText(tester, '-2.5');
    expect(textOf(tester, 'weightValue'), '0');

    await tapText(tester, '세트 완료');
    expect((await store.activeWorkout())!.sets.single.weightKg, 0);
  });

  testWidgets('pickExercise_searchAndAddCustomOffline', (tester) async {
    await pumpScreen(tester);
    await tapText(tester, '운동 선택');
    final sheet = find.byType(BottomSheet);

    await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)), '스쿼');
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('스쿼트')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('벤치 프레스')),
        findsNothing);

    await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        '케틀벨 스윙');
    await tester.pumpAndSettle();
    await tapText(tester, '"케틀벨 스윙" 직접 추가');
    await tester.enterText(find.byKey(const Key('customEquipment')), '케틀벨');
    await tapText(tester, '전신');
    await tapText(tester, '추가');

    expect(find.text('케틀벨 스윙'), findsOneWidget);
    expect(find.text('케틀벨 · 전신'), findsOneWidget);
    final pending = await store.pendingExercises();
    expect(pending.single.name, '케틀벨 스윙');
    expect(pending.single.bodyPart, 'FULL_BODY');
    expect(api.calls, isEmpty); // 서버 없이 폰에만 저장한다
  });

  testWidgets('startButton_startsWorkout_requestsPermission_opensScreen',
      (tester) async {
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...overrides(),
        authControllerProvider.overrideWith(_FixedAuth.new),
      ],
      child: const App(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveWorkoutScreen), findsNothing); // 진행 중 운동 없음

    await tapText(tester, '운동');
    await tapText(tester, '운동 시작');

    expect(await store.activeWorkout(), isNotNull);
    expect(notifier.calls, ['prepare']);
    expect(find.text('운동을 선택하세요'), findsOneWidget);
  });
}
