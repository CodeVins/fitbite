import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../workout/presentation/active_workout_screen.dart';

/// 하단 탭(홈, 운동, 식단, 인바디)을 가진 뼈대 화면.
class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell shell;

  const ShellScreen({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: '운동'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_outlined), label: '식단'),
          NavigationDestination(
              icon: Icon(Icons.monitor_weight_outlined), label: '인바디'),
        ],
      ),
    );
  }
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  // 임시 위치. 5단계 설정 화면으로 옮긴다.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final store = ref.read(workoutStoreProvider);
    final auth = ref.read(authControllerProvider.notifier);
    if (await store.hasUnsent()) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('로그아웃'),
          content: const Text(
              '전송하지 않은 기록이 있습니다. 로그아웃하면 이 기록이 폰에서 삭제되고 복구할 수 없습니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('로그아웃')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await auth.logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final nickname = state is AuthSignedIn ? state.me.nickname : '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$nickname님, 안녕하세요',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

/// 후속 단계에서 채울 탭의 임시 화면.
class PlaceholderTab extends StatelessWidget {
  final String title;

  const PlaceholderTab(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Center(
      child: Text('$title 준비 중',
          style: Theme.of(context).textTheme.titleMedium));
}

/// 운동 탭의 임시 화면. 운동 목록은 이후 작업에서 채우고 이 버튼은 유지한다.
class WorkoutsTab extends ConsumerWidget {
  const WorkoutsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () => startWorkoutAndOpen(context, ref),
              child: const Text('운동 시작'),
            ),
          ],
        ),
      );
}
