import 'package:drift/drift.dart';

import '../../../core/uuid.dart';
import '../domain/models.dart';
import '../domain/rest_timer.dart';
import 'local_db.dart';

/// 운동 기록의 폰 저장소. 모든 쓰기는 즉시 SQLite에 반영된다.
class WorkoutStore {
  static const _ownerKey = 'owner_user_id';
  static const _restKey = 'rest_length_seconds';

  final LocalDb _db;
  final DateTime Function() _now;

  WorkoutStore(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  DateTime get _nowUtc => _now().toUtc();

  /// 저장된 소유자와 다르면 보내지 않은 기록까지 모두 지운다.
  Future<void> ensureOwner(String userId) async {
    final row = await (_db.select(_db.localMeta)
          ..where((t) => t.key.equals(_ownerKey)))
        .getSingleOrNull();
    if (row?.value == userId) return;
    if (row != null) await clearAll();
    await _db.into(_db.localMeta).insertOnConflictUpdate(
        LocalMetaCompanion.insert(key: _ownerKey, value: userId));
  }

  Future<ActiveWorkout?> activeWorkout() async {
    final s = await _activeSessionOrNull();
    if (s == null) return null;
    final sets = await (_db.select(_db.localSets)
          ..where((t) => t.sessionId.equals(s.id))
          ..orderBy([(t) => OrderingTerm.asc(t.orderNo)]))
        .get();
    return ActiveWorkout(
      id: s.id,
      startedAt: s.startedAt.toUtc(),
      restEndsAt: s.restEndsAt?.toUtc(),
      sets: sets.map(_toSet).toList(),
    );
  }

  /// 진행 중인 운동이 있으면 새로 만들지 않고 그대로 돌려준다.
  Future<ActiveWorkout> startWorkout() async {
    final active = await activeWorkout();
    if (active != null) return active;
    await _db.into(_db.localSessions).insert(LocalSessionsCompanion.insert(
        id: newUuid(),
        startedAt: _nowUtc,
        syncState: SessionSyncState.inProgress));
    return (await activeWorkout())!;
  }

  Future<LocalSet> completeSet({
    required String exerciseId,
    required double weightKg,
    required int reps,
  }) {
    return _db.transaction(() async {
      final session = await _activeSession();
      final maxNo = _db.localSets.orderNo.max();
      final top = await (_db.selectOnly(_db.localSets)
            ..addColumns([maxNo])
            ..where(_db.localSets.sessionId.equals(session.id)))
          .map((r) => r.read(maxNo))
          .getSingle();
      final set = SetRow(
        id: newUuid(),
        sessionId: session.id,
        exerciseId: exerciseId,
        orderNo: (top ?? 0) + 1,
        weightKg: weightKg,
        reps: reps,
        completedAt: _nowUtc,
        restSeconds: null,
      );
      await _db.into(_db.localSets).insert(set);
      // 새 휴식이 시작되므로 이전 휴식 종료 시각은 버린다.
      await _clearRest(session.id);
      return _toSet(set);
    });
  }

  /// 직전 세트의 휴식 시간을 기록하고 휴식 상태를 해제한다.
  Future<void> startNextSet() {
    return _db.transaction(() async {
      final session = await _activeSession();
      final last = await (_db.select(_db.localSets)
            ..where((t) => t.sessionId.equals(session.id))
            ..orderBy([(t) => OrderingTerm.desc(t.orderNo)])
            ..limit(1))
          .getSingleOrNull();
      // 이미 기록된 휴식은 덮지 않는다(그 뒤 세트를 지운 경우 등).
      if (last != null && last.restSeconds == null) {
        final secs = _nowUtc.difference(last.completedAt.toUtc()).inSeconds;
        await (_db.update(_db.localSets)..where((t) => t.id.equals(last.id)))
            .write(LocalSetsCompanion(restSeconds: Value(secs < 0 ? 0 : secs)));
      }
      await _clearRest(session.id);
    });
  }

  /// 진행 중 운동의 세트만 고친다. 전송 대기 세션은 전송 중일 수 있어 건드리지 않는다.
  Future<void> updateSet(
      String id, double weightKg, int reps, int? restSeconds) async {
    final n = await (_db.update(_db.localSets)
          ..where((t) => t.id.equals(id) & t.sessionId.isInQuery(_activeIds())))
        .write(LocalSetsCompanion(
            weightKg: Value(weightKg),
            reps: Value(reps),
            restSeconds: Value(restSeconds)));
    if (n == 0) throw StateError('set is not in the active workout');
  }

  /// 진행 중 운동의 세트만 지운다. 휴식은 마지막 세트의 것이므로, 마지막 세트를
  /// 지우면 휴식도 끝낸다. 그대로 두면 "다음 세트 시작"이 앞 세트의 휴식 시간을 덮어쓴다.
  Future<void> deleteSet(String id) {
    return _db.transaction(() async {
      final session = await _activeSession();
      final latest = await (_db.select(_db.localSets)
            ..where((t) => t.sessionId.equals(session.id))
            ..orderBy([(t) => OrderingTerm.desc(t.orderNo)])
            ..limit(1))
          .getSingleOrNull();
      final n = await (_db.delete(_db.localSets)
            ..where((t) => t.id.equals(id) & t.sessionId.equals(session.id)))
          .go();
      if (n == 0) throw StateError('set is not in the active workout');
      if (latest?.id == id) await _clearRest(session.id);
    });
  }

  JoinedSelectStatement _activeIds() => _db.selectOnly(_db.localSessions)
    ..addColumns([_db.localSessions.id])
    ..where(
        _db.localSessions.syncState.equalsValue(SessionSyncState.inProgress));

  /// 마지막으로 쓴 휴식 길이(초). 운동별로 나누지 않는다.
  Future<int> restLengthSeconds() async {
    final row = await (_db.select(_db.localMeta)
          ..where((t) => t.key.equals(_restKey)))
        .getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? RestTimer.defaultSeconds;
  }

  Future<void> setRestLengthSeconds(int seconds) => _db
      .into(_db.localMeta)
      .insertOnConflictUpdate(
          LocalMetaCompanion.insert(key: _restKey, value: '$seconds'));

  Future<Exercise?> exerciseById(String id) async {
    final row = await (_db.select(_db.localExercises)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toExercise(row);
  }

  Future<void> setRestEndsAt(DateTime endsAt) async {
    final session = await _activeSession();
    await (_db.update(_db.localSessions)..where((t) => t.id.equals(session.id)))
        .write(LocalSessionsCompanion(restEndsAt: Value(endsAt.toUtc())));
  }

  /// 세트가 없으면 세션을 지우고, 있으면 전송 대기로 바꾸며 지난 기록 캐시를 갱신한다.
  Future<void> finishWorkout() {
    return _db.transaction(() async {
      final active = await activeWorkout();
      if (active == null) return;
      if (active.sets.isEmpty) {
        await discardWorkout(active.id);
        return;
      }
      await (_db.update(_db.localSessions)
            ..where((t) => t.id.equals(active.id)))
          .write(LocalSessionsCompanion(
              syncState: const Value(SessionSyncState.pending),
              finishedAt: Value(_nowUtc),
              restEndsAt: const Value(null)));
      final byExercise = <String, List<LocalSet>>{};
      for (final s in active.sets) {
        byExercise.putIfAbsent(s.exerciseId, () => []).add(s);
      }
      for (final e in byExercise.entries) {
        await (_db.delete(_db.lastPerformanceCache)
              ..where((t) => t.exerciseId.equals(e.key)))
            .go();
        await _db.batch((b) => b.insertAll(_db.lastPerformanceCache, [
              for (var i = 0; i < e.value.length; i++)
                LastPerformanceCacheCompanion.insert(
                    exerciseId: e.key,
                    orderNo: i + 1,
                    weightKg: e.value[i].weightKg,
                    reps: e.value[i].reps)
            ]));
      }
    });
  }

  Future<void> discardWorkout(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.localSets)..where((t) => t.sessionId.equals(id)))
          .go();
      await (_db.delete(_db.localSessions)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<List<Exercise>> searchExercises(String query) async {
    final rows = await (_db.select(_db.localExercises)
          ..where((t) => t.name.contains(query))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(_toExercise).toList();
  }

  Future<Exercise> addCustomExercise(
      String name, String equipment, String bodyPart) async {
    final row = ExerciseRow(
        id: newUuid(),
        name: name,
        equipment: equipment,
        bodyPart: bodyPart,
        syncPending: true);
    await _db.into(_db.localExercises).insert(row);
    return _toExercise(row);
  }

  Future<List<LastSet>> lastSets(String exerciseId) async {
    final rows = await (_db.select(_db.lastPerformanceCache)
          ..where((t) => t.exerciseId.equals(exerciseId))
          ..orderBy([(t) => OrderingTerm.asc(t.orderNo)]))
        .get();
    return rows
        .map((r) => LastSet(weightKg: r.weightKg, reps: r.reps))
        .toList();
  }

  /// 아직 서버에 보내지 않은 세션이나 사용자 정의 운동이 있는가.
  Future<bool> hasUnsent() async {
    final sessions = await (_db.select(_db.localSessions)..limit(1)).get();
    if (sessions.isNotEmpty) return true;
    final ex = await (_db.select(_db.localExercises)
          ..where((t) => t.syncPending.equals(true))
          ..limit(1))
        .get();
    return ex.isNotEmpty;
  }


  // ---- 동기화(SyncService)가 쓰는 메서드 ----

  /// 종료되어 전송을 기다리는 세션. 실패한 세션은 포함하지 않는다.
  Future<List<PendingSession>> pendingSessions() async {
    final rows = await (_db.select(_db.localSessions)
          ..where((t) => t.syncState.equalsValue(SessionSyncState.pending))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    final result = <PendingSession>[];
    for (final s in rows) {
      final sets = await (_db.select(_db.localSets)
            ..where((t) => t.sessionId.equals(s.id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderNo)]))
          .get();
      result.add(PendingSession(
        id: s.id,
        startedAt: s.startedAt.toUtc(),
        endedAt: (s.finishedAt ?? s.startedAt).toUtc(),
        sets: sets.map(_toSet).toList(),
      ));
    }
    return result;
  }

  /// 재시도로 해결되지 않는 오류로 전송이 거부된 세션. 기록은 그대로 둔다.
  Future<void> markFailed(String id, String message) =>
      (_db.update(_db.localSessions)..where((t) => t.id.equals(id))).write(
          LocalSessionsCompanion(
              syncState: const Value(SessionSyncState.failed),
              failureMessage: Value(message)));

  /// 서버에 저장된 세션을 폰에서 지운다. 지난 기록 캐시는 남는다.
  Future<void> removeSession(String id) => discardWorkout(id);

  Future<List<Exercise>> pendingExercises() async {
    final rows = await (_db.select(_db.localExercises)
          ..where((t) => t.syncPending.equals(true)))
        .get();
    return rows.map(_toExercise).toList();
  }

  Future<void> markExerciseSynced(String id) =>
      (_db.update(_db.localExercises)..where((t) => t.id.equals(id)))
          .write(const LocalExercisesCompanion(syncPending: Value(false)));

  /// 전송할 것이 있는가. 진행 중이거나 실패한 세션은 자동 전송 대상이 아니다.
  Future<bool> hasPendingPush() async {
    final s = await (_db.select(_db.localSessions)
          ..where((t) => t.syncState.equalsValue(SessionSyncState.pending))
          ..limit(1))
        .get();
    return s.isNotEmpty || (await pendingExercises()).isNotEmpty;
  }

  /// 서버 운동 목록으로 캐시를 바꾼다. 아직 보내지 않은 사용자 정의 운동은 유지한다.
  Future<void> replaceExercises(List<Exercise> exercises) {
    return _db.transaction(() async {
      final pendingIds = (await pendingExercises()).map((e) => e.id).toSet();
      await (_db.delete(_db.localExercises)
            ..where((t) => t.syncPending.equals(false)))
          .go();
      await _db.batch((b) => b.insertAll(
          _db.localExercises,
          [
            for (final e in exercises)
              if (!pendingIds.contains(e.id))
                LocalExercisesCompanion.insert(
                    id: e.id,
                    name: e.name,
                    equipment: e.equipment,
                    bodyPart: e.bodyPart)
          ],
          mode: InsertMode.insertOrReplace));
    });
  }

  /// 서버의 지난 기록으로 캐시를 바꾼다. 전송 전 세션에 있는 운동은
  /// 폰의 기록이 더 최신이므로 건드리지 않는다.
  Future<void> replaceLastPerformance(Map<String, List<LastSet>> byExercise) {
    return _db.transaction(() async {
      final unsent = await (_db.selectOnly(_db.localSets, distinct: true)
            ..addColumns([_db.localSets.exerciseId])
            ..join([
              innerJoin(_db.localSessions,
                  _db.localSessions.id.equalsExp(_db.localSets.sessionId))
            ])
            ..where(_db.localSessions.syncState
                .isNotValue(SessionSyncState.inProgress.index)))
          .map((r) => r.read(_db.localSets.exerciseId)!)
          .get();
      final keep = unsent.toSet();
      await (_db.delete(_db.lastPerformanceCache)
            ..where((t) => t.exerciseId.isNotIn(keep)))
          .go();
      await _db.batch((b) => b.insertAll(_db.lastPerformanceCache, [
            for (final e in byExercise.entries)
              if (!keep.contains(e.key))
                for (var i = 0; i < e.value.length; i++)
                  LastPerformanceCacheCompanion.insert(
                      exerciseId: e.key,
                      orderNo: i + 1,
                      weightKg: e.value[i].weightKg,
                      reps: e.value[i].reps)
          ]));
    });
  }

  Future<void> clearAll() {
    return _db.transaction(() async {
      for (final t in _db.allTables) {
        await _db.delete(t).go();
      }
    });
  }

  Future<void> _clearRest(String sessionId) =>
      (_db.update(_db.localSessions)..where((t) => t.id.equals(sessionId)))
          .write(const LocalSessionsCompanion(restEndsAt: Value(null)));

  Future<SessionRow?> _activeSessionOrNull() =>
      (_db.select(_db.localSessions)
            ..where((t) => t.syncState.equalsValue(SessionSyncState.inProgress))
            ..limit(1))
          .getSingleOrNull();

  Future<SessionRow> _activeSession() async {
    final s = await _activeSessionOrNull();
    if (s == null) throw StateError('no active workout');
    return s;
  }

  LocalSet _toSet(SetRow r) => LocalSet(
        id: r.id,
        sessionId: r.sessionId,
        exerciseId: r.exerciseId,
        orderNo: r.orderNo,
        weightKg: r.weightKg,
        reps: r.reps,
        completedAt: r.completedAt.toUtc(),
        restSeconds: r.restSeconds,
      );

  Exercise _toExercise(ExerciseRow r) => Exercise(
      id: r.id, name: r.name, equipment: r.equipment, bodyPart: r.bodyPart);
}
