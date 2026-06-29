import 'package:flutter/material.dart';

Future<bool> showReplaceTemplateConfirmDialog(
  BuildContext context,
  String title,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('替换模板'),
      content: Text('已存在名为「$title」的模板，保存将替换原有内容。是否继续？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('替换'),
        ),
      ],
    ),
  );
  return result ?? false;
}
