import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 휴식이 끝날 때 울리는 알림. 테스트에서는 가짜로 바꾼다.
abstract class RestNotifier {
  /// 첫 운동 시작 때 알림 권한을 요청한다.
  Future<void> prepare();

  /// 이전 예약을 바꿔 endsAt에 알림을 예약한다.
  Future<void> schedule(DateTime endsAt);

  Future<void> cancel();
}

final restNotifierProvider =
    Provider<RestNotifier>((ref) => LocalRestNotifier());

/// flutter_local_notifications로 휴식 종료 알림을 예약한다.
class LocalRestNotifier implements RestNotifier {
  static const _id = 1; // 휴식 알림은 항상 하나다
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('rest_timer', '휴식 타이머',
        channelDescription: '휴식 시간이 끝나면 알려 줍니다.',
        importance: Importance.high,
        priority: Priority.high),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= () async {
        tzdata.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
        await _plugin.initialize(
            settings: const InitializationSettings(
                android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      }();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> prepare() async {
    await _ensureInit();
    await _android?.requestNotificationsPermission();
  }

  @override
  Future<void> schedule(DateTime endsAt) async {
    await _ensureInit();
    // 정확한 알람이 허용되지 않았으면 몇 초 늦을 수 있는 방식으로 대신한다.
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: '휴식 끝',
      body: '다음 세트를 시작하세요.',
    );
    debugPrint('rest notification scheduled (exact: $exact)');
  }

  @override
  Future<void> cancel() async {
    await _ensureInit();
    await _plugin.cancel(id: _id);
  }
}
