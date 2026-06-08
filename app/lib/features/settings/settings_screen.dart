import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/shared/layout/app_layout.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: AppLayout.cardPadding.copyWith(top: 24, bottom: 24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bookmark_outline),
          title: const Text('任务模板'),
          subtitle: const Text('查看、编辑或删除已保存的模板'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/templates'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.volume_up_outlined),
          title: const Text('音效'),
          subtitle: const Text('配置收集、处理、恢复等操作的提示音'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/sounds'),
        ),
      ],
    );
  }
}
