import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../services/user_service.dart';
import '../../services/chat_push_service.dart';
import '../../services/match_suggestion_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../theme/moe_tokens.dart';

/// 探索页 · 同好：在线匹配、话题推荐与结果展示。
class DiscoverMatchTab extends StatefulWidget {
  const DiscoverMatchTab({super.key, this.compact = false});

  final bool compact;

  @override
  State<DiscoverMatchTab> createState() => _DiscoverMatchTabState();
}

class _DiscoverMatchTabState extends State<DiscoverMatchTab>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedTagIds = {};
  List<MatchCandidate> _candidates = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _matchErrorMessage;
  DateTime? _lastOfflineMatchAt;
  static const Duration _offlineMatchThrottle = Duration(milliseconds: 800);

  StreamSubscription<Map<String, dynamic>>? _matchSub;
  bool _onlineMatching = false;
  String? _onlineMatchHint;

  AnimationController? _pulseCtrl;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    _matchSub = ChatPushService.matchEventsStream.listen(_onMatchEvent);
    _initPulseAnimation();
  }

  void _initPulseAnimation() {
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    if (_onlineMatching) ChatPushService.sendMatchCancel();
    _pulseCtrl?.dispose();
    super.dispose();
  }

  bool get _animationsEnabled {
    return MediaQuery.maybeOf(context)?.disableAnimations != true;
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
      _pulseCtrl?.stop();
      return;
    }
    if (t == 'match_found') {
      final peer = e['peer_id']?.toString();
      setState(() {
        _onlineMatching = false;
        _onlineMatchHint = null;
      });
      _pulseCtrl?.stop();
      if (peer != null && peer.isNotEmpty) _openDirectChatWith(peer);
    }
  }

  Future<void> _toggleTopicTag(String tagId) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
    if (_hasSearched && !_loading) {
      await _runOfflineMatch();
    }
  }

  Future<void> _openDirectChatWith(String peerId) async {
    try {
      final u = await UserService.getUserInfo(peerId);
      if (!mounted) return;
      await Navigator.pushNamed(context, '/direct-chat', arguments: {
        'userId': u.id,
        'username': u.username,
        'avatar': u.avatar,
      });
    } catch (_) {
      if (mounted) MoeToast.error(context, '无法打开聊天，请稍后重试');
    }
  }

  Future<void> _toggleOnlineMatch() async {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录后再试');
      return;
    }
    HapticFeedback.heavyImpact();
    if (_onlineMatching) {
      ChatPushService.sendMatchCancel();
      setState(() {
        _onlineMatching = false;
        _onlineMatchHint = null;
      });
      _pulseCtrl?.stop();
      return;
    }
    ChatPushService.start();
    setState(() {
      _onlineMatching = true;
      _onlineMatchHint = '正在连接匹配…';
    });
    if (_animationsEnabled) {
      _pulseCtrl?.repeat(reverse: true);
    }
    ChatPushService.sendMatchJoin();
  }

  Future<void> _runOfflineMatch() async {
    if (!AuthService.isLoggedIn) {
      MoeToast.error(context, '请先登录后再试');
      return;
    }
    if (_loading) return;
    final now = DateTime.now();
    final lastTriggeredAt = _lastOfflineMatchAt;
    if (lastTriggeredAt != null &&
        now.difference(lastTriggeredAt) < _offlineMatchThrottle) {
      return;
    }
    _lastOfflineMatchAt = now;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _hasSearched = true;
      _matchErrorMessage = null;
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
        _matchErrorMessage = null;
      });
      if (list.isEmpty) {
        MoeToast.error(context, '暂时没有合适推荐，换个标签或稍后再试');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _candidates = [];
        _loading = false;
        _matchErrorMessage = '匹配加载失败，请检查网络后重试';
      });
      MoeToast.error(context, '加载失败，请检查网络');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: widget.compact
              ? _buildCompactOnlineMatch()
              : _buildOnlineMatchHero(),
        ),
        SliverToBoxAdapter(child: _buildTopicsSection()),
        SliverToBoxAdapter(child: _buildMatchButton()),
        _buildResultsSection(),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _buildCompactOnlineMatch() {
    final color =
        _onlineMatching ? const Color(0xFFFC6076) : AiBrandTokens.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: InkWell(
          onTap: _toggleOnlineMatch,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _onlineMatching
                        ? Icons.wifi_rounded
                        : Icons.favorite_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _onlineMatching ? '匹配中' : '在线实时匹配',
                        style: const TextStyle(
                          fontSize: MoeTokens.textLg,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.titleText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _onlineMatchHint ??
                            (_onlineMatching ? '请保持在此页等待' : '轻点加入，匹配后直接进入私聊'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  _onlineMatching
                      ? Icons.close_rounded
                      : Icons.arrow_forward_rounded,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineMatchHero() {
    final matchingGradient = const [
      Color(0xFFFC6076),
      Color(0xFFFF9A44),
    ];
    final idleGradient = [
      AiBrandTokens.primary,
      AiBrandTokens.secondary,
    ];

    Widget card = GestureDetector(
      onTap: _toggleOnlineMatch,
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _onlineMatching ? matchingGradient : idleGradient,
          ),
          borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
          boxShadow: [
            BoxShadow(
              color: (_onlineMatching
                      ? matchingGradient.first
                      : idleGradient.first)
                  .withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -24,
              right: -16,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _onlineMatching
                              ? Icons.wifi_rounded
                              : Icons.favorite_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _onlineMatching ? '匹配中…' : '在线实时匹配',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: MoeTokens.textLg,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _onlineMatchHint ??
                                  (_onlineMatching
                                      ? '请保持在此页等待'
                                      : '与另一位用户实时配对，开始私聊'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: MoeTokens.textSm,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusXl),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _onlineMatching
                                  ? Icons.close_rounded
                                  : Icons.bolt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _onlineMatching ? '取消排队' : '立即加入',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: MoeTokens.textBase,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_onlineMatching) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (_onlineMatching && _animationsEnabled && _pulseAnim != null) {
      card = AnimatedBuilder(
        animation: _pulseAnim!,
        builder: (_, child) => Transform.scale(
          scale: _pulseAnim!.value,
          child: child,
        ),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: card,
    );
  }

  Widget _buildTopicsSection() {
    final tags = TopicTag.officialTags;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 18 : 16,
        widget.compact ? 8 : 20,
        widget.compact ? 18 : 16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '按话题找同好',
                style: TextStyle(
                  fontSize: widget.compact ? 14 : 16,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
              const Spacer(),
              if (_selectedTagIds.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    setState(() => _selectedTagIds.clear());
                    if (_hasSearched && !_loading) {
                      await _runOfflineMatch();
                    }
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    foregroundColor: Colors.grey,
                  ),
                  child: const Text('清除',
                      style: TextStyle(fontSize: MoeTokens.textSm)),
                ),
            ],
          ),
          SizedBox(height: widget.compact ? 2 : 4),
          Text(
            _selectedTagIds.isEmpty
                ? '不选也可以，会从站内随机推荐新面孔'
                : '已选 ${_selectedTagIds.length} 个话题（已自动刷新推荐）',
            style: TextStyle(
                fontSize: MoeTokens.textSm, color: Colors.grey.shade500),
          ),
          SizedBox(height: widget.compact ? 9 : 12),
          Wrap(
            spacing: widget.compact ? 8 : 10,
            runSpacing: widget.compact ? 8 : 10,
            children: tags.map((tag) {
              final sel = _selectedTagIds.contains(tag.id);
              return ChoiceChip(
                label: Text(
                  tag.name,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : MoeTokens.titleText,
                  ),
                ),
                selected: sel,
                onSelected: (_) => _toggleTopicTag(tag.id),
                selectedColor: tag.color,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: sel ? tag.color : Colors.grey.shade200,
                ),
                pressElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 9 : 12,
                  vertical: widget.compact ? 5 : 8,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 18 : 16,
        widget.compact ? 12 : 16,
        widget.compact ? 18 : 16,
        0,
      ),
      child: FilledButton.icon(
        onPressed: _loading ? null : _runOfflineMatch,
        style: FilledButton.styleFrom(
          backgroundColor: AiBrandTokens.primary,
          minimumSize: Size(double.infinity, widget.compact ? 44 : 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text(
          _loading
              ? '推荐中…'
              : (_selectedTagIds.isEmpty ? '随机发现新面孔' : '根据话题推荐同好'),
          style: TextStyle(
            fontSize: widget.compact ? 14 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (!_hasSearched) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: MoeSmallLoading(size: 28)),
        ),
      );
    }
    if (_matchErrorMessage != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _buildFailureState(),
        ),
      );
    }
    if (_candidates.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _buildNoResultState(),
        ),
      );
    }
    // 通讯录式列表：与好友 Tab 同好行一致，点行打招呼、点头像看资料
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 18 : 16,
        16,
        widget.compact ? 18 : 16,
        8,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '找到 ${_candidates.length} 位可能感兴趣的人',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AiBrandTokens.titleColor,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MatchCandidateRow(candidate: _candidates[i - 1]),
            );
          },
          childCount: _candidates.length + 1,
        ),
      ),
    );
  }

  Widget _buildFailureState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE0DB)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9A44).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: Color(0xFFFF9A44), size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '这次推荐没有成功',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AiBrandTokens.titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _matchErrorMessage ?? '网络波动可能导致请求失败',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _runOfflineMatch,
                  style: FilledButton.styleFrom(
                    backgroundColor: AiBrandTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重试'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _matchErrorMessage = null;
                            _hasSearched = false;
                            _candidates = [];
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AiBrandTokens.primary,
                    side: const BorderSide(color: AiBrandTokens.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('重新选择'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '没有找到合适的同好',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AiBrandTokens.titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可以刷新一次，或试试在线实时匹配',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _runOfflineMatch,
                  style: FilledButton.styleFrom(
                    backgroundColor: AiBrandTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('刷新推荐'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _selectedTagIds.clear());
                          _runOfflineMatch();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AiBrandTokens.primary,
                    side: const BorderSide(color: AiBrandTokens.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: const Text('随机策略'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _onlineMatching ? null : _toggleOnlineMatch,
            style: TextButton.styleFrom(
              foregroundColor: AiBrandTokens.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: const Text('试试在线实时匹配'),
          ),
        ],
      ),
    );
  }
}

class _MatchCandidateRow extends StatelessWidget {
  const _MatchCandidateRow({required this.candidate});

  final MatchCandidate candidate;

  void _openProfile(BuildContext context) {
    Navigator.pushNamed(context, '/user-profile', arguments: {
      'userId': candidate.userId,
      'userName': candidate.username,
      'userAvatar': candidate.userAvatar,
      'heroTag': 'match_${candidate.userId}',
    });
  }

  void _openChat(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/direct-chat',
      arguments: {
        'userId': candidate.userId,
        'username': candidate.username,
        'avatar': candidate.userAvatar,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = candidate.matchedTagNames.take(2).toList();
    return Material(
      color: MoeTokens.cardBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openChat(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MoeTokens.surfaceBorder),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(context),
                child: Hero(
                  tag: 'match_${candidate.userId}',
                  child: NetworkAvatarImage(
                    imageUrl: candidate.userAvatar,
                    radius: 23,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MoeTokens.titleText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (tags.isNotEmpty)
                      Text(
                        tags.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MoeTokens.hintText,
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const Text(
                        '可能合得来的同好',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MoeTokens.hintText,
                          fontSize: MoeTokens.textSm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _openChat(context),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AiBrandTokens.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('打招呼'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
