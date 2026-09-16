import 'package:form_engine/form_engine.dart';
import 'package:test/test.dart';

void main() {
  test('a rect dragged past the edge is pulled back inside the page', () {
    expect(
      const FractionalRect(0.9, 0.95, 0.3, 0.2).clampedToPage(),
      const FractionalRect(0.7, 0.8, 0.3, 0.2),
    );
  });

  test('a rect already inside the page is left alone', () {
    const r = FractionalRect(0.1, 0.1, 0.2, 0.2);
    expect(r.clampedToPage(), r);
  });

  test('a rect larger than the page is clamped to the page', () {
    final r = const FractionalRect(0.5, 0.5, 2, 2).clampedToPage();
    expect(r.width, 1.0);
    expect(r.left, 0.0);
  });
}
