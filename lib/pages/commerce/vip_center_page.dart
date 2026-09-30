import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/commerce_service.dart';
import '../../models/vip_record.dart';
import 'vip_benefit_catalog.dart';
import 'vip_purchase_page.dart';
import 'order_center_page.dart';
import 'vip_history_page.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_menu_card.dart';

class VipCenterPage extends StatefulWidget {
  const VipCenterPage({super.key});

  @override
  State<VipCenterPage> createState() => _VipCenterPageState();
}

class _VipCenterPageState extends State<VipCenterPage> {
  MoeTheme get _moe => MoeTheme.of(context);

  Map<String, dynamic>? _vipStatus;
  VipRecord? _activeRecord;
  bool _isLoading = true;
  bool _autoRenew = false;

  @override
  void initState() {
    super.initState();
    _loadVipInfo();
  }

  Future<void> _loadVipInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _vipStatus = null;
          _activeRecord = null;
          _autoRenew = false;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vipStatus = await CommerceService.getUserVipStatus(userId);

      VipRecord? activeRecord;
      try {
        activeRecord = await CommerceService.getUserActiveVipRecord(userId);
      } catch (e) {
        debugPrint('获取活跃VIP记录失败: $e');
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _vipStatus = vipStatus;
        _activeRecord = activeRecord;
        _autoRenew = vipStatus['auto_renew'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        MoeToast.error(context, '加载VIP信息失败，请稍后重试');
      }
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    setState(() {
      _autoRenew = value;
    });

    try {
      await CommerceService.updateAutoRenew(userId, value);
      if (mounted) {
        MoeToast.success(context, value ? '已开启自动续费' : '已关闭自动续费');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _autoRenew = !value;
        });
      }
      if (mounted) {
        MoeToast.error(context, '操作失败，请稍后重试');
      }
    }
  }

  Future<void> _openPurchase() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VipPurchasePage()),
    );
    if (result == true) {
      await _loadVipInfo();
      if (mounted) {
        MoeToast.success(context, '会员状态已更新');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.currentUser != null;
    return AdaptivePageScaffold(
      title: '会员中心',
      padding: EdgeInsets.zero,
      body: !isLoggedIn
          ? _buildGuestView()
          : _isLoading
              ? _buildLoadingSkeleton()
              : RefreshIndicator(
                  onRefresh: _loadVipInfo,
                  color: _moe.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      MoeTokens.spaceLg,
                      MoeTokens.spaceLg,
                      MoeTokens.spaceLg,
                      MoeTokens.space4xl,
                    ),
                    child: Column(
                      children: [
                        MoeReveal(child: _buildVipStatusCard()),
                        const SizedBox(height: MoeTokens.spaceLg),
                        const MoeReveal(
                          delay: Duration(milliseconds: 80),
                          child: VipBenefitPanel(),
                        ),
                        if (_activeRecord != null) ...[
                          const SizedBox(height: MoeTokens.spaceLg),
                          MoeReveal(
                            delay: const Duration(milliseconds: 140),
                            child: _buildActiveRecordCard(),
                          ),
                        ],
                        const SizedBox(height: MoeTokens.spaceLg),
                        MoeReveal(
                          delay: const Duration(milliseconds: 180),
                          child: MoeMenuCard(
                            items: [
                              MoeMenuItem(
                                icon: Icons.receipt_long_outlined,
                                title: '订单中心',
                                subtitle: '礼物、会员订单和钱包流水',
                                color: MoeTokens.pastelBlue,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const OrderCenterPage(),
                                    ),
                                  );
                                },
                              ),
                              MoeMenuItem(
                                icon: Icons.history_rounded,
                                title: '开通记录',
                                subtitle: '查看历史生效记录',
                                color: MoeTokens.primary,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const VipHistoryPage(),
                                    ),
                                  );
                                },
                              ),
                              MoeMenuItem(
                                icon: Icons.diamond_outlined,
                                title: '购买 / 续费',
                                subtitle: '选择时长，用钱包余额开通',
                                color: MoeTokens.pastelOrange,
                                onTap: _openPurchase,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MoeTokens.space2xl),
        child: MoeReveal(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MoeTokens.spaceXl),
            decoration: BoxDecoration(
              color: MoeTokens.cardBackground,
              borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
              border: Border.all(color: MoeTokens.surfaceBorder),
              boxShadow: MoeTokens.shadowSm(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _moe.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 20,
                    color: _moe.primary,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                const Text(
                  '登录后查看会员',
                  style: TextStyle(
                    fontSize: MoeTokens.textLg,
                    fontWeight: MoeTokens.fontWeightTitle,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceSm),
                Text(
                  '可以看权益、套餐、订单和续费状态。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MoeTokens.hintText,
                    fontSize: MoeTokens.textBase,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceLg),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/login');
                      if (mounted) {
                        _loadVipInfo();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _moe.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusButton),
                      ),
                    ),
                    child: const Text('去登录'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVipStatusCard() {
    final isVip = _vipStatus?['is_vip'] as bool? ?? false;
    final expiresAt =
        formatVipExpiryLabel(_vipStatus?['expires_at'] as String?);
    final accent = isVip ? MoeTokens.pastelOrange : _moe.primary;

    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVip
                      ? Icons.workspace_premium_rounded
                      : Icons.star_border_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: MoeTokens.spaceMd),
              Expanded(
                child: Text(
                  isVip ? '会员已开通' : '还不是会员',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MoeTokens.titleText,
                    fontSize: MoeTokens.textLg,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
              ),
              const SizedBox(width: MoeTokens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: Text(
                  isVip ? '生效中' : '未开通',
                  style: TextStyle(
                    color: accent,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                    fontSize: MoeTokens.textXs,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          Text(
            isVip ? '有效至 $expiresAt' : '开通后签到经验和私信留存会立刻变化',
            style: const TextStyle(
              color: MoeTokens.hintText,
              fontSize: MoeTokens.textSm,
              height: 1.4,
            ),
          ),
          if (isVip) ...[
            const SizedBox(height: MoeTokens.spaceXs),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '到期后用钱包余额续期',
                    style: TextStyle(
                      fontSize: MoeTokens.textXs,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ),
                const Text(
                  '自动续费',
                  style: TextStyle(
                    fontSize: MoeTokens.textXs,
                    color: MoeTokens.inkMuted,
                  ),
                ),
                const SizedBox(width: MoeTokens.spaceXs),
                SizedBox(
                  width: 36,
                  height: 22,
                  child: FittedBox(
                    child: Switch.adaptive(
                      value: _autoRenew,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeThumbColor: _moe.primary,
                      activeTrackColor: _moe.primary.withValues(alpha: 0.45),
                      onChanged: _toggleAutoRenew,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveRecordCard() {
    final record = _activeRecord!;
    return Container(
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MoeTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前套餐',
              style: TextStyle(
                fontSize: MoeTokens.textBase,
                fontWeight: MoeTokens.fontWeightTitle,
                color: MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
            _buildInfoRow('套餐', record.planName),
            const SizedBox(height: MoeTokens.spaceSm),
            _buildInfoRow('开始',
                _formatRecordDate(record.startAtDateTime, record.startAt)),
            const SizedBox(height: MoeTokens.spaceSm),
            _buildInfoRow(
                '结束', _formatRecordDate(record.endAtDateTime, record.endAt)),
          ],
        ),
      ),
    );
  }

  String _formatRecordDate(DateTime? date, String fallback) {
    if (date == null) {
      return formatVipExpiryLabel(fallback);
    }
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                color: MoeTokens.hintText, fontSize: MoeTokens.textBase),
          ),
        ),
        SizedBox(width: MoeTokens.spaceLg),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: MoeTokens.fontWeightSubtitle,
                fontSize: MoeTokens.textBase,
                color: MoeTokens.titleText),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      child: Column(
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: MoeTokens.cardBackground,
              borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
              border: Border.all(color: MoeTokens.surfaceBorder),
            ),
          ),
          const SizedBox(height: MoeTokens.spaceLg),
          Container(
            height: 148,
            decoration: BoxDecoration(
              color: MoeTokens.cardBackground,
              borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
              border: Border.all(color: MoeTokens.surfaceBorder),
            ),
          ),
        ],
      ),
    );
  }
}
