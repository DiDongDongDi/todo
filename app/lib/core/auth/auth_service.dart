import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_app/core/config/supabase_config.example.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return AuthService.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = AuthService.instance.client;
  if (client == null) {
    return Stream.value(const AuthState(AuthChangeEvent.signedOut, null));
  }
  return client.auth.onAuthStateChange;
});

final authInitProvider = FutureProvider<void>((ref) async {
  await AuthService.instance.initialize();
});

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  SupabaseClient? _client;
  SupabaseClient? get client => _client;

  bool get isConfigured =>
      SupabaseConfig.url.isNotEmpty &&
      SupabaseConfig.url != 'YOUR_SUPABASE_URL' &&
      SupabaseConfig.anonKey.isNotEmpty &&
      SupabaseConfig.anonKey != 'YOUR_SUPABASE_ANON_KEY';

  Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    _client = Supabase.instance.client;
  }

  User? get currentUser => _client?.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  Future<void> signInWithEmail(String email) async {
    final c = _client;
    if (c == null) throw StateError('Supabase 未配置');
    await c.auth.signInWithOtp(email: email);
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}
