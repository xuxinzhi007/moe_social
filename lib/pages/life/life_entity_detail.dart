import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/life/life_event_tile.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

/// Entity 详情页 — 展示单个实体的属性和最近事件。
class LifeEntityDetailPage extends StatefulWidget {
  final LifeEntity entity;

  const LifeEntityDetailPage({super.key, required this.entity});

  @override
  State<LifeEntityDetailPage> createState() => _LifeEntityDetailPageState();
}

class _LifeEntityDetailPageState extends State<LifeEntityDetailPage> {
  bool _isActing = false;
  bool _isUsingItem = false;

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
        MoeToast.success(
          context,
          msg,
          duration: const Duration(seconds: 1),
        );
      } else if (provider.lastActionError != null) {
        final isCooldown = provider.lastActionIsCooldown;
        if (isCooldown) {
          MoeToast.warning(context, provider.lastActionError!);
        } else {
          MoeToast.error(context, provider.lastActionError!);
        }
        provider.clearActionError();
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  /// 显示道具选择 BottomSheet
  void _showItemSheet() async {
    final provider = context.read<LifeProvider>();
    // 确保背包已加载
    if (provider.inventory.isEmpty) {
      await provider.fetchInventory();
    }
    if (!mounted) return;

    final items = provider.inventory.where((i) => i.quantity > 0).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MoeTokens.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '📦 选择道具',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MoeTokens.titleText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      '背包空空如也~',
                      style: TextStyle(color: MoeTokens.hintText),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (ctx2, i) {
                        final inv = items[i];
                        final typeColor = inv.item?.typeColor ?? MoeTokens.primary;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(inv.displayIcon, style: const TextStyle(fontSize: 22)),
                          ),
                          title: Text(inv.displayName),
                          subtitle: Text(
                            inv.item?.effectLabel ?? '',
                            style: TextStyle(fontSize: 12, color: typeColor),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: MoeTokens.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '×${inv.quantity}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MoeTokens.primary,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _useItemOnEntity(inv);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _useItemOnEntity(LifeInventoryItem invItem) async {
    if (_isUsingItem) return;
    final provider = context.read<LifeProvider>();
    setState(() => _isUsingItem = true);
    try {
      final ok = await provider.useItem(widget.entity.id, invItem.itemId);
      if (!mounted) return;
      if (ok) {
        MoeToast.success(context, '✨ ${invItem.displayName} 使用成功！');
      } else if (provider.lastActionError != null) {
        MoeToast.error(context, provider.lastActionError!);
        provider.clearActionError();
      }
    } finally {
      if (mounted) setState(() => _isUsingItem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<LifeProvider, _EntityDetailData>(
      selector: (_, p) {
        final selected = p.entities
                .where((e) => e.id == widget.entity.id)
                .firstOrNull ??
            widget.entity;
        return _EntityDetailData(
          entity: selected,
          events: p.getEventsForEntity(widget.entity.id),
        );
      },
      builder: (context, data, _) {
        final currentEntity = data.entity;
        final entityEvents = data.events;

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
                    ...entityEvents.asMap().entries.map(
                          (entry) => LifeEventTile(
                            event: entry.value,
                            compact: true,
                            showTimeline: true,
                            isLast: entry.key == entityEvents.length - 1,
                          ),
                        ),
                  // 底部留空，避免被操作栏遮挡
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // 底部操作按钮栏
          SafeArea(
            top: false,
            child: _BottomActionBar(
              isActing: _isActing,
              isUsingItem: _isUsingItem,
              onFeed: () => _doAction('feed'),
              onPet: () => _doAction('pet'),
              onItem: _showItemSheet,
            ),
          ),
        ],
      ),
    );
      },
    );
  }


}

class _EntityDetailData {
  final LifeEntity entity;
  final List<LifeEvent> events;

  const _EntityDetailData({required this.entity, required this.events});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EntityDetailData &&
          entity.id == other.entity.id &&
          entity.hunger == other.entity.hunger &&
          entity.energy == other.entity.energy &&
          entity.mood == other.entity.mood &&
          entity.action == other.entity.action &&
          entity.x == other.entity.x &&
          entity.y == other.entity.y &&
          entity.experience == other.entity.experience &&
          entity.age == other.entity.age &&
          entity.growthStage == other.entity.growthStage &&
          _sameEvents(events, other.events);

  @override
  int get hashCode => Object.hash(
        entity.id,
        entity.hunger,
        entity.energy,
        entity.mood,
        entity.action,
        entity.x,
        entity.y,
        entity.experience,
        entity.age,
        entity.growthStage,
        events.length,
        events.isEmpty ? 0 : events.first.timestamp.millisecondsSinceEpoch,
      );
}

bool _sameEvents(List<LifeEvent> a, List<LifeEvent> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final left = a[i];
    final right = b[i];
    if (left.type != right.type ||
        left.desc != right.desc ||
        left.timestamp != right.timestamp) {
      return false;
    }
  }
  return true;
}

/// 底部操作按钮栏。
class _BottomActionBar extends StatelessWidget {
  final bool isActing;
  final bool isUsingItem;
  final VoidCallback onFeed;
  final VoidCallback onPet;
  final VoidCallback onItem;

  const _BottomActionBar({
    required this.isActing,
    required this.isUsingItem,
    required this.onFeed,
    required this.onPet,
    required this.onItem,
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
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: '道具',
              icon: Icons.inventory_2_outlined,
              emoji: '📦',
              color: MoeTokens.primary,
              isActing: isUsingItem,
              onTap: onItem,
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
                  child: MoeSmallLoading(
                    size: 20,
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
    final normalizedValue = (value / 100).clamp(0.0, 1.0);

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
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: normalizedValue,
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              builder: (context, animatedValue, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: animatedValue,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                );
              },
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
