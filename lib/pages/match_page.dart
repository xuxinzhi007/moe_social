import 'dart:async';

import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../models/topic_tag.dart';
import '../services/api_service.dart';
import '../services/chat_push_service.dart';
import '../services/match_suggestion_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/moe_toast.dart';

/// 按话题标签从动态流中找「可能同好」，并辅以用户列表兜底。
class MatchPage extends StatefulWidget {
  const MatchPage({super.key});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final Set<String> _selectedTagIds = {};
  List<MatchCandidate> _candidates = [];
  bool _loading = false;
  bool _hasSearched = false;

  StreamSubscription<Map<String, dynamic>>? _matchSub;
  bool _onlineMatching = false;
  String? _onlineMatchHint;

  @override
  void initState() {
    super.initState();
    _matchSub = ChatPushService.matchEventsStream.listen(_onMatchEvent);
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    if (_onlineMatching) {
      ChatPushService.sendMatchCancel();
    }
    super.dispose();
  }

  void _onMatchEvent(Map<String, dynamic> e) {
    if (!mounted) return;
    final t = e['type']?.toString();
    if (t == 'match_waiting') {
      setState(() => _onlineMatchHint = '排队中，请稍候…');
      return;
    }
    if (t == 'match_cancelled') {
      setState(() {
        _onlineMatching = false;
        _onlineMatchHint = null;
      });
      return;
    }
    if (t == 'match_found') {
      final peer = e['peer_id']?.toString();
      setState(() {
        _onlineMatching = false;
        _onlineMatchHint = null;
      });
      if (peer != null && peer.isNotEmpty) {
        _openDirectChatWith(peer);
      }
    }
  }

  Future<void> _openDirectChatWith(String peerId) async {
    try {
      final u = await ApiService.getUserInfo(peerId);
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/direct-chat',
        arguments: {
          'userId': u.id,
          'username': u.username,
          'avatar': u.avatar,
        },
      );
    } catch (_) {
      if (mounted) {
        MoeToast.error(context, '无法打开聊天，请稍后重试');
      }
    }
  }

  Future<void> _toggleOnlineMatch() async {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录后再试');
      return;
    }
    if (_onlineMatching) {
      ChatPushService.sendMatchCancel();
      setState(() {
        _onlineMatching = false;
        _onlineMatchHint = null;
      });
      return;
    }
    ChatPushService.start();
    setState(() {
      _onlineMatching = true;
      _onlineMatchHint = '正在连接匹配…';
    });
    ChatPushService.sendMatchJoin();
  }

  Future<void> _runMatch() async {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录后再试');
      return;
    }

    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    try {
      final list = await MatchSuggestionService.suggest(
        preferredTagIds: _selectedTagIds,
        maxResults: 24,
      );
      if (!mounted) return;
      setState(() {
        _candidates = list;
        _loading = false;
      });
      if (list.isEmpty) {
        MoeToast.error(context, '暂时没有合适推荐，换个标签或稍后再试');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _candidates = [];
        _loading = false;
      });
      MoeToast.error(context, '加载失败，请检查网络');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tags = TopicTag.officialTags;

    return Scaffold(
      appBar: AppBar(
        title: const Text('同好匹配'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '选几个你感兴趣的话题（可不选）。我们会从大家发的动态里找带这些标签的作者；'
              '没选标签时，会从站内用户里随机推荐一些你可能还不认识的人。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withOpacity(0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outline.withOpacity(0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '在线匹配',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '与另一位同时在线的用户实时配对，成功后进入私聊。请保持网络畅通并停留在本页等待。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    if (_onlineMatchHint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _onlineMatchHint!,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _toggleOnlineMatch,
                      icon: Icon(
                        _onlineMatching
                            ? Icons.close_rounded
                            : Icons.bolt_rounded,
                      ),
                      label: Text(
                        _onlineMatching ? '取消排队' : '开始在线匹配',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final selected = _selectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text('#${tag.name}'),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTagIds.add(tag.id);
                      } else {
                        _selectedTagIds.remove(tag.id);
                      }
                    });
                  },
                  selectedColor: tag.color.withOpacity(0.25),
                  checkmarkColor: tag.color,
                  side: BorderSide(
                    color: selected ? tag.color : scheme.outline.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton.icon(
              onPressed: _loading ? null : _runMatch,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? '匹配中…' : '开始匹配'),
            ),
          ),
          Expanded(
            child: _buildResultArea(context, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildResultArea(BuildContext context, ColorScheme scheme) {
    if (!_hasSearched && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '选好标签后点「开始匹配」，或留空直接随机看看新面孔～',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    if (_loading && _candidates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_candidates.isEmpty) {
      return Center(
        child: Text(
          '没有结果',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = _candidates[index];
        return Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/user-profile',
                arguments: {
                  'userId': c.userId,
                  'userName': c.username,
                  'userAvatar': c.userAvatar,
                  'heroTag': 'match_${c.userId}',
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outline.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  NetworkAvatarImage(
                    imageUrl: c.userAvatar,
                    radius: 26,
                    placeholderIcon: Icons.person_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.reason,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.outline),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
