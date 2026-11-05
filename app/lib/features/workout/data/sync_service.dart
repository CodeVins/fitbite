import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter/widgets.dart';

import '../../../core/api/api_error.dart';
import 'workout_api.dart';
import 'workout_store.dart';

/// 폰에 저장된 운동을 서버로 보내고, 운동 목록과 지난 기록 캐시를 받아 온다.
/// 어떤 메서드도 던지지 않는다. 실패는 다음 시도에서 다시 처리한다.
class SyncService {

  // 이 상태 코드는 재시도해도 같으므로 세션을 실패로 표시하고 다음으로 넘어간다.
  static const _permanent = {400, 404, 409};

  final WorkoutStore _store;
  final WorkoutApi _api;
  final bool Function() isSignedIn;
  final Duration interval; // 테스트에서 줄일 수 있다

  Future<void>? _inflight;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  // 로그아웃(stop)마다 올라가며, 이전 계정으로 시작한 작업이 결과를 쓰지 못하게 한다.
  int _epoch = 0;
  // stop 때 취소해, 이전 계정의 요청이 늦게 401을 받아도 새 계정 토큰으로 다시 가지 않게 한다.
  CancelToken _cancel = CancelToken();

  SyncService(this._store, this._api,
      {required this.isSignedIn, this.interval = const Duration(seconds: 30)});

  bool _live(int epoch) => epoch == _epoch && isSignedIn();

  /// 동시에 불려도 한 번만 보낸다.
  Future<void> push() =>
      _inflight ??= _push().whenComplete(() => _inflight = null);

  Future<void> _push() async {
    final epoch = _epoch;
    final cancel = _cancel;
    try {
      if (!_live(epoch)) return;
      // 새 사용자 정의 운동을 먼저 보내야 세션이 그 운동을 가리킬 수 있다.
      for (final e in await _store.pendingExercises()) {
        if (!_live(epoch)) return;
        try {
          await _api.putExercise(e, cancelToken: cancel);
          await _store.markExerciseSynced(e.id);
        } on ApiError catch (err) {
          // 영구 오류는 대기 상태로 두고 다른 전송을 막지 않는다.
          if (!_permanent.contains(err.status)) return;
        }
      }
      for (final s in await _store.pendingSessions()) {
        if (!_live(epoch)) return;
        try {
          await _api.putWorkout(s, cancelToken: cancel);
          await _store.removeSession(s.id);
        } on ApiError catch (err) {
          if (!_permanent.contains(err.status)) return; // 네트워크, 5xx, 401 등
          await _store.markFailed(s.id, _failureMessage(err.status!));
        }
      }
    } catch (e) {
      debugPrint('push failed: ${e.runtimeType}');
    }
  }

  static String _failureMessage(int status) => switch (status) {
        404 => '기록에 쓰인 운동을 서버에서 찾을 수 없어 전송하지 못했습니다.',
        409 => '서버의 기록과 충돌해 전송하지 못했습니다.',
        _ => '기록 형식이 올바르지 않아 전송하지 못했습니다.',
      };

  /// 운동 목록과 지난 기록을 받아 캐시를 바꾼다. 실패하면 기존 캐시를 그대로 둔다.
  Future<void> refreshCatalog() async {
    final epoch = _epoch;
    try {
      if (!_live(epoch)) return;
      final exercises = await _api.listExercises();
      final last = await _api.lastPerformance();
      if (!_live(epoch)) return;
      await _store.replaceExercises(exercises);
      await _store.replaceLastPerformance(last);
    } catch (e) {
      debugPrint('refreshCatalog failed: ${e.runtimeType}');
    }
  }

  /// 앱 복귀와 30초 주기로 전송을 시도한다. 주기 시도는 보낼 것이 있을 때만 한다.
  void start() {
    stop();
    final epoch = _epoch;
    // 테스트처럼 바인딩이 없는 환경에서도 시작할 수 있게 한다.
    WidgetsFlutterBinding.ensureInitialized();
    _lifecycle = AppLifecycleListener(onResume: () {
      if (_live(epoch)) unawaited(push());
    });
    _timer = Timer.periodic(interval, (_) async {
      try {
        if (_live(epoch) && await _store.hasPendingPush()) await push();
      } catch (e) {
        debugPrint('periodic sync failed: ${e.runtimeType}');
      }
    });
  }

  void stop() {
    _epoch++;
    _cancel.cancel();
    _cancel = CancelToken();
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
