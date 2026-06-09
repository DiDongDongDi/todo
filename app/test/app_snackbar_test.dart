import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

const _kExpectedBannerHeight = 52.0;

Finder _bannerHeightFinder() {
  return find.descendant(
    of: find.byType(Positioned),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox && widget.height == _kExpectedBannerHeight,
    ),
  );
}

Future<void> _pumpSnackBarHarness(
  WidgetTester tester, {
  required void Function(BuildContext context) onShow,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => onShow(context),
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
}

void main() {
  testWidgets('showAppSnackBar renders near top of screen',
      (WidgetTester tester) async {
    await _pumpSnackBarHarness(
      tester,
      onShow: (context) {
        showAppSnackBar(
          context,
          message: '已收集',
          icon: Icons.check_circle_outline,
          type: AppSnackType.success,
          duration: const Duration(milliseconds: 100),
        );
      },
    );

    expect(find.text('已收集'), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.top, greaterThan(0));

    final textBox = tester.getRect(find.text('已收集'));
    expect(textBox.top, lessThan(200));

    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('showAppSnackBar keeps fixed height for short message',
      (WidgetTester tester) async {
    await _pumpSnackBarHarness(
      tester,
      onShow: (context) {
        showAppSnackBar(
          context,
          message: '请先输入内容',
          icon: Icons.edit_outlined,
          type: AppSnackType.warning,
          duration: const Duration(milliseconds: 100),
        );
      },
    );

    expect(
      tester.getSize(_bannerHeightFinder()).height,
      _kExpectedBannerHeight,
    );

    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('showAppSnackBar keeps fixed height for long wrapping message',
      (WidgetTester tester) async {
    await _pumpSnackBarHarness(
      tester,
      onShow: (context) {
        showAppSnackBar(
          context,
          message: 'Web 版暂不支持录音，请使用移动端',
          icon: Icons.mic_off_outlined,
          type: AppSnackType.info,
          duration: const Duration(milliseconds: 100),
        );
      },
    );

    expect(
      tester.getSize(_bannerHeightFinder()).height,
      _kExpectedBannerHeight,
    );

    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('showAppSnackBar keeps fixed height with action button',
      (WidgetTester tester) async {
    await _pumpSnackBarHarness(
      tester,
      onShow: (context) {
        showAppSnackBar(
          context,
          message: '已收集',
          icon: Icons.check_circle_outline,
          type: AppSnackType.success,
          duration: const Duration(milliseconds: 100),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {},
          ),
        );
      },
    );

    expect(find.text('撤销'), findsOneWidget);
    expect(
      tester.getSize(_bannerHeightFinder()).height,
      _kExpectedBannerHeight,
    );

    await tester.pump(const Duration(milliseconds: 150));
  });
}
