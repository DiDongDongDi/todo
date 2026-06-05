import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Collect tab shows card', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: TodoApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Process tab shows content', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: TodoApp()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.swipe_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final hasEmpty = find.text('收集箱是空的，去收集页记一条吧').evaluate().isNotEmpty;
    final hasTasks = find.textContaining('待处理').evaluate().isNotEmpty;

    expect(hasEmpty || hasTasks, isTrue);
  });
}
