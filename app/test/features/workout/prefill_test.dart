import 'package:fitbite/features/workout/domain/models.dart';
import 'package:fitbite/features/workout/domain/prefill.dart';
import 'package:flutter_test/flutter_test.dart';

LastSet l(double w, int r) => LastSet(weightKg: w, reps: r);
LocalSet s(double w, int r) => LocalSet(
      id: 'x',
      sessionId: 's',
      exerciseId: 'e',
      orderNo: 1,
      weightKg: w,
      reps: r,
      completedAt: DateTime.utc(2026, 1, 1),
    );

void expectPrefill(
    List<LastSet> last, List<LocalSet> today, (double, int)? want) {
  final p = prefillFor(last, today);
  if (want == null) {
    expect(p, isNull);
  } else {
    expect(p!.weightKg, want.$1);
    expect(p.reps, want.$2);
  }
}

void main() {
  test('no history, no today -> null', () => expectPrefill([], [], null));
  test('history only -> first last set',
      () => expectPrefill([l(60, 10), l(70, 8)], [], (60, 10)));
  test('same as last -> next last set',
      () => expectPrefill([l(60, 10), l(70, 8)], [s(60, 10)], (70, 8)));
  test('differs from last -> repeat today',
      () => expectPrefill([l(60, 10), l(70, 8)], [s(65, 10)], (65, 10)));
  test('differs at first of three -> today last',
      () => expectPrefill(
          [l(60, 10), l(70, 8), l(80, 6)], [s(65, 10), s(70, 8)], (70, 8)));
  test('once changed, later sets follow today',
      () => expectPrefill(
          [l(60, 10), l(70, 8), l(80, 6)], [s(65, 10), s(65, 10)], (65, 10)));
  test('all same so far -> next last',
      () => expectPrefill(
          [l(60, 10), l(70, 8), l(80, 6)], [s(60, 10), s(70, 8)], (80, 6)));
  test('no next last set -> repeat today',
      () => expectPrefill([l(60, 10)], [s(60, 10)], (60, 10)));
  test('no history, today -> today last',
      () => expectPrefill([], [s(50, 12)], (50, 12)));
}
