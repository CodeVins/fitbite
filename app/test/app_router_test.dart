import 'package:fitbite/app.dart';
import 'package:fitbite/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/auth/fakes.dart';

class _FixedAuth extends AuthController {
  final AuthState initial;
  _FixedAuth(this.initial);
  @override
  AuthState build() => initial;
}

Future<void> _pumpApp(WidgetTester tester, AuthState s) =>
    tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => _FixedAuth(s))],
      child: const App(),
    ));

void main() {
  testWidgets('router_signedOut_redirectsToLogin', (tester) async {
    await _pumpApp(tester, const AuthSignedOut());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
  });

  testWidgets('router_signedIn_opensHomeWithFourTabs', (tester) async {
    await _pumpApp(tester, const AuthSignedIn(testMe));
    await tester.pumpAndSettle();
    expect(find.textContaining('테스터님'), findsOneWidget);
    for (final label in ['홈', '운동', '식단', '인바디']) {
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text(label)),
          findsOneWidget);
    }
    await tester.tap(find.text('식단'));
    await tester.pumpAndSettle();
    expect(find.text('식단 준비 중'), findsOneWidget);
  });
}
