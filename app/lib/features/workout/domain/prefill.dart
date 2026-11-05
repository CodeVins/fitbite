import 'models.dart';

/// 다음 세트의 기본값을 정한다.
/// 오늘 세트가 지난번 같은 번호 세트와 모두 같으면 지난번의 다음 세트를,
/// 하나라도 다르거나 지난번에 다음 세트가 없으면 오늘 마지막 세트를 따른다.
Prefill? prefillFor(List<LastSet> last, List<LocalSet> todayForExercise) {
  final today = todayForExercise;
  if (today.isEmpty) {
    return last.isEmpty ? null : Prefill(last[0].weightKg, last[0].reps);
  }
  var sameAsLast = today.length <= last.length;
  for (var i = 0; sameAsLast && i < today.length; i++) {
    sameAsLast =
        today[i].weightKg == last[i].weightKg && today[i].reps == last[i].reps;
  }
  if (sameAsLast && today.length < last.length) {
    final next = last[today.length];
    return Prefill(next.weightKg, next.reps);
  }
  final t = today.last;
  return Prefill(t.weightKg, t.reps);
}
