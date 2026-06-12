import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/import/subtask_batch_import_parser.dart';

void main() {
  group('parseSubtaskBatchImport', () {
    test('splits multi-line text into titles', () {
      const input = '买牛奶\n写报告\n回邮件';
      expect(parseSubtaskBatchImport(input), ['买牛奶', '写报告', '回邮件']);
    });

    test('skips empty lines', () {
      const input = 'first\n\n  \nsecond';
      expect(parseSubtaskBatchImport(input), ['first', 'second']);
    });

    test('trims whitespace on each line', () {
      const input = '  alpha  \n\tbeta\t';
      expect(parseSubtaskBatchImport(input), ['alpha', 'beta']);
    });

    test('handles CRLF line endings', () {
      const input = 'one\r\ntwo\r\nthree';
      expect(parseSubtaskBatchImport(input), ['one', 'two', 'three']);
    });

    test('strips Dida footer', () {
      const input = '''
task one
task two

来自滴答清单:
https://dida365.com''';

      expect(parseSubtaskBatchImport(input), ['task one', 'task two']);
    });

    test('returns empty for blank input', () {
      expect(parseSubtaskBatchImport(''), isEmpty);
      expect(parseSubtaskBatchImport('   \n  \n'), isEmpty);
    });
  });
}
