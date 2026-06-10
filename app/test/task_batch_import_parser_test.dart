import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/import/task_batch_import_parser.dart';

void main() {
  group('stripDidaFooter', () {
    test('removes footer with URL', () {
      const input = '''
- task one

来自滴答清单:
https://dida365.com''';

      expect(stripDidaFooter(input), '- task one');
    });

    test('is case insensitive', () {
      const input = '- task\n来自滴答清单:';
      expect(stripDidaFooter(input), '- task');
    });
  });

  group('parseBatchImportTasks', () {
    test('parses user example', () {
      const input = '''
💡生活-将来也许

-  盐焗虾
-  facebook 注册
    修改一下名字

来自滴答清单:
https://dida365.com''';

      expect(parseBatchImportTasks(input), [
        '盐焗虾',
        'facebook 注册\n    修改一下名字',
      ]);
    });

    test('returns empty for text without task markers', () {
      expect(parseBatchImportTasks('💡生活-将来也许'), isEmpty);
      expect(parseBatchImportTasks(''), isEmpty);
    });

    test('handles single task', () {
      expect(parseBatchImportTasks('- only one'), ['only one']);
    });

    test('skips empty blocks', () {
      expect(parseBatchImportTasks('- \n- real'), ['real']);
    });
  });
}
