import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  String defaultTitle = '示例任务',
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showSaveTemplateDialog(
                  context,
                  defaultTitle: defaultTitle,
                ),
                child: const Text('Open sheet'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('showSaveTemplateDialog uses bottom sheet with titleMedium title',
      (tester) async {
    await _openSheet(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('保存为模板'), findsOneWidget);

    final title = tester.widget<Text>(find.text('保存为模板'));
    final theme = Theme.of(tester.element(find.byType(MaterialApp)));
    expect(title.style, theme.textTheme.titleMedium);
  });

  testWidgets('showSaveTemplateDialog prefills default title', (tester) async {
    await _openSheet(tester, defaultTitle: '  我的父任务  ');

    expect(find.text('我的父任务'), findsOneWidget);
  });

  testWidgets('showSaveTemplateDialog returns trimmed title on save',
      (tester) async {
    String? result;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showSaveTemplateDialog(
                      context,
                      defaultTitle: '旧标题',
                    );
                  },
                  child: const Text('Open sheet'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  新模板  ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result, '新模板');
    expect(find.text('保存为模板'), findsNothing);
  });

  testWidgets('showSaveTemplateDialog keeps sheet open when title is empty',
      (tester) async {
    await _openSheet(tester, defaultTitle: '');

    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('请输入模板名称'), findsOneWidget);
    expect(find.text('保存为模板'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });
}
