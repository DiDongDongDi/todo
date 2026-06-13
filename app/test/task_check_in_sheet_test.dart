import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/shared/widgets/task_check_in_sheet.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required int checkInTarget,
    required ValueChanged<int> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showTaskCheckInSheet(
                context,
                checkInTarget: checkInTarget,
                onCheckInTargetChanged: onChanged,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  test('checkInEditorSummary labels inactive and active targets', () {
    expect(checkInEditorSummary(defaultCheckInTarget), '打卡');
    expect(checkInEditorSummary(minActiveCheckInTarget), '打卡 · 2次');
    expect(checkInEditorSummary(5), '打卡 · 5次');
  });

  testWidgets('sheet defaults to 2 when check-in is inactive', (tester) async {
    await pumpSheet(
      tester,
      checkInTarget: defaultCheckInTarget,
      onChanged: (_) {},
    );

    expect(find.text('2 次'), findsOneWidget);
    final minus = find.widgetWithIcon(IconButton, Icons.remove);
    final minusButton = tester.widget<IconButton>(minus);
    expect(minusButton.onPressed, isNull);
  });

  testWidgets('sheet shows existing active target', (tester) async {
    await pumpSheet(
      tester,
      checkInTarget: 5,
      onChanged: (_) {},
    );

    expect(find.text('5 次'), findsOneWidget);
  });

  testWidgets('cancel check-in commits default target', (tester) async {
    int? committed;
    await pumpSheet(
      tester,
      checkInTarget: 5,
      onChanged: (value) => committed = value,
    );

    await tester.tap(find.text('取消打卡'));
    await tester.pumpAndSettle();

    expect(committed, defaultCheckInTarget);
    expect(find.text('打卡设置'), findsNothing);
  });
}
