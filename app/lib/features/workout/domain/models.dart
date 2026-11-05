/// 세션의 전송 상태. 진행 중 -> 종료 후 전송 대기 -> (실패)
enum SessionSyncState { inProgress, pending, failed }

class Exercise {
  final String id;
  final String name;
  final String equipment;
  final String bodyPart;

  const Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.bodyPart,
  });
}

/// 지난번 운동에서 같은 번호의 세트 기록.
class LastSet {
  final double weightKg;
  final int reps;

  const LastSet({required this.weightKg, required this.reps});
}

/// 폰에 저장된 세트. 시각은 UTC다.
class LocalSet {
  final String id;
  final String sessionId;
  final String exerciseId;
  final int orderNo;
  final double weightKg;
  final int reps;
  final DateTime completedAt;
  final int? restSeconds;

  const LocalSet({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.orderNo,
    required this.weightKg,
    required this.reps,
    required this.completedAt,
    this.restSeconds,
  });
}

class ActiveWorkout {
  final String id;
  final DateTime startedAt;
  final DateTime? restEndsAt;
  final List<LocalSet> sets;

  const ActiveWorkout({
    required this.id,
    required this.startedAt,
    required this.restEndsAt,
    required this.sets,
  });
}

class Prefill {
  final double weightKg;
  final int reps;

  const Prefill(this.weightKg, this.reps);
}

/// 종료되어 서버로 보내기를 기다리는 운동. 시각은 UTC다.
class PendingSession {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LocalSet> sets;

  const PendingSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
  });
}
