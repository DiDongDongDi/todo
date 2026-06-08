import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

void main() {
  testWidgets('showAppSnackBar renders near top of screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showAppSnackBar(
                      context,
                      message: '已收集',
                      icon: Icons.check_circle_outline,
                      type: AppSnackType.success,
                      duration: const Duration(milliseconds: 100),
                    );
                  },
                  child: const Text('Show banner'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show banner'));
    await tester.pump();

    expect(find.text('已收集'), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.top, greaterThan(0));

    final textBox = tester.getRect(find.text('已收集'));
    expect(textBox.top, lessThan(200));

    await tester.pump(const Duration(milliseconds: 150));
  });
}
