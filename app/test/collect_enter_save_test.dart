import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';

Future<void> _pumpCollectCard(
  WidgetTester tester, {
  required TextEditingController controller,
  required FocusNode focusNode,
  VoidCallback? onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 640,
          child: BigTaskCard(
            mode: BigTaskCardMode.collect,
            controller: controller,
            focusNode: focusNode,
            onSave: onSave,
            editing: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Enter in collect title triggers onSave', (tester) async {
    final controller = TextEditingController(text: 'Buy milk');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    var saved = false;
    await _pumpCollectCard(
      tester,
      controller: controller,
      focusNode: focusNode,
      onSave: () => saved = true,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(saved, isTrue);
  });

  testWidgets('Shift+Enter in collect title does not trigger onSave',
      (tester) async {
    final controller = TextEditingController(text: 'Line one');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    var saved = false;
    await _pumpCollectCard(
      tester,
      controller: controller,
      focusNode: focusNode,
      onSave: () => saved = true,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(saved, isFalse);
  });
}
