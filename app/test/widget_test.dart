import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches with collect tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TodoApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('收集'), findsNWidgets(2));
    expect(find.text('处理'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('Collect tab starts unfocused on cold launch',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: TodoApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('取消'), findsNothing);
  });
}
