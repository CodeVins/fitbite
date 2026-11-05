import 'package:dio/dio.dart';
import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/features/workout/data/local_db.dart';
import 'package:fitbite/features/workout/data/workout_api.dart';
import 'package:fitbite/features/workout/data/workout_store.dart';
import 'package:fitbite/features/workout/domain/models.dart';

/// 호출을 기록하고, 지정한 오류를 던지는 가짜 서버.
class FakeWorkoutApi implements WorkoutApi {
  final calls = <String>[]; // 예: putExercise:id, putWorkout:id
  ApiError? Function(String call)? failWith;
  Future<void>? gate; // putWorkout이 이 future를 기다린다
  Future<void>? catalogGate; // listExercises가 이 future를 기다린다
  ApiError? catalogError;
  List<Exercise> exercises = [];
  Map<String, List<LastSet>> last = {};

  Iterable<String> callsOf(String kind) => calls
      .where((c) => c.startsWith('$kind:'))
      .map((c) => c.substring(kind.length + 1));

  Future<void> _record(String call) async {
    calls.add(call);
    final err = failWith?.call(call);
    if (err != null) throw err;
  }

  @override
  Future<void> putExercise(Exercise e, {CancelToken? cancelToken}) => _record('putExercise:${e.id}');

  @override
  Future<void> putWorkout(PendingSession s, {CancelToken? cancelToken}) async {
    await gate;
    await _record('putWorkout:${s.id}');
  }

  @override
  Future<List<Exercise>> listExercises() async {
    calls.add('listExercises');
    await catalogGate;
    if (catalogError != null) throw catalogError!;
    return exercises;
  }

  @override
  Future<Map<String, List<LastSet>>> lastPerformance() async {
    calls.add('lastPerformance');
    if (catalogError != null) throw catalogError!;
    return last;
  }

  @override
  Future<List<Map<String, dynamic>>> listWorkouts(
          DateTime from, DateTime to) async =>
      [];
  @override
  Future<Map<String, dynamic>> getWorkout(String id) async => {};
  @override
  Future<void> deleteWorkout(String id) async {}
}

/// 세트 하나를 기록하고 끝낸 세션의 id를 돌려준다.
Future<String> finishedSession(WorkoutStore s,
    {String exerciseId = 'e1', double weightKg = 60}) async {
  final w = await s.startWorkout();
  await s.completeSet(exerciseId: exerciseId, weightKg: weightKg, reps: 10);
  await s.finishWorkout();
  return w.id;
}

Future<SessionRow> sessionRow(LocalDb db, String id) =>
    (db.select(db.localSessions)..where((t) => t.id.equals(id))).getSingle();
