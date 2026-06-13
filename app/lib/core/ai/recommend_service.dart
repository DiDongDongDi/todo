import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/repositories/task_repository.dart';

final recommendServiceProvider = Provider<RecommendService>((ref) {
  return RecommendService(ref);
});

class RecommendResult {
  const RecommendResult({
    required this.recommendedTasks,
    required this.suggestedPlaylistName,
    this.summary,
  });

  final List<Task> recommendedTasks;
  final String suggestedPlaylistName;
  final String? summary;
}

class RecommendService {
  RecommendService(this._ref);

  final Ref _ref;

  static const _maxTasks = 200;

  Future<RecommendResult> recommend(String query) async {
    if (!AuthService.instance.isSignedIn) {
      throw RecommendException('请先登录以使用 AI 推荐');
    }

    final client = AuthService.instance.client;
    if (client == null) {
      throw RecommendException('Supabase 未配置');
    }

    final inbox = _ref.read(inboxTasksProvider).value ?? [];
    final someday = _ref.read(somedayTasksProvider).value ?? [];
    final candidates = [...inbox, ...someday]
        .where((t) => t.parentId == null)
        .take(_maxTasks)
        .toList();

    if (candidates.isEmpty) {
      throw RecommendException('收集箱和将来也许中暂无任务可推荐');
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw RecommendException('请描述你的想法和需求');
    }

    final response = await client.functions.invoke(
      'recommend-tasks',
      body: {
        'query': trimmedQuery,
        'tasks': candidates
            .map(
              (t) => {
                'id': t.id,
                'title': t.title,
                'status': t.status.name,
              },
            )
            .toList(),
      },
    );

    if (response.status != 200) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw RecommendException(data['error'].toString());
      }
      throw RecommendException('AI 推荐失败 (${response.status})');
    }

    final data = response.data;
    if (data is! Map) {
      throw RecommendException('AI 返回格式无效');
    }

    final rawIds = data['recommendedIds'];
    final playlistName = (data['playlistName'] as String?)?.trim();
    final summary = (data['summary'] as String?)?.trim();

    final allowedIds = {for (final t in candidates) t.id};
    final recommendedIds = <String>[];
    if (rawIds is List) {
      for (final id in rawIds) {
        final s = id.toString();
        if (allowedIds.contains(s) && !recommendedIds.contains(s)) {
          recommendedIds.add(s);
        }
      }
    }

    final byId = {for (final t in candidates) t.id: t};
    final recommendedTasks = [
      for (final id in recommendedIds)
        if (byId[id] != null) byId[id]!,
    ];

    return RecommendResult(
      recommendedTasks: recommendedTasks,
      suggestedPlaylistName:
          playlistName?.isNotEmpty == true ? playlistName! : '推荐清单',
      summary: summary,
    );
  }
}

class RecommendException implements Exception {
  RecommendException(this.message);
  final String message;

  @override
  String toString() => message;
}
