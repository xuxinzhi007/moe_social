import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/life_state.dart';
import '../../providers/life_provider.dart';
import '../../theme/moe_tokens.dart';

/// 背包道具页面。
class LifeInventoryPage extends StatefulWidget {
  const LifeInventoryPage({super.key});

  @override
  State<LifeInventoryPage> createState() => _LifeInventoryPageState();
}

class _LifeInventoryPageState extends State<LifeInventoryPage> {
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    // 进入时自动加载背包
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LifeProvider>().fetchInventory();
    });
  }

  Future<void> _claimDailyItems() async {
    if (_claiming) return;
    final provider = context.read<LifeProvider>();
    if (provider.claimedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('今日已签到领取过了，明天再来吧'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _claiming = true);
    final result = await provider.claimItems();
    if (!mounted) return;
    setState(() => _claiming = false);
    final ok = result != null && result.success;
    final msg = !ok
        ? (provider.lastActionError ?? '领取失败，请稍后重试')
        : result.alreadyClaimed
            ? '今日已签到领取过了'
            : result.count > 0
                ? '签到成功！获得 ${result.items.map((e) => e.displayIcon).join('')} ×${result.count}'
                : (result.message.isNotEmpty ? result.message : '签到成功');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? MoeTokens.success : MoeTokens.danger,
        duration: const Duration(seconds: 2),
      ),
    );
    provider.clearActionError();
  }

  void _showUseItemSheet(LifeInventoryItem invItem) {
    final provider = context.read<LifeProvider>();
    final entities =
        provider.entities.where((e) => e.action != 'dying').toList();

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
                // 拖动指示条
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 道具信息
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(invItem.displayIcon,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invItem.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: MoeTokens.titleText,
                              ),
                            ),
                            Text(
                              invItem.item?.description ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: MoeTokens.hintText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: invItem.item?.typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          invItem.item?.effectLabel ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: invItem.item?.typeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20, indent: 20, endIndent: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选择目标实体',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MoeTokens.bodyText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (entities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('暂无可用实体',
                        style: TextStyle(color: MoeTokens.hintText)),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entities.length,
                      itemBuilder: (ctx2, i) {
                        final entity = entities[i];
                        return ListTile(
                          leading: Text(entity.emoji,
                              style: const TextStyle(fontSize: 24)),
                          title: Text(entity.name),
                          subtitle: Text(
                            '${entity.actionLabel} · ${entity.growthStageLabel}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmUseItem(invItem, entity);
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

  Future<void> _confirmUseItem(
      LifeInventoryItem invItem, LifeEntity entity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('使用 ${invItem.displayName}？'),
        content:
            Text('对 ${entity.emoji} ${entity.name} 使用 ${invItem.displayName}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MoeTokens.primary),
            child: const Text('确认使用'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    final provider = context.read<LifeProvider>();
    final ok = await provider.useItem(entity.id, invItem.itemId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '✨ ${invItem.displayName} 使用成功！'
            : provider.lastActionError ?? '使用失败'),
        backgroundColor: ok ? MoeTokens.success : MoeTokens.danger,
        duration: const Duration(seconds: 2),
      ),
    );
    provider.clearActionError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('我的背包'),
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        foregroundColor: MoeTokens.titleText,
      ),
      body: Consumer<LifeProvider>(
        builder: (context, provider, _) {
          final items =
              provider.inventory.where((i) => i.quantity > 0).toList();

          return Column(
            children: [
              // 顶部签到领取按钮
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Builder(
                  builder: (context) {
                    final claimed = provider.claimedToday;
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: claimed ? null : MoeTokens.primaryGradient,
                        color: claimed ? const Color(0xFFE8E4F0) : null,
                        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                        boxShadow: claimed ? null : MoeTokens.shadowButton(),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusLg),
                          onTap:
                              (_claiming || claimed) ? null : _claimDailyItems,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: _claiming
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
                                      Text(
                                        claimed ? '✅' : '🎁',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        claimed ? '今日已签到 · 明天再来' : '签到领取每日道具',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: claimed
                                              ? const Color(0xFF7A6F8A)
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!provider.claimedToday)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    '每天可领一次：食物 / 药剂 / 玩具各 1 份，记入你的账号背包。',
                    style: TextStyle(
                      fontSize: 12,
                      color: MoeTokens.hintText,
                      height: 1.35,
                    ),
                  ),
                ),
              // 加载指示
              if (provider.inventoryLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              // 空背包状态
              else if (items.isEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: MoeTokens.primary.withValues(alpha: 0.10),
                          ),
                          boxShadow: MoeTokens.shadowSm(),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(
                                color:
                                    MoeTokens.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.backpack_outlined,
                                  size: 38, color: MoeTokens.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '还没有可用道具',
                              style: TextStyle(
                                fontSize: 18,
                                color: MoeTokens.titleText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.claimedToday
                                  ? '今日补给已领过。去世界里对居民使用道具吧。'
                                  : '点上方「签到领取每日道具」领取今日补给。',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: MoeTokens.hintText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              // 道具网格
              else
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _ItemGridCell(
                        item: items[index],
                        onTap: () => _showUseItemSheet(items[index]),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 单个道具格子。
class _ItemGridCell extends StatelessWidget {
  final LifeInventoryItem item;
  final VoidCallback onTap;

  const _ItemGridCell({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeColor = item.item?.typeColor ?? MoeTokens.primary;
    return GestureDetector(
      onTap: item.quantity > 0 ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          boxShadow: MoeTokens.shadowSm(),
          border: Border.all(color: typeColor.withValues(alpha: 0.15)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 主体内容
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 道具图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      item.displayIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 道具名称
                  Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MoeTokens.titleText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  // 类型标签
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.item?.typeLabel ?? '',
                      style: TextStyle(fontSize: 9, color: typeColor),
                    ),
                  ),
                ],
              ),
            ),
            // 右上角数量角标
            if (item.quantity > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: MoeTokens.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MoeTokens.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
