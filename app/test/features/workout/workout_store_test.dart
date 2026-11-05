import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fitbite/features/workout/data/local_db.dart';
import 'package:fitbite/features/workout/data/workout_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  var clock = DateTime.utc(2026, 1, 1, 9);
  DateTime now() => clock;
  setUp(() => clock = DateTime.utc(2026, 1, 1, 9));

  WorkoutStore memStore() =>
      WorkoutStore(LocalDb(NativeDatabase.memory()), now: now);

  Future<void> seedExercise(LocalDb db, String id, String name) =>
      db.into(db.localExercises).insert(LocalExercisesCompanion.insert(
          id: id, name: name, equipment: 'barbell', bodyPart: 'chest'));

  test('completeSet_persistsImmediately', () async {
    final dir = Directory.systemTemp.createTempSync('fitbite_db');
    final file = File('${dir.path}/a.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));

    final db1 = LocalDb(NativeDatabase(file));
    final s1 = WorkoutStore(db1, now: now);
    await s1.startWorkout();
    await s1.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    // 닫지 않고 바로 다른 연결로 연다.
    final db2 = LocalDb(NativeDatabase(file));
    final s2 = WorkoutStore(db2, now: now);
    addTearDown(() async {
      await db1.close();
      await db2.close();
    });
    final w = await s2.activeWorkout();
    expect(w, isNotNull);
    expect(w!.sets, hasLength(1));
    expect(w.sets.single.weightKg, 60);
  });

  test('reopen_restoresActiveWorkout_andRestEndsAt', () async {
    final dir = Directory.systemTemp.createTempSync('fitbite_db');
    final file = File('${dir.path}/b.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));

    final db1 = LocalDb(NativeDatabase(file));
    final s1 = WorkoutStore(db1, now: now);
    final started = await s1.startWorkout();
    final ends = DateTime.utc(2026, 1, 1, 9, 2);
    await s1.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    await s1.setRestEndsAt(ends);

    final db2 = LocalDb(NativeDatabase(file));
    final s2 = WorkoutStore(db2, now: now);
    addTearDown(() async {
      await db1.close();
      await db2.close();
    });
    final w = await s2.activeWorkout();
    expect(w!.id, started.id);
    expect(w.restEndsAt, ends);
  });

  test('startNextSet_recordsRestSeconds', () async {
    final s = memStore();
    await s.startWorkout();
    await s.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    await s.setRestEndsAt(DateTime.utc(2026, 1, 1, 9, 2));
    clock = clock.add(const Duration(seconds: 75));
    await s.startNextSet();
    final w = (await s.activeWorkout())!;
    expect(w.sets.single.restSeconds, 75);
    expect(w.restEndsAt, isNull);
  });

  test('completeSetWithoutStartNext_leavesRestNull', () async {
    final s = memStore();
    await s.startWorkout();
    await s.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    final second =
        await s.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    final w = (await s.activeWorkout())!;
    expect(w.sets.map((e) => e.orderNo), [1, 2]);
    expect(w.sets.first.restSeconds, isNull);
    expect(second.restSeconds, isNull);
  });

  test('finish_withNoSets_deletesSession', () async {
    final s = memStore();
    await s.startWorkout();
    await s.finishWorkout();
    expect(await s.activeWorkout(), isNull);
    expect(await s.hasUnsent(), isFalse);
  });

  test('finish_setsPending_andUpdatesLastSets', () async {
    final s = memStore();
    await s.startWorkout();
    await s.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    await s.completeSet(exerciseId: 'e1', weightKg: 70, reps: 8);
    await s.finishWorkout();
    expect(await s.activeWorkout(), isNull);
    expect(await s.hasUnsent(), isTrue);
    final last = await s.lastSets('e1');
    expect(last.map((e) => (e.weightKg, e.reps)), [(60.0, 10), (70.0, 8)]);

    // 다음 운동이 끝나면 캐시가 그 세션의 세트로 교체된다.
    await s.startWorkout();
    await s.completeSet(exerciseId: 'e1', weightKg: 80, reps: 5);
    await s.finishWorkout();
    expect((await s.lastSets('e1')).map((e) => e.weightKg), [80.0]);
  });

  test('ensureOwner_differentUser_wipesData', () async {
    final s = memStore();
    await s.ensureOwner('u1');
    await s.startWorkout();
    await s.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    await s.finishWorkout();
    await s.ensureOwner('u2');
    expect(await s.hasUnsent(), isFalse);
    expect(await s.lastSets('e1'), isEmpty);
  });

  test('ensureOwner_sameUser_keepsPending', () async {
    final s = memStore();
    await s.ensureOwner('u1');
    await s.startWorkout();
    await s.completeSet(exerciseId: 'e1', weightKg: 60, reps: 10);
    await s.finishWorkout();
    await s.ensureOwner('u1');
    expect(await s.hasUnsent(), isTrue);
  });

  test('search_matchesKoreanSubstring', () async {
    final db = LocalDb(NativeDatabase.memory());
    final s = WorkoutStore(db, now: now);
    await seedExercise(db, 'a', '벤치 프레스');
    await seedExercise(db, 'b', '스쿼트');
    expect((await s.searchExercises('프레스')).map((e) => e.id), ['a']);
    expect(await s.searchExercises('없음'), isEmpty);
  });

  test('addCustomExercise_marksPendingSync', () async {
    final db = LocalDb(NativeDatabase.memory());
    final s = WorkoutStore(db, now: now);
    final ex = await s.addCustomExercise('내 운동', 'machine', 'back');
    final row = await (db.select(db.localExercises)
          ..where((t) => t.id.equals(ex.id)))
        .getSingle();
    expect(row.syncPending, isTrue);
    expect(row.name, '내 운동');
    expect(await s.hasUnsent(), isTrue);
  });
}
