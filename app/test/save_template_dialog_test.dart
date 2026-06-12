import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/save_template_dialog.dart';

Future<void> _openDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showSaveTemplateDialog(
                  context,
                  defaultTitle: '默认模板名',
                ),
                child: const Text('打开'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('取消关闭对话框不崩溃', (tester) async {
    await _openDialog(tester);
    expect(find.text('保存为模板'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('保存为模板'), findsNothing);
  });

  testWidgets('保存返回模板名称', (tester) async {
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), '我的模板');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存为模板'), findsNothing);
  });

  testWidgets('点击外部关闭对话框不崩溃', (tester) async {
    await _openDialog(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('保存为模板'), findsNothing);
  });
}
