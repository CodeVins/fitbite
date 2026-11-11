/// 휴식 타이머 계산. 끝나는 시각만 저장하므로 앱이 멈춰 있던 시간과 무관하게 맞는다.
class RestTimer {
  static const defaultSeconds = 90;
  static const stepSeconds = 30;
  static const minSeconds = 30;

  /// 남은 시간. 이미 지났으면 0이다.
  static Duration remaining(DateTime endsAt, DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// m:ss. 남은 초는 올림해, 0:00은 실제로 끝났을 때만 보인다.
  static String format(Duration d) {
    final secs = (d.inMilliseconds + 999) ~/ 1000;
    return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
  }
}
