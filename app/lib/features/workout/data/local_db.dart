import 'package:drift/drift.dart';

import '../domain/models.dart';

part 'local_db.g.dart';

@DataClassName('ExerciseRow')
class LocalExercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get equipment => text()();
  TextColumn get bodyPart => text()();
  // 사용자 정의 운동을 서버에 아직 보내지 않았으면 true
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionRow')
class LocalSessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get syncState => intEnum<SessionSyncState>()();
  TextColumn get failureMessage => text().nullable()();
  // 휴식 타이머는 끝나는 시각을 저장해 계산한다.
  DateTimeColumn get restEndsAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SetRow')
class LocalSets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text()();
  IntColumn get orderNo => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get restSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LastPerformanceRow')
class LastPerformanceCache extends Table {
  TextColumn get exerciseId => text()();
  IntColumn get orderNo => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();

  @override
  Set<Column> get primaryKey => {exerciseId, orderNo};
}

@DataClassName('MetaRow')
class LocalMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  LocalExercises,
  LocalSessions,
  LocalSets,
  LastPerformanceCache,
  LocalMeta,
])
class LocalDb extends _$LocalDb {
  LocalDb(super.e);

  @override
  int get schemaVersion => 1;
}
