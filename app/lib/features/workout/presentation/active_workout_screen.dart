import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications.dart';
import '../../../core/providers.dart';
import '../domain/models.dart';
import 'exercise_picker_sheet.dart';
import 'rest_timer_panel.dart';
import 'workout_controller.dart';

const activeWorkoutPath = '/workout/active';

/// 운동을 시작(이미 있으면 이어서)하고 운동 진행 화면을 연다.
/// 알림 권한은 이때 요청하며, 거부되거나 실패해도 운동은 시작한다.
Future<void> startWorkoutAndOpen(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(workoutStoreProvider).startWorkout();
  } catch (e) {
    debugPrint('startWorkout failed: ${e.runtimeType}');
    if (context.mounted) _snack(context, '운동을 시작하지 못했습니다. 다시 시도해 주세요.');
    return;
  }
  unawaited(ref.read(restNotifierProvider).prepare().catchError(
      (Object e) => debugPrint('notification prepare failed: ${e.runtimeType}')));
  if (context.mounted) unawaited(context.push(activeWorkoutPath));
}

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// 무게는 소수 둘째 자리까지, 횟수는 정수만. 음수 부호는 받지 않는다.
TextInputFormatter _numberFormatter(bool decimal) {
  final pattern = RegExp(decimal ? r'^\d{0,4}(\.\d{0,2})?$' : r'^\d{0,4}$');
  return TextInputFormatter.withFunction(
      (old, next) => pattern.hasMatch(next.text) ? next : old);
}

String formatKg(double kg) => kg == kg.roundToDouble()
    ? kg.toInt().toString()
    : kg.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

