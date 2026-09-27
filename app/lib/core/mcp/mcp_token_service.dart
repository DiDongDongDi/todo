import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_app/core/auth/auth_service.dart';

/// MCP 长期 Token 管理：调用 mcp-tokens Edge Function（需登录）。
class McpToken {
  const McpToken({
    required this.id,
    required this.name,
    required this.tokenPrefix,
    required this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final String tokenPrefix;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  factory McpToken.fromJson(Map<String, dynamic> json) {
    return McpToken(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tokenPrefix: json['token_prefix'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
    );
  }
}

/// 生成成功时返回，[plainToken] 明文仅此一次可得。
class McpCreatedToken {
  const McpCreatedToken({required this.token, required this.plainToken});

  final McpToken token;
  final String plainToken;
}

class McpTokenException implements Exception {
  const McpTokenException(this.message);

  final String message;

  @override
  String toString() => message;
}

final mcpTokenServiceProvider = Provider<McpTokenService>((ref) {
  return McpTokenService();
});

final mcpTokensProvider =
    AsyncNotifierProvider<McpTokensNotifier, List<McpToken>>(
  McpTokensNotifier.new,
);

class McpTokensNotifier extends AsyncNotifier<List<McpToken>> {
  @override
  Future<List<McpToken>> build() {
    return ref.read(mcpTokenServiceProvider).listTokens();
  }

  Future<McpCreatedToken> create(String name) async {
    final created = await ref.read(mcpTokenServiceProvider).createToken(name);
    await refresh();
    return created;
  }

  Future<void> revoke(String tokenId) async {
    await ref.read(mcpTokenServiceProvider).revokeToken(tokenId);
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(mcpTokenServiceProvider).listTokens(),
    );
  }
}

class McpTokenService {
  SupabaseClient get _client {
    final client = AuthService.instance.client;
    if (client == null) throw const McpTokenException('Supabase 未配置');
    return client;
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (!AuthService.instance.isSignedIn) {
      throw const McpTokenException('请先登录账号');
    }

    FunctionResponse response;
    try {
      response = await _client.functions.invoke('mcp-tokens', body: body);
    } on FunctionException catch (e) {
      throw McpTokenException(_extractError(e));
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['error'] is String) {
        throw McpTokenException(data['error'] as String);
      }
      return data;
    }
    throw const McpTokenException('服务返回异常');
  }

  String _extractError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return '请求失败（${e.status}）';
  }

  Future<List<McpToken>> listTokens() async {
    final data = await _invoke({'action': 'list'});
    final tokens = data['tokens'] as List? ?? const [];
    return tokens
        .map((e) => McpToken.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<McpCreatedToken> createToken(String name) async {
    final data = await _invoke({'action': 'create', 'name': name});
    final plainToken = data['token'] as String?;
    if (plainToken == null || plainToken.isEmpty) {
      throw const McpTokenException('服务未返回 token');
    }
    return McpCreatedToken(
      token: McpToken.fromJson(data),
      plainToken: plainToken,
    );
  }

  Future<void> revokeToken(String tokenId) async {
    await _invoke({'action': 'revoke', 'token_id': tokenId});
  }
}
