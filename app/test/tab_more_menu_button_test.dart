import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/tab_more_menu_button.dart';

enum _TestAction { first, second }

void main() {
  testWidgets('TabMoreMenuButton shows menu items on tap',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: TabMoreMenuButton<_TestAction>(
              items: const [
                TabMoreMenuEntry.item(
                  value: _TestAction.first,
                  icon: Icons.star_outline,
                  label: '第一项',
                ),
                TabMoreMenuEntry.item(
                  value: _TestAction.second,
                  icon: Icons.favorite_outline,
                  label: '第二项',
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('第一项'), findsNothing);

    await tester.tap(find.byTooltip('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('第一项'), findsOneWidget);
    expect(find.text('第二项'), findsOneWidget);
  });

  testWidgets('TabMoreMenuButton onSelected fires when item tapped',
      (WidgetTester tester) async {
    _TestAction? selected;

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: TabMoreMenuButton<_TestAction>(
              items: const [
                TabMoreMenuEntry.item(
                  value: _TestAction.first,
                  icon: Icons.star_outline,
                  label: '第一项',
                ),
                TabMoreMenuEntry.item(
                  value: _TestAction.second,
                  icon: Icons.favorite_outline,
                  label: '第二项',
                ),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.tap(find.text('第二项'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(selected, _TestAction.second);
  });

  testWidgets('TabMoreMenuButton dismisses when barrier tapped',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: TabMoreMenuButton<_TestAction>(
              items: const [
                TabMoreMenuEntry.item(
                  value: _TestAction.first,
                  icon: Icons.star_outline,
                  label: '第一项',
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('第一项'), findsOneWidget);

    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();

    expect(find.text('第一项'), findsNothing);
  });
}
