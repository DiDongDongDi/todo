import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        showAppSnackBar(
          context,
          message: '登录失败: $e',
          icon: Icons.error_outline,
          type: AppSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final user = authAsync.value?.session?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('账号与同步')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!AuthService.instance.isConfigured) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Supabase 未配置。复制 supabase_config.example.dart 为 supabase_config.dart 并填入密钥。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (user != null) ...[
              Text('已登录: ${user.email ?? user.id}'),
              const SizedBox(height: 8),
              Text('同步: ${syncStatus.name}'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await AuthService.instance.signOut();
                  ref.read(syncEngineProvider).stop();
                },
                child: const Text('退出登录'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(syncEngineProvider).sync(),
                child: const Text('立即同步'),
              ),
            ] else ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
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
                    : Text(_sent ? '已发送魔法链接' : '发送魔法链接登录'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