/// 운동 진행 화면(시안 A). 한 번에 한 운동을 보여 주고, 큰 버튼은 아래 엄지 영역에 둔다.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _ticker;

  WorkoutController get _ctrl => ref.read(workoutControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // 1초마다 끝나는 시각에서 남은 시간을 다시 계산한다.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 저장 실패는 알리고 화면은 그대로 둔다.
  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('workout action failed: ${e.runtimeType}');
      if (mounted) _snack(context, '저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _pickExercise() async {
    final ex =
        await showExercisePicker(context, ref.read(workoutStoreProvider));
    if (ex != null) await _act(() => _ctrl.selectExercise(ex));
  }

  Future<void> _finish(WorkoutView v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('운동 종료'),
        content: Text(v.workout.sets.isEmpty
            ? '기록한 세트가 없어 이 운동은 저장되지 않습니다.'
            : '운동을 마치고 기록을 저장합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('계속하기')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('종료')),
        ],
      ),
    );
    if (ok != true) return;
    await _act(_ctrl.finish);
    if (mounted && ref.read(workoutControllerProvider).value == null) {
      context.go('/home');
    }
  }

  // 대화상자의 입력 컨트롤러는 닫히는 애니메이션 중에도 쓰이므로 직접 dispose하지 않는다.
  // 리스너가 없어 대화상자와 함께 GC가 정리한다.
  Future<num?> _askNumber(String title, num initial, bool decimal) {
    final text = TextEditingController(
        text: decimal ? formatKg(initial.toDouble()) : '$initial');
    return showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('numberInput'),
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [_numberFormatter(decimal)],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(
                ctx, decimal ? double.tryParse(text.text) : int.tryParse(text.text)),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSet(LocalSet s) async {
    final w = TextEditingController(text: formatKg(s.weightKg));
    final r = TextEditingController(text: '${s.reps}');
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('세트 수정'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('editWeight'),
            controller: w,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_numberFormatter(true)],
            decoration: const InputDecoration(labelText: '무게 (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('editReps'),
            controller: r,
            keyboardType: TextInputType.number,
            inputFormatters: [_numberFormatter(false)],
            decoration: const InputDecoration(labelText: '횟수 (회)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Text('삭제',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () {
              final kg = double.tryParse(w.text);
              final reps = int.tryParse(r.text);
              // 서버가 받지 않는 값은 저장하지 않는다.
              if (kg == null || kg > maxWeightKg) return;
              if (reps == null || reps < 1 || reps > maxReps) return;
              Navigator.pop(ctx, (kg, reps));
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    switch (result) {
      case 'delete':
        await _act(() => _ctrl.deleteSet(s));
      case (double kg, int reps):
        await _act(() => _ctrl.editSet(s, kg, reps));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workoutControllerProvider);
    final now = ref.read(clockProvider)();
    final v = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(v == null ? '운동' : '운동 중 · ${_elapsed(v, now)}'),
        actions: [
          if (v != null)
            TextButton(onPressed: () => _finish(v), child: const Text('운동 종료')),
        ],
      ),
      body: switch (async) {
        AsyncData(value: final v?) => _body(context, v, now),
        AsyncData() => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('진행 중인 운동이 없습니다.'),
              TextButton(
                  onPressed: () => context.go('/workouts'),
                  child: const Text('운동 탭으로')),
            ]),
          ),
        AsyncError() => const Center(child: Text('기록을 불러오지 못했습니다.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static String _elapsed(WorkoutView v, DateTime now) {
    final d = now.difference(v.workout.startedAt);
    final secs = d.isNegative ? 0 : d.inSeconds;
    return '${(secs ~/ 60).toString().padLeft(2, '0')}:'
        '${(secs % 60).toString().padLeft(2, '0')}';
  }

  Widget _body(BuildContext context, WorkoutView v, DateTime now) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 15, color: colors.onSurfaceVariant);
    final ex = v.exercise;
    final ends = v.workout.restEndsAt;
    final today = v.todaySets;

    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (ex == null) ...[
            Text('운동을 선택하세요',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: _pickExercise, child: const Text('운동 선택')),
          ] else ...[
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      Text(exerciseSubtitle(ex),
                          style: TextStyle(
                              fontSize: 14, color: colors.onSurfaceVariant)),
                    ]),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(84, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: _pickExercise,
                child: const Text('운동 바꾸기'),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  v.last.isEmpty
                      ? '지난번 기록 없음'
                      : '지난번   ${v.last.map((s) => '${formatKg(s.weightKg)}×${s.reps}').join(' · ')}',
                  style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 16),
            if (today.isNotEmpty) Text('오늘', style: muted),
            for (var i = 0; i < today.length; i++)
              InkWell(
                onTap: () => _editSet(today[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text('${i + 1}세트', style: muted)),
                    Text(
                        '${formatKg(today[i].weightKg)} kg × ${today[i].reps}회',
                        style: const TextStyle(fontSize: 17)),
                    const Spacer(),
                    Icon(Icons.check_circle, color: colors.primary, size: 22),
                  ]),
                ),
              ),
            const SizedBox(height: 16),
            if (ends == null) ...[
              Text(
                  v.prefillNote == null
                      ? '${v.nextSetNo}세트'
                      : '${v.nextSetNo}세트 · ${v.prefillNote}',
                  style: muted),
              const SizedBox(height: 8),
              Row(children: [
                _StepperCard(
                  label: '무게',
                  valueKey: const Key('weightValue'),
                  value: formatKg(v.weightKg),
                  unit: 'kg',
                  step: '2.5',
                  onMinus: () => _ctrl.setInput(v.weightKg - 2.5, v.reps),
                  onPlus: () => _ctrl.setInput(v.weightKg + 2.5, v.reps),
                  onTapValue: () async {
                    final n = await _askNumber('무게 (kg)', v.weightKg, true);
                    if (n != null) _ctrl.setInput(n.toDouble(), v.reps);
                  },
                ),
                const SizedBox(width: 12),
                _StepperCard(
                  label: '횟수',
                  valueKey: const Key('repsValue'),
                  value: '${v.reps}',
                  unit: '회',
                  step: '1',
                  onMinus: () => _ctrl.setInput(v.weightKg, v.reps - 1),
                  onPlus: () => _ctrl.setInput(v.weightKg, v.reps + 1),
                  onTapValue: () async {
                    final n = await _askNumber('횟수 (회)', v.reps, false);
                    if (n != null) _ctrl.setInput(v.weightKg, n.toInt());
                  },
                ),
              ]),
            ] else
              OutlinedButton.icon(
                  onPressed: _pickExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('다른 운동 추가')),
          ],
        ]),
      ),
      if (ends != null)
        RestTimerPanel(
          endsAt: ends,
          now: now,
          lengthSeconds: v.restLengthSeconds,
          onMinus: () => _act(() => _ctrl.adjustRest(-30)),
          onPlus: () => _act(() => _ctrl.adjustRest(30)),
          onNext: () => _act(_ctrl.startNextSet),
        )
      else if (ex != null)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64)),
              onPressed: () => _act(_ctrl.completeSet),
              child: const Text('세트 완료'),
            ),
          ),
        ),
    ]);
  }
}

/// 큰 숫자와 -/+ 버튼. 숫자를 누르면 직접 입력한다.
class _StepperCard extends StatelessWidget {
  final String label;
  final Key valueKey;
  final String value;
  final String unit;
  final String step;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTapValue;

  const _StepperCard({
    required this.label,
    required this.valueKey,
    required this.value,
    required this.unit,
    required this.step,
    required this.onMinus,
    required this.onPlus,
    required this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget btn(String t, VoidCallback onTap) => Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52), padding: EdgeInsets.zero),
            onPressed: onTap,
            child: Text(t),
          ),
        );
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(label,
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant)),
          InkWell(
            onTap: onTapValue,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    child: Text(value,
                        key: valueKey,
                        style: const TextStyle(
                            fontSize: 44, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 4),
                Text(unit,
                    style: TextStyle(
                        fontSize: 16, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            btn('-$step', onMinus),
            const SizedBox(width: 8),
            btn('+$step', onPlus),
          ]),
        ]),
      ),
    );
  }
}
