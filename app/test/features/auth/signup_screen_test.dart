import 'package:fitbite/core/api/api_error.dart';
import 'package:fitbite/features/auth/presentation/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

FilledButton _submit(WidgetTester t) =>
    t.widget<FilledButton>(find.widgetWithText(FilledButton, '가입하기'));

void main() {
  testWidgets('signup_submitDisabled_untilConsentChecked', (tester) async {
    await pumpScreen(tester, const SignupScreen(), repo: FakeAuthRepository());
    expect(_submit(tester).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('signup_showsConsentText', (tester) async {
    await pumpScreen(tester, const SignupScreen(), repo: FakeAuthRepository());
    expect(find.textContaining('수집 항목: 운동 기록, 식단, 체성분'), findsOneWidget);
    expect(find.textContaining('이용 목적'), findsOneWidget);
  });

  testWidgets('signup_invalidInviteCode_showsKoreanError', (tester) async {
    await pumpScreen(tester, const SignupScreen(),
        repo: FakeAuthRepository(
            error: const ApiError(403, 'INVALID_INVITE_CODE', 'x')));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('초대 코드가 올바르지 않습니다.'), findsOneWidget);
  });
}
