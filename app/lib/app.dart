import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/home/presentation/shell_screen.dart';
import 'features/workout/presentation/active_workout_screen.dart';

const _authPaths = ['/login', '/signup'];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  late final GoRouter router;
  // 앱을 열어 로그인 상태가 되면, 진행 중인 운동이 있을 때 운동 진행 화면으로 보낸다.
  ref.listen(authControllerProvider, (prev, next) async {
    if (next is! AuthSignedIn || prev is AuthSignedIn) return;
    try {
      if (await ref.read(workoutStoreProvider).activeWorkout() != null) {
        router.go(activeWorkoutPath);
      }
    } catch (e) {
      debugPrint('active workout check failed: ${e.runtimeType}');
    }
  }, fireImmediately: true);

  router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      return switch (auth) {
        AuthLoading() => path == '/splash' ? null : '/splash',
        AuthSignedOut() => _authPaths.contains(path) ? null : '/login',
        AuthSignedIn() =>
          (_authPaths.contains(path) || path == '/splash') ? '/home' : null,
      };
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
          path: activeWorkoutPath,
          builder: (_, _) => const ActiveWorkoutScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScreen(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeTab()),
          ]),
          StatefulShellBranch(routes: [
            // 운동 목록은 이후 작업에서 채운다. 지금은 운동 시작 버튼만 둔다.
            GoRoute(
                path: '/workouts',
                builder: (_, _) => const WorkoutsTab()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/meals',
                builder: (_, _) => const PlaceholderTab('식단')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/body',
                builder: (_, _) => const PlaceholderTab('인바디')),
          ]),
        ],
      ),
    ],
  );
  return router;
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FitBite',
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
