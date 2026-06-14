import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/keyboard_lift.dart';

void main() {
  testWidgets('does not extend background when keyboard is closed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KeyboardLift(
            backgroundColor: Colors.red,
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: Text('footer'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('keyboard_lift_extended_background')),
      findsNothing,
    );
  });

  testWidgets('extends background when keyboard is open',
      (WidgetTester tester) async {
    const keyboardInset = 300.0;
    const childHeight = 80.0;

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final dpr = tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset * dpr);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: KeyboardLift(
            backgroundColor: Colors.red,
            duration: Duration.zero,
            child: SizedBox(
              height: childHeight,
              width: double.infinity,
              child: Text('footer'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('keyboard_lift_extended_background')),
      findsOneWidget,
    );

    final bgSize = tester.getSize(
      find.byKey(const Key('keyboard_lift_extended_background')),
    );
    final childSize = tester.getSize(find.text('footer'));

    expect(bgSize.height, childSize.height + keyboardInset);
    expect(childSize.height, childHeight);
  });

  testWidgets('respects bottomObstruction when computing lift',
      (WidgetTester tester) async {
    const keyboardInset = 300.0;
    const obstruction = 80.0;
    const childHeight = 80.0;
    const expectedLift = keyboardInset - obstruction;

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final dpr = tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset * dpr);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: KeyboardLift(
            backgroundColor: Colors.red,
            bottomObstruction: obstruction,
            duration: Duration.zero,
            child: SizedBox(
              height: childHeight,
              width: double.infinity,
              child: Text('footer'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bgSize = tester.getSize(
      find.byKey(const Key('keyboard_lift_extended_background')),
    );
    final childSize = tester.getSize(find.text('footer'));

    expect(bgSize.height, childSize.height + expectedLift);
  });
}
