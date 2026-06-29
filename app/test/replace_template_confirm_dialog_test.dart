import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/replace_template_confirm_dialog.dart';

Future<void> _openDialog(WidgetTester tester, {String title = '周报模板'}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  showReplaceTemplateConfirmDialog(context, title);
                },
                child: const Text('Open dialog'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('showReplaceTemplateConfirmDialog shows title and message',
      (tester) async {
    await _openDialog(tester, title: '周报模板');

    expect(find.text('替换模板'), findsOneWidget);
    expect(
      find.text('已存在名为「周报模板」的模板，保存将替换原有内容。是否继续？'),
      findsOneWidget,
    );
  });

  testWidgets('cancel returns false', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showReplaceTemplateConfirmDialog(
                      context,
                      '周报模板',
                    );
                  },
                  child: const Text('Open dialog'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('替换模板'), findsNothing);
  });

  testWidgets('confirm returns true', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showReplaceTemplateConfirmDialog(
                      context,
                      '周报模板',
                    );
                  },
                  child: const Text('Open dialog'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('替换'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('替换模板'), findsNothing);
  });
}
