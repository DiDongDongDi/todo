import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';

void main() {
  testWidgets('SubtaskTitleEditor reports focus changes', (tester) async {
    final controllers = [TextEditingController()];
    bool? lastFocused;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtaskTitleEditor(
            controllers: controllers,
            onRemove: (_) {},
            onAnyFieldFocusChanged: (focused) => lastFocused = focused,
          ),
        ),
      ),
    );

    expect(lastFocused, isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(lastFocused, isTrue);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('SubtaskTitleEditor keeps focus after tap', (tester) async {
    final controllers = [TextEditingController()];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtaskTitleEditor(
            controllers: controllers,
            onRemove: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), '子任务内容');
    expect(controllers.first.text, '子任务内容');
  });
}
