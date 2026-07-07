import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';

/// Entity 详情页 — 展示单个实体的属性和最近事件。
class LifeEntityDetailPage extends StatefulWidget {
  final LifeEntity entity;

  const LifeEntityDetailPage({super.key, required this.entity});

  @override
  State<LifeEntityDetailPage> createState() => _LifeEntityDetailPageState();
}

class _LifeEntityDetailPageState extends State<LifeEntityDetailPage> {
  bool _isActing = false;

  Future<void> _doAction(String action) async {
    if (_isActing) return;
    final provider = context.read<LifeProvider>();
    setState(() => _isActing = true);
    try {
      final success = await provider.performAction(action, widget.entity.id);
      if (!mounted) return;
      if (success) {
        final msg = action == 'feed'
            ? '喂食成功！${widget.entity.emoji} 很开心'
            : '抚摸成功！${widget.entity.emoji} 心情变好了';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: MoeTokens.success,
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (provider.lastActionError != null) {
        final isCooldown = provider.lastActionIsCooldown;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (isCooldown) ...[Icon(Icons.timer_outlined, size: 18, color: Colors.white), const SizedBox(width: 6)],
                Expanded(child: Text(provider.lastActionError!)),
              ],
            ),
            backgroundColor: isCooldown ? MoeTokens.warning : MoeTokens.danger,
            duration: const Duration(seconds: 2),
          ),
        );
        provider.clearActionError();
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lifeProvider = context.watch<LifeProvider>();
    // 从 provider 获取最新状态
    final currentEntity = lifeProvider.entities
            .where((e) => e.id == widget.entity.id)
            .firstOrNull ??
        widget.entity;
    final entityEvents = lifeProvider.recentEvents
        .where((e) => e.entityId == widget.entity.id)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: Text('${currentEntity.emoji} ${currentEntity.name}'),
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        foregroundColor: MoeTokens.titleText,
      ),
      body: Column(
        children: [
          // 可滚动内容区
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 大号 emoji 头像
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: MoeTokens.cardBackground,
                      shape: BoxShape.circle,
                      boxShadow: MoeTokens.shadowMd(),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      currentEntity.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 名称
                  Text(
                    currentEntity.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 成长阶段标签 + 年龄
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentEntity.growthStageColor
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentEntity.growthStageColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          currentEntity.growthStageLabel,
                          style: TextStyle(
                            color: currentEntity.growthStageColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '🕐 ${currentEntity.ageInDays}天',
                        style: const TextStyle(
                          fontSize: 13,
                          color: MoeTokens.hintText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 行为状态标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          MoeTokens.primary.withValues(alpha: 0.15),
                          MoeTokens.secondary.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentEntity.actionLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 三个属性进度条
                  _StatBar(
                    label: '饥饿度',
                    value: currentEntity.hunger,
                    color: Colors.orange,
                    icon: Icons.restaurant,
                  ),
                  const SizedBox(height: 12),
                  _StatBar(
                    label: '精力值',
                    value: currentEntity.energy,
                    color: Colors.blue,
                    icon: Icons.bolt,
                  ),
                  const SizedBox(height: 12),
                  _StatBar(
                    label: '心情值',
                    value: currentEntity.mood,
                    color: Colors.pink,
                    icon: Icons.favorite,
                  ),
                  // 成长进度条（仅非老年阶段显示）
                  if (currentEntity.experienceThreshold > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: MoeTokens.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: MoeTokens.shadowSm(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 18,
                                  color: currentEntity.growthStageColor),
                              const SizedBox(width: 8),
                              const Text(
                                '成长进度',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: MoeTokens.bodyText,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${currentEntity.experience.toInt()} / ${currentEntity.experienceThreshold.toInt()} EXP',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: currentEntity.growthStageColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: currentEntity.growthProgress,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                  currentEntity.growthStageColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 位置坐标
                  Container(
                    padding: const EdgeInsets.all(14),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: MoeTokens.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: MoeTokens.shadowSm(),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 20, color: MoeTokens.primary),
                        const SizedBox(width: 8),
                        Text(
                          '坐标: (${currentEntity.x.toInt()}, ${currentEntity.y.toInt()})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: MoeTokens.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 该 entity 的最近事件
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '最近事件',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.titleText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (entityEvents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: MoeTokens.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '暂无事件记录',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...entityEvents.map((event) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: MoeTokens.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.circle,
                                  size: 6,
                                  color: MoeTokens.primary
                                      .withValues(alpha: 0.5)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.desc,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: MoeTokens.bodyText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimestamp(event.timestamp),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  // 底部留空，避免被操作栏遮挡
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // 底部操作按钮栏
          _BottomActionBar(
            isActing: _isActing,
            onFeed: () => _doAction('feed'),
            onPet: () => _doAction('pet'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// 底部操作按钮栏。
class _BottomActionBar extends StatelessWidget {
  final bool isActing;
  final VoidCallback onFeed;
  final VoidCallback onPet;

  const _BottomActionBar({
    required this.isActing,
    required this.onFeed,
    required this.onPet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: '喂食',
              icon: Icons.restaurant_menu,
              emoji: '🍖',
              color: Colors.orange,
              isActing: isActing,
              onTap: onFeed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: '抚摸',
              icon: Icons.front_hand,
              emoji: '🤚',
              color: Colors.pink,
              isActing: isActing,
              onTap: onPet,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个操作按钮。
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String emoji;
  final Color color;
  final bool isActing;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.isActing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
        onTap: isActing ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isActing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MoeTokens.bodyText,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '${value.toInt()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
