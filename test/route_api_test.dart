// Small surface checks on RakuRoute: name, props, toString, and the
// equality edge cases (different type, non-route operand).
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('name defaults to the runtime type', () {
    expect(const Home().name, 'Home');
    expect(const Note('1').name, 'Note');
  });

  test('props default to empty and drive toString', () {
    expect(const Home().props, isEmpty);
    expect(const Home().toString(), 'Home');
    expect(const Note('5').toString(), 'Note(5)');
  });

  test('== distinguishes types and rejects non-route operands', () {
    expect(const Home() == const Plain(), isFalse);
    const Object other = 'home';
    expect(const Home() == other, isFalse);
  });
}
