import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';

void main() {
  testWidgets('subtaskTitleInputDecoration uses compact subtask styling',
      (tester) async {
    InputDecoration? decoration;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decoration = subtaskTitleInputDecoration(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decoration, isNotNull);
    expect(decoration!.hintText, '子任务');
    expect(decoration!.isDense, isTrue);
    expect(decoration!.filled, isTrue);
    expect(
      decoration!.contentPadding,
      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  });

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

  testWidgets('SubtaskTitleEditor syncs focus nodes when list is mutated in place',
      (tester) async {
    final controllers = <TextEditingController>[];

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

    controllers.add(TextEditingController());
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
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), '洗袜子');
    expect(controllers.first.text, '洗袜子');
  });
}
