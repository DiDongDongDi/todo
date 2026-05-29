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
      attachments: [
        TaskAttachment(type: AttachmentType.image, localPath: '/tmp/a.png'),
      ],
    );
    final restored = Task.fromJson(task.toJson());
    expect(restored.title, '测试');
    expect(restored.attachments.length, 1);
  });
}
