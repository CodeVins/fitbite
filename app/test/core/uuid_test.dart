import 'package:fitbite/core/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newUuid_isV4Format_andUnique', () {
    final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 1000; i++) newUuid()};
    expect(ids.length, 1000);
    expect(ids.every(re.hasMatch), isTrue);
  });
}
