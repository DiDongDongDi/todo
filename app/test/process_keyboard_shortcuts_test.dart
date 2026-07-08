import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CallbackShortcuts arrow keys invoke bindings', (tester) async {
    var left = 0;
    var right = 0;
    var up = 0;
    var down = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () => left++,
            const SingleActivator(LogicalKeyboardKey.arrowRight): () => right++,
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => up++,
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => down++,
          },
          child: const Focus(
            autofocus: true,
            child: SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(left, 1);
    expect(right, 1);
    expect(up, 1);
    expect(down, 1);
  });
}
