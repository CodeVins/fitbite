import 'package:dio/dio.dart';

import '../../../core/api/api_error.dart';
import '../domain/models.dart';

/// 운동·운동 목록 API 호출. 실패는 [ApiError]로 던진다.
class WorkoutApi {
  final Dio _dio;

  WorkoutApi(this._dio);

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      final err = e.error;
      throw err is ApiError
          ? err
          : const ApiError(null, 'NETWORK', '서버에 연결할 수 없습니다.');
    }
  }

  static String _utc(DateTime t) => t.toUtc().toIso8601String();
  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> putExercise(Exercise e) => _call(() => _dio.put<void>(
        '/exercises/${e.id}',
        data: {
          'name': e.name,
          'equipment': e.equipment,
          'bodyPart': e.bodyPart.toUpperCase(),
        },
      ));

  /// 같은 id로 다시 보내도 결과가 같다(서버가 세션 전체를 덮어쓴다).
  Future<void> putWorkout(PendingSession s) => _call(() => _dio.put<void>(
        '/workouts/${s.id}',
        data: {
          'startedAt': _utc(s.startedAt),
          'endedAt': _utc(s.endedAt),
          'sets': [
            for (final x in s.sets)
              {
                'id': x.id,
                'exerciseId': x.exerciseId,
                'orderNo': x.orderNo,
                'weightKg': x.weightKg,
                'reps': x.reps,
                'completedAt': _utc(x.completedAt),
                'restSeconds': x.restSeconds,
              }
          ],
        },
      ));

  /// 날짜(yyyy-MM-dd)는 from, to의 연월일을 그대로 쓴다.
  Future<List<Map<String, dynamic>>> listWorkouts(DateTime from, DateTime to) =>
      _call(() async {
        final res = await _dio.get<List>('/workouts',
            queryParameters: {'from': _date(from), 'to': _date(to)});
        return res.data!.cast<Map<String, dynamic>>();
      });

  Future<Map<String, dynamic>> getWorkout(String id) => _call(() async {
        final res = await _dio.get<Map<String, dynamic>>('/workouts/$id');
        return res.data!;
      });

  Future<void> deleteWorkout(String id) =>
      _call(() => _dio.delete<void>('/workouts/$id'));

  Future<List<Exercise>> listExercises() => _call(() async {
        final res = await _dio.get<List>('/exercises');
        return [
          for (final j in res.data!.cast<Map<String, dynamic>>())
            Exercise(
              id: j['id'] as String,
              name: j['name'] as String,
              equipment: (j['equipment'] as String?) ?? '',
              bodyPart: j['bodyPart'] as String,
            )
        ];
      });

  /// 운동 id별 가장 최근 세션의 세트.
  Future<Map<String, List<LastSet>>> lastPerformance() => _call(() async {
        final res = await _dio.get<List>('/exercises/last-performance');
        return {
          for (final j in res.data!.cast<Map<String, dynamic>>())
            j['exerciseId'] as String: [
              for (final s in ((j['sets'] as List).cast<Map<String, dynamic>>()
                ..sort((a, b) =>
                    (a['setNumber'] as int).compareTo(b['setNumber'] as int))))
                LastSet(
                    weightKg: (s['weightKg'] as num).toDouble(),
                    reps: s['reps'] as int)
            ]
        };
      });
}
