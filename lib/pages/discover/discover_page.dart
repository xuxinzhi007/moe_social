import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth_service.dart';
import '../../models/topic_tag.dart';
import '../../services/api_service.dart';
import '../../services/chat_push_service.dart';
import '../../services/match_suggestion_service.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../ai/agent_list_page.dart';
import '../game/game_lobby_page.dart';
import '../notifications/notification_center_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedTagIds = {};
  List<MatchCandidate> _candidates = [];
  bool _loading = false;
  bool _hasSearched = false;

  // Online match
  StreamSubscription<Map<String, dynamic>>? _matchSub;
  bool _onlineMatching = false;
  String? _onlineMatchHint;

  // Pulse animation for online match button
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _matchSub = ChatPushService.matchEventsStream.listen(_onMatchEvent);
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    if (_onlineMatching) ChatPushService.sendMatchCancel();
    _pulseCtrl.dispose();
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
      setState(() { _onlineMatching = false; _onlineMatchHint = null; });
      _pulseCtrl.stop();
      return;
    }
    if (t == 'match_found') {
      final peer = e['peer_id']?.toString();
      setState(() { _onlineMatching = false; _onlineMatchHint = null; });
      _pulseCtrl.stop();
      if (peer != null && peer.isNotEmpty) _openDirectChatWith(peer);
    }
  }

  Future<void> _openDirectChatWith(String peerId) async {
    try {
      final u = await ApiService.getUserInfo(peerId);
      if (!mounted) return;
      await Navigator.pushNamed(context, '/direct-chat', arguments: {
        'userId': u.id, 'username': u.username, 'avatar': u.avatar,
      });
    } catch (_) {
      if (mounted) MoeToast.error(context, '无法打开聊天，请稍后重试');
    }
  }

  Future<void> _toggleOnlineMatch() async {
    if (!AuthService.isLoggedIn) { MoeToast.error(context, '请先登录后再试'); return; }
    HapticFeedback.heavyImpact();
    if (_onlineMatching) {
      ChatPushService.sendMatchCancel();
      setState(() { _onlineMatching = false; _onlineMatchHint = null; });
      _pulseCtrl.stop();
      return;
    }
    ChatPushService.start();
    setState(() { _onlineMatching = true; _onlineMatchHint = '正在连接匹配…'; });
    _pulseCtrl.repeat(reverse: true);
    ChatPushService.sendMatchJoin();
  }

  Future<void> _runOfflineMatch() async {
    if (!AuthService.isLoggedIn) { MoeToast.error(context, '请先登录后再试'); return; }
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _hasSearched = true; });
    try {
      final list = await MatchSuggestionService.suggest(
        preferredTagIds: _selectedTagIds, maxResults: 24);
      if (!mounted) return;
      setState(() { _candidates = list; _loading = false; });
      if (list.isEmpty) { MoeToast.error(context, '暂时没有合适推荐，换个标签或稍后再试'); }
    } catch (_) {
      if (!mounted) return;
      setState(() { _candidates = []; _loading = false; });
      MoeToast.error(context, '加载失败，请检查网络');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildAppBar(),
          _buildHeroSection(),
          _buildTopicsSection(),
          _buildMatchButton(),
          _buildResultsSection(),
          _buildOtherTools(),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true, snap: true,
      backgroundColor: const Color(0xFFF5F7FA),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text('发现',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationCenterPage())),
        ),
      ],
    );
  }

  // ─── Hero: online match CTA ───────────────────────────────────────────────

  Widget _buildHeroSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _onlineMatching ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: GestureDetector(
            onTap: _toggleOnlineMatch,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _onlineMatching
                      ? [const Color(0xFFFC6076), const Color(0xFFFF9A44)]
                      : [const Color(0xFF7F7FD5), const Color(0xFF86A8E7)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (_onlineMatching
                        ? const Color(0xFFFC6076)
                        : const Color(0xFF7F7FD5)).withValues(alpha: 0.4),
                    blurRadius: 24, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background decoration circles
                  Positioned(top: -30, right: -20,
                    child: Container(width: 120, height: 120,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
                  Positioned(bottom: -40, left: 20,
                    child: Container(width: 160, height: 160,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                              child: Icon(
                                _onlineMatching ? Icons.wifi_rounded : Icons.favorite_rounded,
                                color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _onlineMatching ? '匹配中…' : '在线实时匹配',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  _onlineMatchHint ?? (_onlineMatching ? '请保持在此页等待' : '与另一位用户实时配对，开始私聊'),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_onlineMatching ? Icons.close_rounded : Icons.bolt_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _onlineMatching ? '取消排队' : '立即加入',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            if (_onlineMatching) ...[
                              const SizedBox(width: 12),
                              const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Topics ───────────────────────────────────────────────────────────────

  Widget _buildTopicsSection() {
    final tags = TopicTag.officialTags;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('选择感兴趣的话题',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                const Spacer(),
                if (_selectedTagIds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedTagIds.clear()),
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), foregroundColor: Colors.grey),
                    child: const Text('清除', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _selectedTagIds.isEmpty
                  ? '不选也没关系，会从站内随机推荐新面孔'
                  : '已选 ${_selectedTagIds.length} 个话题，将从相关动态作者中推荐',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: tags.map((tag) {
                final sel = _selectedTagIds.contains(tag.id);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (sel) { _selectedTagIds.remove(tag.id); }
                      else { _selectedTagIds.add(tag.id); }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: sel ? LinearGradient(colors: [tag.color, tag.color.withValues(alpha: 0.7)]) : null,
                      color: sel ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? tag.color : Colors.grey.shade200),
                      boxShadow: sel ? [BoxShadow(color: tag.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sel) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check_rounded, color: Colors.white, size: 13)),
                      Text('#${tag.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF333333))),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Offline match button ─────────────────────────────────────────────────

  Widget _buildMatchButton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: FilledButton.icon(
          onPressed: _loading ? null : _runOfflineMatch,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7F7FD5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome_rounded, size: 20),
          label: Text(
            _loading ? '推荐中…' : (_selectedTagIds.isEmpty ? '随机发现新面孔' : '根据话题推荐同好'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  // ─── Results grid ─────────────────────────────────────────────────────────

  Widget _buildResultsSection() {
    if (!_hasSearched) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _buildEmptyHint(),
        ),
      );
    }
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: MoeSmallLoading(size: 28)),
        ),
      );
    }
    if (_candidates.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('没有找到合适的同好', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Text('换几个话题再试试，或直接随机发现新朋友', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '找到 ${_candidates.length} 位可能感兴趣的人',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.75,
              ),
              itemCount: _candidates.length,
              itemBuilder: (_, i) => _MatchCandidateCard(candidate: _candidates[i]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint() {
    // Decorative scattered topic badges to fill space
    final tags = TopicTag.officialTags;
    final rng = math.Random(42);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(math.min(8, tags.length), (i) {
                final tag = tags[i];
                final angle = (i / tags.length) * 2 * math.pi;
                final r = 28.0 + rng.nextDouble() * 12;
                return Positioned(
                  left: 120 + r * math.cos(angle) * 1.6,
                  top: 30 + r * math.sin(angle) * 0.8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tag.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tag.color.withValues(alpha: 0.3)),
                    ),
                    child: Text('#${tag.name}', style: TextStyle(fontSize: 10, color: tag.color, fontWeight: FontWeight.w600)),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          const Text('选好话题，找到你的同好 ✨',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF333333))),
          const SizedBox(height: 6),
          Text('选几个感兴趣的标签，或直接点「随机发现新面孔」',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ─── Other tools ─────────────────────────────────────────────────────────

  Widget _buildOtherTools() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('其他功能', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallToolCard(
                    icon: Icons.smart_toy_rounded,
                    label: 'AI 助手',
                    gradient: const [Color(0xFF7F7FD5), Color(0xFF91EAE4)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentListPage())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SmallToolCard(
                    icon: Icons.sports_esports_rounded,
                    label: '小游戏',
                    gradient: const [Color(0xFF43C6AC), Color(0xFF191654)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLobbyPage())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MatchCandidateCard
// ─────────────────────────────────────────────────────────────────────────────

class _MatchCandidateCard extends StatelessWidget {
  final MatchCandidate candidate;

  const _MatchCandidateCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final tags = candidate.matchedTagNames.take(2).toList();
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/user-profile', arguments: {
        'userId': candidate.userId,
        'userName': candidate.username,
        'userAvatar': candidate.userAvatar,
        'heroTag': 'match_${candidate.userId}',
      }),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'match_${candidate.userId}',
                child: NetworkAvatarImage(imageUrl: candidate.userAvatar, radius: 26),
              ),
              const SizedBox(height: 8),
              Text(
                candidate.username,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3, runSpacing: 3,
                  children: tags.map((name) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F7FD5).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('#$name', style: const TextStyle(fontSize: 9, color: Color(0xFF7F7FD5), fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/direct-chat', arguments: {
                  'userId': candidate.userId,
                  'username': candidate.username,
                  'avatar': candidate.userAvatar,
                }),
                child: Container(
                  height: 28,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 11),
                        SizedBox(width: 3),
                        Text('打招呼', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SmallToolCard
// ─────────────────────────────────────────────────────────────────────────────

class _SmallToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _SmallToolCard({required this.icon, required this.label, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
