import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/models/task_check_in.dart';
import 'package:todo_app/shared/widgets/big_task_card.dart';

Task _task({
  int checkInTarget = 3,
  int checkInCount = 2,
  DateTime? lastCheckInAt,
}) {
  final now = DateTime(2026, 6, 7);
  return Task(
    id: '1',
    title: 'Workout',
    status: TaskStatus.inbox,
    createdAt: now,
    updatedAt: now,
    checkInTarget: checkInTarget,
    checkInCount: checkInCount,
    lastCheckInAt: lastCheckInAt ?? now,
  );
}

Future<void> _pumpProcessCard(
  WidgetTester tester, {
  required Task task,
  VoidCallback? onResetCheckInProgress,
}) async {
  final controller = TextEditingController(text: task.title);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 640,
          child: BigTaskCard(
            mode: BigTaskCardMode.process,
            task: task,
            controller: controller,
            checkInLabel: checkInLabel(task, now: DateTime(2026, 6, 7)),
            onResetCheckInProgress: onResetCheckInProgress,
            onComplete: () {},
            onSomeday: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows reset button when callback provided with check-in label',
      (tester) async {
    await _pumpProcessCard(
      tester,
      task: _task(),
      onResetCheckInProgress: () {},
    );

    expect(find.text('打卡 2/3'), findsOneWidget);
    expect(find.text('重置进度'), findsOneWidget);
  });

  testWidgets('hides reset button when callback is null', (tester) async {
    await _pumpProcessCard(
      tester,
      task: _task(checkInCount: 0, lastCheckInAt: null),
      onResetCheckInProgress: null,
    );

    expect(find.text('打卡 0/3'), findsOneWidget);
    expect(find.text('重置进度'), findsNothing);
  });

  testWidgets('hides reset button for single check-in tasks', (tester) async {
    await _pumpProcessCard(
      tester,
      task: _task(checkInTarget: 1, checkInCount: 0, lastCheckInAt: null),
      onResetCheckInProgress: null,
    );

    expect(find.textContaining('打卡'), findsNothing);
    expect(find.text('重置进度'), findsNothing);
  });

  testWidgets('tapping reset button invokes callback', (tester) async {
    var tapped = false;
    await _pumpProcessCard(
      tester,
      task: _task(),
      onResetCheckInProgress: () => tapped = true,
    );

    await tester.tap(find.text('重置进度'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
