import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> _login(WidgetTester tester, ApiError error) async {
  await pumpScreen(tester, const LoginScreen(),
      repo: FakeAuthRepository(error: error));
  await tester.tap(find.widgetWithText(FilledButton, '로그인'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('login_wrongCredentials_showsKoreanError', (tester) async {
    await _login(tester, const ApiError(401, 'INVALID_CREDENTIALS', 'x'));
    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
  });

  testWidgets('login_noNetwork_showsConnectionError', (tester) async {
    await _login(tester, const ApiError(null, 'NETWORK', 'x'));
    expect(find.textContaining('서버에 연결할 수 없습니다'), findsOneWidget);
  });
}
