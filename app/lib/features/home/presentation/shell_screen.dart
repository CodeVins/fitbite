import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final nickname = state is AuthSignedIn ? state.me.nickname : '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$nickname님, 안녕하세요',
              style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('로그아웃'),
          ),
        ],
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
