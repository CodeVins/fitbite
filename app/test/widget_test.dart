import 'package:fitbite/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('FitBite'), findsOneWidget);
  });
}
