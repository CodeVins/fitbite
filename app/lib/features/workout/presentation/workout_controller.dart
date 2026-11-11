import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications.dart';
import '../../../core/providers.dart';
import '../data/workout_store.dart';
import '../domain/models.dart';
import '../domain/prefill.dart';
import '../domain/rest_timer.dart';

/// 서버 검증 범위(무게 0~1000kg, 횟수 1~1000회)와 같게 맞춘다.
const maxWeightKg = 1000.0;
const maxReps = 1000;
// 지난 기록도 오늘 기록도 없는 운동의 기본값
const _defaultReps = 10;

/// 운동 진행 화면의 상태. 진행 중 운동과 지금 고른 운동, 입력값을 담는다.
class WorkoutView {
  final ActiveWorkout workout;
  final Exercise? exercise;
  final List<LastSet> last;
  final double weightKg;
  final int reps;
  final String? prefillNote; // 기본값의 출처. 사용자가 값을 바꾸면 없앤다.
  final int restLengthSeconds;

  const WorkoutView({
    required this.workout,
    required this.exercise,
    required this.last,
    required this.weightKg,
    required this.reps,
    required this.prefillNote,
    required this.restLengthSeconds,
  });

  bool get resting => workout.restEndsAt != null;

  List<LocalSet> get todaySets => [
        for (final s in workout.sets)
          if (s.exerciseId == exercise?.id) s
      ];

  int get nextSetNo => todaySets.length + 1;

  WorkoutView withInput(double weightKg, int reps) => WorkoutView(
        workout: workout,
        exercise: exercise,
        last: last,
        weightKg: weightKg,
        reps: reps,
        prefillNote: null,
        restLengthSeconds: restLengthSeconds,
      );
}

/// 진행 중 운동이 없으면 null이다.
final workoutControllerProvider =
    AsyncNotifierProvider.autoDispose<WorkoutController, WorkoutView?>(
        WorkoutController.new);

/// 모든 기록은 폰에 먼저 저장한 뒤 화면 상태를 다시 읽는다.
/// 알림 실패는 기록 흐름을 막지 않는다.
class WorkoutController extends AsyncNotifier<WorkoutView?> {
  WorkoutStore get _store => ref.read(workoutStoreProvider);
  RestNotifier get _notifier => ref.read(restNotifierProvider);
  DateTime _now() => ref.read(clockProvider)();

  bool _busy = false;

  @override
  Future<WorkoutView?> build() async {
    final w = await _store.activeWorkout();
    if (w == null) return null;
    // 다시 열면 마지막으로 기록한 운동부터 보여 준다.
    final exercise = w.sets.isEmpty
        ? null
        : await _store.exerciseById(w.sets.last.exerciseId);
    return _load(exercise);
  }

  Future<WorkoutView?> _load(Exercise? exercise) async {
    final w = await _store.activeWorkout();
    if (w == null) return null;
    final last = exercise == null
        ? const <LastSet>[]
        : await _store.lastSets(exercise.id);
    final today = [
      for (final s in w.sets)
        if (s.exerciseId == exercise?.id) s
    ];
    final p = prefillFor(last, today);
    final setNo = today.length + 1;
    final String? note;
    if (p == null) {
      note = null;
    } else if (today.length < last.length &&
        last[today.length].weightKg == p.weightKg &&
        last[today.length].reps == p.reps) {
      note = '지난번 $setNo세트 값으로 채움';
    } else {
      note = '직전 세트 값으로 채움';
    }
    return WorkoutView(
      workout: w,
      exercise: exercise,
      last: last,
      weightKg: p?.weightKg ?? 0,
      reps: p?.reps ?? _defaultReps,
      prefillNote: note,
      restLengthSeconds: await _store.restLengthSeconds(),
    );
  }

  /// 한 번에 하나의 기록만 처리해 두 번 눌러도 세트가 두 번 저장되지 않는다.
  Future<void> _run(Future<void> Function(WorkoutView v) action) async {
    final v = state.value;
    if (v == null || _busy) return;
    _busy = true;
    try {
      await action(v);
    } finally {
      _busy = false;
    }
  }

  Future<void> _reload(Exercise? exercise) async =>
      state = AsyncData(await _load(exercise));

  Future<void> _safeNotify(String what, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      // 알림 권한 거부 등. 기록과 화면 타이머는 그대로 진행한다.
      debugPrint('rest notifier $what failed: ${e.runtimeType}');
    }
  }

  Future<void> selectExercise(Exercise e) => _run((_) => _reload(e));

  void setInput(double weightKg, int reps) {
    final v = state.value;
    if (v == null) return;
    state = AsyncData(v.withInput(
        weightKg.clamp(0, maxWeightKg).toDouble(), reps.clamp(1, maxReps)));
  }

  Future<void> completeSet() => _run((v) async {
        final ex = v.exercise;
        if (ex == null || v.resting) return;
        await _store.completeSet(
            exerciseId: ex.id, weightKg: v.weightKg, reps: v.reps);
        final endsAt = _now().add(Duration(seconds: v.restLengthSeconds));
        await _store.setRestEndsAt(endsAt);
        await _reload(ex);
        await _safeNotify('schedule', () => _notifier.schedule(endsAt));
      });

  Future<void> startNextSet() => _run((v) async {
        await _store.startNextSet();
        await _reload(v.exercise);
        await _safeNotify('cancel', _notifier.cancel);
      });

  /// 휴식 길이를 바꾸고 기억한다. 진행 중인 휴식의 끝나는 시각도 같은 만큼 옮긴다.
  Future<void> adjustRest(int deltaSeconds) => _run((v) async {
        final len = max(RestTimer.minSeconds, v.restLengthSeconds + deltaSeconds);
        final applied = len - v.restLengthSeconds;
        await _store.setRestLengthSeconds(len);
        final ends = v.workout.restEndsAt;
        DateTime? newEnds;
        if (ends != null && applied != 0) {
          newEnds = ends.add(Duration(seconds: applied));
          await _store.setRestEndsAt(newEnds);
        }
        await _reload(v.exercise);
        if (newEnds != null) {
          final at = newEnds;
          await _safeNotify('schedule', () => _notifier.schedule(at));
        }
      });

  Future<void> editSet(LocalSet s, double weightKg, int reps) =>
      _run((v) async {
        await _store.updateSet(s.id, weightKg, reps, s.restSeconds);
        await _reload(v.exercise);
      });

  Future<void> deleteSet(LocalSet s) => _run((v) async {
        await _store.deleteSet(s.id);
        await _reload(v.exercise);
        // 휴식 중이던 마지막 세트를 지웠으면 저장소가 휴식을 끝냈으므로 알림도 취소한다.
        if (v.resting && state.value?.resting == false) {
          await _safeNotify('cancel', _notifier.cancel);
        }
      });

  /// 운동을 끝낸다. 세트가 있으면 전송 대기로 두고 바로 전송을 시도한다.
  Future<void> finish() => _run((v) async {
        await _store.finishWorkout();
        await _safeNotify('cancel', _notifier.cancel);
        if (v.workout.sets.isNotEmpty) {
          unawaited(ref.read(syncServiceProvider).push());
        }
        state = const AsyncData(null);
      });
}
