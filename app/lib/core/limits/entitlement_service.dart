import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/limits/resource_limits.dart';

/// Whether the signed-in user is on the email whitelist (AI bypass + attachments).
final isWhitelistedProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);

  if (!AuthService.instance.isSignedIn) return false;

  final email = AuthService.instance.currentUser?.email?.trim().toLowerCase();
  if (email == null || email.isEmpty) return false;

  final client = AuthService.instance.client;
  if (client == null) return false;

  final row = await client
      .from('ai_email_whitelist')
      .select('email')
      .eq('email', email)
      .maybeSingle();

  return row != null;
});

/// Effective per-task attachment cap; `null` means unlimited (whitelist).
final maxAttachmentsPerTaskProvider = Provider<int?>((ref) {
  final whitelisted = ref.watch(isWhitelistedProvider).value ?? false;
  if (whitelisted) return null;
  return ResourceLimits.maxAttachmentsPerTask;
});
