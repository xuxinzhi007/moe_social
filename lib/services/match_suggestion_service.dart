import '../auth_service.dart';
import '../models/post.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'post_service.dart';

/// 轻量匹配结果（客户端根据动态话题与用户列表推算，无需专门匹配接口）。
class MatchCandidate {
  final String userId;
  final String username;
  final String userAvatar;
  final int score;
  final List<String> matchedTagNames;

  const MatchCandidate({
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.score,
    required this.matchedTagNames,
  });

  String get reason {
    if (matchedTagNames.isEmpty) {
      return '站内用户，随便逛逛也许能聊得来';
    }
    final names = matchedTagNames.toSet().toList()..sort();
    final show = names.take(4).join('、');
    return score > 1 ? '发过 $score 条相关动态 · $show' : '话题重合 · $show';
  }
}

class MatchSuggestionService {
  MatchSuggestionService._();

  /// [preferredTagIds] 为空时：从用户池随机推荐（排除自己及已关注）。
  /// 非空时：根据近期动态中是否带有这些标签给作者加分，再补足用户池。
  static Future<List<MatchCandidate>> suggest({
    required Set<String> preferredTagIds,
    int maxResults = 20,
  }) async {
    final myId = AuthService.currentUser;
    if (myId == null || myId.isEmpty) {
      return const [];
    }

    final excluded = <String>{myId};
    try {
      final follow = await ApiService.getFollowings(myId, page: 1, pageSize: 500);
      final list = (follow['followings'] as List<dynamic>).cast<User>();
      excluded.addAll(list.map((u) => u.id));
    } catch (_) {}

    final Map<String, _AuthorAgg> byAuthor = {};

    if (preferredTagIds.isNotEmpty) {
      try {
        final res = await PostService.getPosts(page: 1, pageSize: 80);
        final posts = res['posts'] as List<Post>;
        for (final p in posts) {
          if (excluded.contains(p.userId)) continue;
          final overlapNames = <String>{};
          var hit = false;
          for (final t in p.topicTags) {
            if (preferredTagIds.contains(t.id)) {
              hit = true;
              overlapNames.add(t.name);
            }
          }
          if (!hit) continue;
          byAuthor.putIfAbsent(
            p.userId,
            () => _AuthorAgg(
              username: p.userName,
              avatar: p.userAvatar,
            ),
          );
          final a = byAuthor[p.userId]!;
          a.score += 1;
          a.matchedNames.addAll(overlapNames);
        }
      } catch (_) {}
    }

    final candidates = <MatchCandidate>[];

    byAuthor.forEach((id, agg) {
      candidates.add(MatchCandidate(
        userId: id,
        username: agg.username,
        userAvatar: agg.avatar,
        score: agg.score,
        matchedTagNames: agg.matchedNames.toList(),
      ));
    });

    candidates.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.username.compareTo(b.username);
    });

    final seen = candidates.map((c) => c.userId).toSet();

    try {
      final res = await ApiService.getUsers(page: 1, pageSize: 40);
      final users = res['users'] as List<User>;
      final shuffled = List<User>.from(users)..shuffle();
      for (final u in shuffled) {
        if (excluded.contains(u.id) || seen.contains(u.id)) continue;
        candidates.add(MatchCandidate(
          userId: u.id,
          username: u.username,
          userAvatar: u.avatar,
          score: 0,
          matchedTagNames: const [],
        ));
        seen.add(u.id);
        if (candidates.length >= maxResults) break;
      }
    } catch (_) {}

    if (candidates.isEmpty) {
      return const [];
    }

    return candidates.take(maxResults).toList();
  }
}

class _AuthorAgg {
  _AuthorAgg({required this.username, required this.avatar});

  final String username;
  final String avatar;
  int score = 0;
  final Set<String> matchedNames = {};
}
