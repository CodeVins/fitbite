import 'dart:convert';

import 'package:fitbite/core/api/api_client.dart';
import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/features/workout/data/workout_api.dart';
import 'package:fitbite/features/workout/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api_client_test.dart'
    show FakeAdapter, MemoryTokenStore, json;

void main() {
  WorkoutApi apiWith(FakeAdapter a) => WorkoutApi(buildApiClient(
      baseUrl: 'http://test/api/v1',
      tokens: MemoryTokenStore(),
      onSignedOut: () {},
      adapter: a));

  test('putWorkout_sendsServerFieldNames_inUtc', () async {
    final a = FakeAdapter((_) => json(200, {}));
    await apiWith(a).putWorkout(PendingSession(
      id: 'w1',
      startedAt: DateTime.utc(2026, 1, 1, 9),
      endedAt: DateTime.utc(2026, 1, 1, 10),
      sets: [
        LocalSet(
            id: 's1',
            sessionId: 'w1',
            exerciseId: 'e1',
            orderNo: 1,
            weightKg: 62.5,
            reps: 8,
            completedAt: DateTime.utc(2026, 1, 1, 9, 5),
            restSeconds: 90),
      ],
    ));

    final o = a.calls.single;
    expect(o.method, 'PUT');
    expect(o.path, '/workouts/w1');
    final body = o.data as Map;
    expect(body['startedAt'], '2026-01-01T09:00:00.000Z');
    expect(body['endedAt'], '2026-01-01T10:00:00.000Z');
    final set = (body['sets'] as List).single as Map;
    expect(set, {
      'id': 's1',
      'exerciseId': 'e1',
      'orderNo': 1,
      'weightKg': 62.5,
      'reps': 8,
      'completedAt': '2026-01-01T09:05:00.000Z',
      'restSeconds': 90,
    });
  });

  test('lastPerformance_parsesAndOrdersBySetNumber', () async {
    final a = FakeAdapter((_) => json(200, [
          {
            'exerciseId': 'e1',
            'performedAt': '2026-01-01T09:00:00Z',
            'sets': [
              {'setNumber': 2, 'weightKg': 70.0, 'reps': 6},
              {'setNumber': 1, 'weightKg': 60, 'reps': 10},
            ]
          }
        ]));
    final r = await apiWith(a).lastPerformance();
    expect(r['e1']!.map((s) => s.weightKg), [60.0, 70.0]);
    expect(r['e1']!.first.reps, 10);
  });

  test('error_isThrownAsApiError', () async {
    final a = FakeAdapter((_) =>
        json(404, {'code': 'NOT_FOUND', 'detail': 'x'}));
    await expectLater(
        apiWith(a).putExercise(const Exercise(
            id: 'e', name: 'n', equipment: '', bodyPart: 'chest')),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 404)));
    expect(jsonEncode(a.calls.single.data), contains('"CHEST"'));
  });
}
