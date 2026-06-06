import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo_app/core/auth/auth_error_messages.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/sync/sync_engine.dart';
import 'package:todo_app/shared/widgets/app_snackbar.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  bool _manualSyncing = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!AuthService.instance.isConfigured) {
      showAppSnackBar(
        context,
        message: '请先配置 Supabase（见 README）',
        icon: Icons.settings_outlined,
        type: AppSnackType.warning,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithEmail(_emailController.text.trim());
      setState(() => _sent = true);
      ref.read(syncEngineProvider).startPeriodicSync();
      await ref.read(syncEngineProvider).sync();
    } catch (e) {
      if (mounted) {
        final snackType = authSignInErrorSnackType(e);
        showAppSnackBar(
          context,
          message: authSignInErrorMessage(e),
          icon: snackType == AppSnackType.warning
              ? Icons.schedule_outlined
              : Icons.error_outline,
          type: snackType,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _manualSyncing = true);
    try {
      await ref.read(syncEngineProvider).sync();
      if (!mounted) return;

      final status = ref.read(syncStatusProvider);
      if (status == SyncStatus.idle) {
        showAppSnackBar(
          context,
          message: '同步完成',
          icon: Icons.cloud_done_outlined,
          type: AppSnackType.success,
        );
      } else if (status == SyncStatus.offline) {
        showAppSnackBar(
          context,
          message: '当前离线，联网后将自动同步',
          icon: Icons.wifi_off_outlined,
          type: AppSnackType.warning,
        );
      } else if (status == SyncStatus.error) {
        showAppSnackBar(
          context,
          message: '同步失败，请稍后重试',
          icon: Icons.error_outline,
          type: AppSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _manualSyncing = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    ref.read(syncEngineProvider).stop();
    ref.read(lastSyncAtProvider.notifier).state = null;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    if (mounted) setState(() => _sent = false);
  }

  String _formatLastSync(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return DateFormat('M月d日 HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      final wasSignedIn = prev?.value?.session != null;
      final isSignedIn = next.value?.session != null;
      if (!wasSignedIn && isSignedIn && mounted) {
        showAppSnackBar(
          context,
          message: '登录成功，云同步已开启',
          icon: Icons.cloud_done_outlined,
          type: AppSnackType.success,
        );
      }
    });

    final authAsync = ref.watch(authStateProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSyncAt = ref.watch(lastSyncAtProvider);
    final user = authAsync.value?.session?.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('账号与同步')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!AuthService.instance.isConfigured) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Supabase 未配置。复制 supabase_config.example.dart 为 supabase_config.dart 并填入密钥。',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (user != null) ...[
            _SyncStatusCard(
              syncStatus: syncStatus,
              email: user.email ?? user.id,
              lastSyncAt: lastSyncAt,
              formatLastSync: _formatLastSync,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _manualSyncing || syncStatus == SyncStatus.syncing
                  ? null
                  : _syncNow,
              icon: _manualSyncing || syncStatus == SyncStatus.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_outlined),
              label: const Text('立即同步'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _signOut,
              child: const Text('退出登录'),
            ),
          ] else ...[
            Text(
              '登录后，待办将自动同步到云端，可在多设备间保持一致。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 24),
            if (_sent) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '魔法链接已发送',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '请查收 ${_emailController.text.trim()} 的邮件并点击链接。'
                              '点击后会自动打开本 App 并完成登录，本页将显示「云同步已开启」。',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_sent,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _signIn,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_sent ? '重新发送魔法链接' : '发送魔法链接登录'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.syncStatus,
    required this.email,
    required this.lastSyncAt,
    required this.formatLastSync,
  });

  final SyncStatus syncStatus;
  final String email;
  final DateTime? lastSyncAt;
  final String Function(DateTime time) formatLastSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = switch (syncStatus) {
      SyncStatus.idle => colorScheme.primary,
      SyncStatus.syncing => colorScheme.tertiary,
      SyncStatus.error => colorScheme.error,
      SyncStatus.offline => colorScheme.outline,
    };
    final headline = switch (syncStatus) {
      SyncStatus.idle => '云同步已开启',
      SyncStatus.syncing => '正在同步…',
      SyncStatus.error => '同步遇到问题',
      SyncStatus.offline => '离线，待联网后同步',
    };
    final detail = switch (syncStatus) {
      SyncStatus.idle when lastSyncAt != null =>
        '上次同步：${formatLastSync(lastSyncAt!)}',
      SyncStatus.idle => '首次同步完成后会显示时间',
      SyncStatus.syncing => '正在与云端交换数据',
      SyncStatus.error => '请检查网络后点击「立即同步」重试',
      SyncStatus.offline => '本地更改已保存，联网后自动上传',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: syncStatus == SyncStatus.syncing
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accent,
                      ),
                    )
                  : Icon(syncStatus.icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  if (syncStatus != SyncStatus.idle) ...[
                    const SizedBox(height: 8),
                    Text(
                      syncStatus.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
