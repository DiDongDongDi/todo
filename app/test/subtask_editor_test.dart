import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/subtask_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('insertedMatchesCollapsedClipboard matches Android collapsed paste', () {
    const clipboard = '买牛奶\n写报告';
    expect(
      insertedMatchesCollapsedClipboard('买牛奶 写报告', clipboard),
      isTrue,
    );
    expect(insertedMatchesCollapsedClipboard('你好', clipboard), isFalse);
  });

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

    controllers.first.value = const TextEditingValue(
      text: '子任务内容',
      selection: TextSelection.collapsed(offset: 5),
    );
    await tester.pump();
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
    controllers.first.value = const TextEditingValue(
      text: '洗袜子',
      selection: TextSelection.collapsed(offset: 3),
    );
    await tester.pump();
    expect(controllers.first.text, '洗袜子');
  });

  testWidgets('SubtaskTitleEditor ignores empty submit', (tester) async {
    final controllers = [TextEditingController()];
    var submitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtaskTitleEditor(
            controllers: controllers,
            onRemove: (_) {},
            onSubmitRow: (index) async {
              submitCount++;
              return index + 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(submitCount, 0);
    expect(controllers.length, 1);
  });

  testWidgets(
      'SubtaskTitleEditor focuses appended row when parent adds controller',
      (tester) async {
    final controllers = <TextEditingController>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _SubtaskAppendHarness(controllers: controllers),
      ),
    );

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(controllers.length, 1);
    expect(find.byType(TextField), findsOneWidget);
    final focusNode =
        tester.widget<TextField>(find.byType(TextField)).focusNode!;
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets(
      'SubtaskTitleEditor focuses appended row when list mutates in place',
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
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    final focusNode =
        tester.widget<TextField>(find.byType(TextField)).focusNode!;
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('SubtaskTitleEditor inserts row and focuses on submit',
      (tester) async {
    final controllers = [TextEditingController()];

    await tester.pumpWidget(
      MaterialApp(
        home: _SubtaskEditorHarness(controllers: controllers),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    controllers.first.value = const TextEditingValue(
      text: '第一项',
      selection: TextSelection.collapsed(offset: 3),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump();

    expect(controllers.length, 2);
    expect(controllers.first.text, '第一项');
    expect(controllers[1].text, isEmpty);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('SubtaskTitleEditor keeps focus callback stable during submit',
      (tester) async {
    final controllers = [TextEditingController()];
    final focusHistory = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _SubtaskEditorHarness(
          controllers: controllers,
          onAnyFieldFocusChanged: focusHistory.add,
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    focusHistory.clear();

    controllers.first.value = const TextEditingValue(
      text: '第一项',
      selection: TextSelection.collapsed(offset: 3),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump();

    expect(controllers.length, 2);
    expect(controllers.first.text, '第一项');
    expect(controllers[1].text, isEmpty);
    expect(focusHistory.contains(false), isFalse);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets(
      'SubtaskTitleEditor scrolls appended row into view in scrollable content',
      (tester) async {
    final controllers = <TextEditingController>[];
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: _ScrollableSubtaskHarness(
          scrollController: scrollController,
          controllers: controllers,
        ),
      ),
    );

    expect(scrollController.hasClients, isTrue);
    expect(scrollController.offset, 0);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(controllers.length, 1);
    expect(scrollController.offset, greaterThan(0));
  });

  testWidgets(
      'SubtaskTitleEditor does not batch import when IME commits two chars',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': '行1\n行2\n行3'};
      }
      return null;
    });

    final controllers = [TextEditingController()];
    var importCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubtaskTitleEditor(
            controllers: controllers,
            onRemove: (_) {},
            onImportLines: (_, __) => importCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '你好',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controllers.first.text, '你好');
    expect(importCount, 0);
    expect(controllers.length, 1);
  });

  testWidgets(
      'SubtaskTitleEditor batch imports collapsed multiline paste on Android',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': '买牛奶\n写报告'};
      }
      return null;
    });

    final controllers = [TextEditingController()];

    await tester.pumpWidget(
      MaterialApp(
        home: _SubtaskImportHarness(controllers: controllers),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '买牛奶 写报告',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controllers.length, 2);
    expect(controllers[0].text, '买牛奶');
    expect(controllers[1].text, '写报告');
  });
}

class _SubtaskImportHarness extends StatefulWidget {
  const _SubtaskImportHarness({required this.controllers});

  final List<TextEditingController> controllers;

  @override
  State<_SubtaskImportHarness> createState() => _SubtaskImportHarnessState();
}

class _SubtaskImportHarnessState extends State<_SubtaskImportHarness> {
  void _onImportLines(int index, List<String> lines) {
    setState(() {
      SubtaskTitleEditor.importLinesIntoControllers(
        controllers: widget.controllers,
        index: index,
        lines: lines,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SubtaskTitleEditor(
        controllers: widget.controllers,
        onRemove: (_) {},
        onImportLines: _onImportLines,
      ),
    );
  }
}

class _ScrollableSubtaskHarness extends StatefulWidget {
  const _ScrollableSubtaskHarness({
    required this.scrollController,
    required this.controllers,
  });

  final ScrollController scrollController;
  final List<TextEditingController> controllers;

  @override
  State<_ScrollableSubtaskHarness> createState() =>
      _ScrollableSubtaskHarnessState();
}

class _ScrollableSubtaskHarnessState extends State<_ScrollableSubtaskHarness> {
  void _addRow() {
    setState(() => widget.controllers.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: 200,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          child: Column(
            children: [
              Focus(
                canRequestFocus: false,
                skipTraversal: true,
                child: IconButton(onPressed: _addRow, icon: const Icon(Icons.add)),
              ),
              const SizedBox(height: 400),
              SubtaskTitleEditor(
                controllers: widget.controllers,
                onRemove: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtaskAppendHarness extends StatefulWidget {
  const _SubtaskAppendHarness({required this.controllers});

  final List<TextEditingController> controllers;

  @override
  State<_SubtaskAppendHarness> createState() => _SubtaskAppendHarnessState();
}

class _SubtaskAppendHarnessState extends State<_SubtaskAppendHarness> {
  void _addRow() {
    setState(() => widget.controllers.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: IconButton(onPressed: _addRow, icon: const Icon(Icons.add)),
          ),
          SubtaskTitleEditor(
            controllers: widget.controllers,
            onRemove: (_) {},
          ),
        ],
      ),
    );
  }
}

class _SubtaskEditorHarness extends StatefulWidget {
  const _SubtaskEditorHarness({
    required this.controllers,
    this.onAnyFieldFocusChanged,
  });

  final List<TextEditingController> controllers;
  final ValueChanged<bool>? onAnyFieldFocusChanged;

  @override
  State<_SubtaskEditorHarness> createState() => _SubtaskEditorHarnessState();
}

class _SubtaskEditorHarnessState extends State<_SubtaskEditorHarness> {
  Future<int> _submitRow(int index) async {
    setState(() {
      widget.controllers.insert(index + 1, TextEditingController());
    });
    return index + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SubtaskTitleEditor(
        controllers: widget.controllers,
        onRemove: (_) {},
        onSubmitRow: _submitRow,
        onAnyFieldFocusChanged: widget.onAnyFieldFocusChanged,
      ),
    );
  }
}
