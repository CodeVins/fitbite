import 'package:fitbite/features/workout/domain/rest_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ends = DateTime.utc(2026, 1, 1, 9, 1, 30);

  test('remaining_clampsAtZero', () {
    expect(RestTimer.remaining(ends, ends), Duration.zero);
    expect(RestTimer.remaining(ends, ends.add(const Duration(seconds: 5))),
        Duration.zero);
  });

  test('remaining_correctAfterLongPause', () {
    // 앱이 오래 멈춰 있어도 끝나는 시각과 지금 시각만으로 계산한다.
    final start = DateTime.utc(2026, 1, 1, 9);
    expect(RestTimer.remaining(ends, start), const Duration(seconds: 90));
    expect(
        RestTimer.remaining(ends, start.add(const Duration(seconds: 61))),
        const Duration(seconds: 29));
    // 지역 시각으로 넘어와도 같은 순간이면 같은 결과다.
    expect(RestTimer.remaining(ends, start.toLocal()),
        const Duration(seconds: 90));
  });

  test('format_roundsUpToWholeSeconds', () {
    expect(RestTimer.format(const Duration(seconds: 90)), '1:30');
    expect(RestTimer.format(const Duration(milliseconds: 84200)), '1:25');
    expect(RestTimer.format(Duration.zero), '0:00');
  });
}
