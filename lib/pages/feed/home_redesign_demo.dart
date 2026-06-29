import 'package:flutter/material.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/daily_quote_widget.dart';

class HomeRedesignDemo extends StatefulWidget {
  const HomeRedesignDemo({super.key});

  @override
  State<HomeRedesignDemo> createState() => _HomeRedesignDemoState();
}

class _HomeRedesignDemoState extends State<HomeRedesignDemo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    return Scaffold(
      backgroundColor: moe.pageBackground,
      appBar: AppBar(
        title: const Text('首页方案对比'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '方案A\n融合卡'),
            Tab(text: '方案B\n仪表盘'),
            Tab(text: '方案C\n横滑卡'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SchemeA(),
          _SchemeB(),
          _SchemeC(),
        ],
      ),
    );
  }
}

// ============================================================
// 方案 A：统一融合卡（推荐）
// 所有个人信息整合在一张渐变卡片中
// ============================================================
class _SchemeA extends StatelessWidget {
  const _SchemeA();

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildUnifiedCard(context, moe, scheme),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _buildCompactQuickActions(context, moe, scheme),
          ),
        ),
        SliverToBoxAdapter(child: _buildTopicRow(context, scheme)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              '热门动态',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildLightPostCard(context, scheme, index),
            childCount: 5,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildUnifiedCard(
      BuildContext context, MoeTheme moe, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white60, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_rounded,
                        color: Colors.white70, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '下午好 ☕',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '萌友',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildWeatherMini(scheme),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  color: Colors.white54,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: DailyQuoteWidget(
                    textColor: Colors.white,
                    embedded: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMini(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('☀️', style: TextStyle(fontSize: 16)),
          SizedBox(width: 4),
          Text(
            '26°',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuickActions(
      BuildContext context, MoeTheme moe, ColorScheme scheme) {
    final actions = [
      (icon: Icons.edit_note, label: '发动态', color: const Color(0xFF7F7FD5)),
      (icon: Icons.smart_toy, label: 'AI助手', color: const Color(0xFFFFB347)),
      (icon: Icons.forum_rounded, label: '社区', color: const Color(0xFF5B8DEF)),
      (icon: Icons.photo_library, label: '云相册', color: const Color(0xFF4ECDC4)),
      (icon: Icons.more_horiz_rounded, label: '更多', color: scheme.onSurfaceVariant),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {},
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: a.color.withValues(alpha: 0.22)),
                      ),
                      child: Icon(a.icon, color: a.color, size: 22),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopicRow(BuildContext context, ColorScheme scheme) {
    final tags = ['全部', '日常', '二次元', '游戏', '摄影', '美食', '旅行'];
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          final color = isSelected ? scheme.primary : scheme.onSurfaceVariant;
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.35)
                        : scheme.outline.withValues(alpha: 0.15)),
              ),
              child: Text(
                tags[index],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLightPostCard(
      BuildContext context, ColorScheme scheme, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  child:
                      Icon(Icons.person_rounded, color: scheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('用户昵称',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('2 小时前',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded,
                    color: scheme.onSurfaceVariant, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '这是一条动态内容示例~ 今天天气真好，和朋友们一起出去玩了！(｡•ᴗ•｡)',
              style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurface,
                  height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_border_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('12',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('3',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 方案 B：仪表盘错落布局
// 左侧大卡 + 右侧堆叠小卡，更有设计感
// ============================================================
class _SchemeB extends StatelessWidget {
  const _SchemeB();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildLeftCard(context, scheme)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _buildRightStack(context, scheme)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: _buildHorizontalActions(context, scheme),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              '热门动态',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _SchemeA()._buildLightPostCard(context, scheme, index),
            childCount: 5,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildLeftCard(BuildContext context, ColorScheme scheme) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white60, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_rounded,
                        color: Colors.white70, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('下午好 ☕',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      SizedBox(height: 1),
                      Text('萌友',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('☀️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    const Text('26°',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('北京',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('晴转多云 · 空气优',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightStack(BuildContext context, ColorScheme scheme) {
    return Column(
      children: [
        _buildQuoteCard(scheme),
        const SizedBox(height: 10),
        _buildPostButton(scheme),
      ],
    );
  }

  Widget _buildQuoteCard(ColorScheme scheme) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082).withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFFFB347), size: 16),
            const SizedBox(height: 4),
            const Expanded(
              child: DailyQuoteWidget(
                textColor: Color(0xFF5D4037),
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButton(ColorScheme scheme) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  '发动态',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalActions(
      BuildContext context, ColorScheme scheme) {
    final actions = [
      (icon: Icons.smart_toy, label: 'AI助手', color: const Color(0xFFFFB347)),
      (icon: Icons.forum_rounded, label: '社区', color: const Color(0xFF5B8DEF)),
      (icon: Icons.photo_library, label: '云相册', color: const Color(0xFF4ECDC4)),
      (icon: Icons.games, label: '游戏', color: const Color(0xFF95E1D3)),
      (icon: Icons.card_giftcard, label: '抽卡', color: const Color(0xFFF38181)),
      (icon: Icons.more_horiz_rounded, label: '更多', color: scheme.onSurfaceVariant),
    ];
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = actions[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(a.label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// 方案 C：横向卡片流
// 顶部可横滑的信息卡片区域
// ============================================================
class _SchemeC extends StatelessWidget {
  const _SchemeC();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildHorizontalCards(context, scheme),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: _SchemeA()._buildTopicRow(context, scheme),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              '热门动态',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _SchemeA()._buildLightPostCard(context, scheme, index),
            childCount: 5,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildHorizontalCards(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _buildUserCard(scheme);
          if (index == 1) return _buildQuoteCard(scheme);
          return _buildActionsCard(scheme);
        },
      ),
    );
  }

  Widget _buildUserCard(ColorScheme scheme) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white60, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('下午好 ☕',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      SizedBox(height: 2),
                      Text('萌友',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('☀️', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('26°',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    Text('北京 · 晴转多云',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(ColorScheme scheme) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE082).withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFFFFB347), size: 20),
                SizedBox(width: 6),
                Text('每日一文',
                    style: TextStyle(
                        color: Color(0xFF5D4037),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: DailyQuoteWidget(
                textColor: Color(0xFF5D4037),
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ColorScheme scheme) {
    final actions = [
      (icon: Icons.edit_note, label: '发动态', color: const Color(0xFF7F7FD5)),
      (icon: Icons.smart_toy, label: 'AI助手', color: const Color(0xFFFFB347)),
      (icon: Icons.forum_rounded, label: '社区', color: const Color(0xFF5B8DEF)),
      (icon: Icons.photo_library, label: '云相册', color: const Color(0xFF4ECDC4)),
    ];
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷功能',
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: actions.map((a) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(a.icon, color: a.color, size: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(a.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
