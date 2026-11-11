import 'package:flutter/material.dart';

import '../domain/rest_timer.dart';

/// 세트 완료 후 화면 아래 엄지 영역에 나오는 휴식 타이머(시안 A).
class RestTimerPanel extends StatelessWidget {
  final DateTime endsAt;
  final DateTime now;
  final int lengthSeconds;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onNext;

  const RestTimerPanel({
    super.key,
    required this.endsAt,
    required this.now,
    required this.lengthSeconds,
    required this.onMinus,
    required this.onPlus,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final left = RestTimer.remaining(endsAt, now);
    final progress =
        (left.inMilliseconds / (lengthSeconds * 1000)).clamp(0.0, 1.0);
    Widget adjust(String text, VoidCallback onTap) => OutlinedButton(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(84, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12)),
          onPressed: onTap,
          child: Text(text),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('휴식 · $lengthSeconds초 중',
              style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(RestTimer.format(left),
              key: const Key('restRemaining'),
              style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                  height: 1)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            adjust('-${RestTimer.stepSeconds}초', onMinus),
            const SizedBox(width: 8),
            adjust('+${RestTimer.stepSeconds}초', onPlus),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHigh),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64)),
            onPressed: onNext,
            child: const Text('다음 세트 시작'),
          ),
        ]),
      ),
    );
  }
}
