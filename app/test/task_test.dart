import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/models/task.dart';

final _t = DateTime.utc(2025, 1, 1);

void main() {
  test('Task hasContent detects text and attachments', () {
    final empty = Task(
      id: '1',
      title: '',
      status: TaskStatus.inbox,
      createdAt: _t,
      updatedAt: _t,
    );
    expect(empty.hasContent, false);

    final withTitle = Task(
      id: '2',
      title: 'hello',
      status: TaskStatus.inbox,
      createdAt: _t,
      updatedAt: _t,
    );
    expect(withTitle.hasContent, true);
  });

  test('Task round-trip json', () {
    final task = Task(
      id: 'abc',
      title: '测试',
      status: TaskStatus.inbox,
      createdAt: _t,
      updatedAt: _t,
      isDaily: true,
      dailyUntil: DateTime(2026, 6, 30),
      lastDailyCompletedAt: DateTime.utc(2026, 6, 7, 12),
      dueDate: DateTime(2026, 6, 15),
      attachments: [
        TaskAttachment(type: AttachmentType.image, localPath: '/tmp/a.png'),
      ],
    );
    final restored = Task.fromJson(task.toJson());
    expect(restored.title, '测试');
    expect(restored.attachments.length, 1);
    expect(restored.isDaily, isTrue);
    expect(restored.dailyUntil, DateTime(2026, 6, 30));
    expect(restored.lastDailyCompletedAt, DateTime.utc(2026, 6, 7, 12));
    expect(restored.dueDate, DateTime(2026, 6, 15));
  });
}
