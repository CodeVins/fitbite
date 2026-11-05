import 'package:drift/drift.dart';
import 'package:fitbite/core/api/api_error.dart';
import 'package:drift/native.dart';
import 'package:fitbite/core/providers.dart';
import 'package:fitbite/core/theme.dart';
import 'package:fitbite/features/auth/presentation/auth_controller.dart';
import 'package:fitbite/features/home/presentation/shell_screen.dart';
import 'package:fitbite/features/workout/data/local_db.dart';
import 'package:fitbite/features/workout/data/workout_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workout/sync_fakes.dart';
import 'fakes.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LocalDb db;
  late WorkoutStore store;
  late ProviderContainer container;

  Future<void> pumpHome(WidgetTester tester, {required bool withUnsent}) async {
    db = LocalDb(NativeDatabase.memory());
    store = WorkoutStore(db);
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      workoutStoreProvider.overrideWithValue(store),
      // 서버에 닿지 않아 미전송 기록이 그대로 남는 상황
      workoutApiProvider.overrideWithValue(
          FakeWorkoutApi()..failWith = (_) => const ApiError(null, 'NETWORK', 'x')),
    ]);
    if (withUnsent) {
      await tester.runAsync(() async {
        await store.ensureOwner(testMe.id);
        await finishedSession(store);
      });
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildAppTheme(), home: const HomeTab()),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(container.read(authControllerProvider), isA<AuthSignedIn>());
  }

  // 저장소 조회가 실제 비동기라 runAsync로 기다린 뒤 화면을 갱신한다.
  Future<void> tapLogout(WidgetTester tester) async {
    await tester.tap(find.byTooltip('로그아웃'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose(); // 동기화 타이머도 함께 멈춘다
    await tester.runAsync(() => db.close());
  }

  testWidgets('logout_withUnsent_requiresConfirm', (tester) async {
    await pumpHome(tester, withUnsent: true);

    await tapLogout(tester);
    expect(find.textContaining('전송하지 않은 기록'), findsOneWidget);
    expect(find.textContaining('삭제'), findsWidgets);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(container.read(authControllerProvider), isA<AuthSignedIn>());
    expect(await tester.runAsync(store.hasUnsent), isTrue);
    await teardown(tester);
  });

  testWidgets('logout_confirmed_clearsLocal', (tester) async {
    await pumpHome(tester, withUnsent: true);

    await tapLogout(tester);
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    expect(await tester.runAsync(store.hasUnsent), isFalse);
    await teardown(tester);
  });

  testWidgets('logout_withoutUnsent_noConfirm', (tester) async {
    await pumpHome(tester, withUnsent: false);

    await tapLogout(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
    await teardown(tester);
  });
}
