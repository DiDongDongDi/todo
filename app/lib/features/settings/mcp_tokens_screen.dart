import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/config/supabase_config.dart';
import 'package:todo_app/core/mcp/mcp_token_service.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

class McpTokensScreen extends ConsumerWidget {
  const McpTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = AuthService.instance.isSignedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('MCP Token')),
      body: !isSignedIn
          ? _buildSignedOut(context)
          : _buildTokenList(context, ref),
      floatingActionButton: isSignedIn
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('生成 Token'),
            )
          : null,
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '登录后可生成 MCP Token，\n用于在 Cursor / Claude 等客户端中管理任务',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/auth'),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenList(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(mcpTokensProvider);

    return tokensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(mcpTokensProvider.notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (tokens) {
        if (tokens.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '暂无 Token\n点击右下角生成，复制到 MCP 客户端即可使用',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final active = tokens.where((t) => t.isActive).toList();
        final revoked = tokens.where((t) => !t.isActive).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ...active.map((t) => _TokenTile(token: t)),
            if (revoked.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '已吊销',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              ...revoked.map((t) => _TokenTile(token: t)),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('生成 MCP Token'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: '名称',
              hintText: '例如：Cursor、Claude Desktop',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
            maxLength: 50,
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, nameController.text.trim()),
              child: const Text('生成'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty || !context.mounted) return;

    try {
      final created = await ref.read(mcpTokensProvider.notifier).create(name);
      if (!context.mounted) return;
      await _showTokenCreatedDialog(context, created);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: '$e',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _showTokenCreatedDialog(
    BuildContext context,
    McpCreatedToken created,
  ) async {
    final configJson =
        '{\n'
        '  "mcpServers": {\n'
        '    "todo": {\n'
        '      "url": "${SupabaseConfig.url}/functions/v1/mcp",\n'
        '      "headers": {\n'
        '        "Authorization": "Bearer ${created.plainToken}"\n'
        '      }\n'
        '    }\n'
        '  }\n'
        '}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Token 已生成'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '请立即复制保存，关闭后将无法再次查看完整 Token。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  created.plainToken,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'MCP 客户端配置示例：',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  configJson,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: created.plainToken),
              );
              if (context.mounted) {
                showAppSnackBar(
                  context,
                  message: 'Token 已复制',
                  icon: Icons.copy,
                  type: AppSnackType.success,
                );
              }
            },
            child: const Text('复制 Token'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: configJson));
              if (context.mounted) {
                showAppSnackBar(
                  context,
                  message: '配置已复制',
                  icon: Icons.copy,
                  type: AppSnackType.success,
                );
              }
            },
            child: const Text('复制配置'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

class _TokenTile extends ConsumerWidget {
  const _TokenTile({required this.token});

  final McpToken token;

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = StringBuffer('${token.tokenPrefix}…');
    subtitle.write(' · 创建于 ${_formatTime(token.createdAt)}');
    if (token.lastUsedAt != null) {
      subtitle.write(' · 最后使用 ${_formatTime(token.lastUsedAt!)}');
    }

    return ListTile(
      leading: Icon(
        token.isActive ? Icons.key_outlined : Icons.key_off_outlined,
      ),
      title: Text(
        token.name,
        style: token.isActive
            ? null
            : TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.outline,
              ),
      ),
      subtitle: Text(subtitle.toString()),
      trailing: token.isActive
          ? IconButton(
              icon: const Icon(Icons.block),
              tooltip: '吊销',
              onPressed: () => _confirmRevoke(context, ref),
            )
          : null,
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('吊销 Token'),
            content: Text(
              '吊销后「${token.name}」将立即失效，使用该 Token 的 MCP 客户端将无法访问。此操作不可撤销。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('吊销'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(mcpTokensProvider.notifier).revoke(token.id);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: 'Token 已吊销',
        icon: Icons.block,
        type: AppSnackType.info,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: '$e',
        icon: Icons.error_outline,
        type: AppSnackType.error,
      );
    }
  }
}
