import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app.dart';

void main() {
  testWidgets('App launches with collect tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TodoApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('收集'), findsOneWidget);
    expect(find.text('处理'), findsOneWidget);
  });
}
