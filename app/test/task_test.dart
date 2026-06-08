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
      lastDailyCompletedAt: DateTime(2026, 6, 7),
      dueDate: DateTime(2026, 6, 15),
      parentId: 'parent-uuid',
      attachments: [
        TaskAttachment(type: AttachmentType.image, localPath: '/tmp/a.png'),
      ],
    );
    final restored = Task.fromJson(task.toJson());
    expect(restored.title, '测试');
    expect(restored.attachments.length, 1);
    expect(restored.isDaily, isTrue);
    expect(restored.dailyUntil, DateTime(2026, 6, 30));
    expect(restored.lastDailyCompletedAt, DateTime(2026, 6, 7));
    expect(restored.toJson()['last_daily_completed_at'], '2026-06-07');
    expect(restored.dueDate, DateTime(2026, 6, 15));
    expect(restored.parentId, 'parent-uuid');
  });

  test('Task fromJson parses legacy ISO last_daily_completed_at', () {
    final utcIso = DateTime.utc(2026, 6, 8, 18).toIso8601String();
    final restored = Task.fromJson({
      'id': 'abc',
      'title': 'test',
      'status': 'inbox',
      'created_at': _t.toIso8601String(),
      'updated_at': _t.toIso8601String(),
      'is_daily': true,
      'last_daily_completed_at': utcIso,
    });
    final expectedLocal = DateTime.utc(2026, 6, 8, 18).toLocal();
    expect(
      restored.lastDailyCompletedAt,
      DateTime(expectedLocal.year, expectedLocal.month, expectedLocal.day),
    );
  });
}
