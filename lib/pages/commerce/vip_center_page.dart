import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';
import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/commerce_service.dart';
import '../../models/vip_record.dart';
import 'vip_purchase_page.dart';
import 'order_center_page.dart';
import 'vip_history_page.dart';
import '../../widgets/motion/moe_reveal.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_menu_card.dart'; // 引入通用菜单组件

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

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.currentUser != null;

    return Scaffold(
      backgroundColor: _moe.pageBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('会员中心',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !isLoggedIn
          ? _buildGuestView()
          : _isLoading
              ? _buildLoadingSkeleton()
              : Stack(
                  children: [
                    // 顶部背景 - 统一 Moe 风格渐变
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_moe.primary, MoeTokens.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(MoeTokens.space3xl),
                          bottomRight: Radius.circular(MoeTokens.space3xl),
                        ),
                      ),
                    ),

                    RefreshIndicator(
                      onRefresh: _loadVipInfo,
                      color: _moe.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 60),
                        child: Column(
                          children: [
                            // VIP状态卡片
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: MoeTokens.spaceLg),
                              child: MoeReveal(
                                child: _buildVipStatusCard(),
                              ),
                            ),

                            SizedBox(height: MoeTokens.space2xl),

                            // 活跃 VIP记录信息
                            if (_activeRecord != null)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: MoeTokens.spaceLg),
                                child: MoeReveal(
                                  delay: const Duration(milliseconds: 100),
                                  child: _buildActiveRecordCard(),
                                ),
                              ),

                            SizedBox(height: MoeTokens.spaceLg),

                            // 功能菜单 - 使用 MoeMenuCard
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: MoeTokens.spaceLg),
                              child: MoeReveal(
                                delay: const Duration(milliseconds: 200),
                                child: MoeMenuCard(
                                  items: [
                                    MoeMenuItem(
                                      icon: Icons.receipt_long_outlined,
                                      title: '订单中心',
                                      subtitle: '礼物购买、VIP订单与钱包流水',
                                      color: Colors.blueAccent,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const OrderCenterPage()),
                                        );
                                      },
                                    ),
                                    MoeMenuItem(
                                      icon: Icons.history_rounded,
                                      title: '开通记录',
                                      subtitle: '查看历史生效记录',
                                      color: Colors.purpleAccent,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const VipHistoryPage()),
                                        );
                                      },
                                    ),
                                    MoeMenuItem(
                                      icon: Icons.diamond_outlined,
                                      title: '购买/续费 VIP',
                                      subtitle: '查看最新套餐优惠',
                                      color: Colors.orangeAccent,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const VipPurchasePage()),
                                        );
                                        if (result == true) {
                                          _loadVipInfo();
                                          if (context.mounted) {
                                            MoeToast.success(
                                                context, 'VIP 状态已更新');
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: MoeTokens.spaceLg),

                            // 自动续费设置 - 也可以封装进 MoeMenuCard，或者单独样式
                            if (_vipStatus != null &&
                                (_vipStatus!['is_vip'] as bool? ?? false))
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: MoeTokens.spaceLg),
                                child: MoeReveal(
                                  delay: const Duration(milliseconds: 300),
                                  child: _buildAutoRenewCard(),
                                ),
                              ),

                            SizedBox(height: MoeTokens.space4xl),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGuestView() {
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_moe.primary, MoeTokens.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(MoeTokens.space3xl),
              bottomRight: Radius.circular(MoeTokens.space3xl),
            ),
          ),
        ),
        Center(
          child: MoeReveal(
            child: Padding(
              padding: EdgeInsets.all(MoeTokens.space2xl),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(MoeTokens.space2xl),
                decoration: BoxDecoration(
                  color: MoeTokens.cardBackground,
                  borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
                  boxShadow: MoeTokens.shadowMd(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(MoeTokens.spaceMd + MoeTokens.spaceXs),
                      decoration: BoxDecoration(
                        color: _moe.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: 36,
                        color: _moe.primary,
                      ),
                    ),
                    SizedBox(height: MoeTokens.spaceLg),
                    const Text(
                      '登录后查看 VIP 会员中心',
                      style: TextStyle(
                        fontSize: MoeTokens.textXl,
                        fontWeight: MoeTokens.fontWeightTitle,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    SizedBox(height: MoeTokens.spaceSm),
                    Text(
                      '登录后可查看会员权益、套餐价格、订单记录和续费状态。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MoeTokens.hintText,
                        fontSize: MoeTokens.textBase,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: MoeTokens.spaceXl),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
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
        ),
      ],
    );
  }

  Widget _buildVipStatusCard() {
    final isVip = _vipStatus?['is_vip'] as bool? ?? false;
    final expiresAt = _vipStatus?['expires_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(MoeTokens.space2xl),
      decoration: BoxDecoration(
        gradient: isVip
            ? const LinearGradient(
                colors: [Color(0xFFFFD66B), Color(0xFFFFA94D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.7)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        boxShadow: [
          BoxShadow(
            color: (isVip ? MoeTokens.pastelOrange : _moe.primary)
                .withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isVip
              ? Colors.white.withValues(alpha: 0.5)
              : _moe.primary.withValues(alpha: 0.1),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isVip
                      ? Colors.white.withValues(alpha: 0.25)
                      : _moe.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: isVip
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.32),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isVip
                      ? Icons.workspace_premium_rounded
                      : Icons.star_border_rounded,
                  color: isVip ? Colors.white : _moe.primary,
                  size: 32,
                ),
              ),
              SizedBox(width: MoeTokens.spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVip ? '尊贵VIP会员' : '普通用户',
                      style: TextStyle(
                        color: isVip ? Colors.white : MoeTokens.titleText,
                        fontSize: MoeTokens.text2xl,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: MoeTokens.spaceXs),
                    Text(
                      isVip ? '有效期至: ${expiresAt ?? "未知"}' : '开通VIP，解锁更多特权',
                      style: TextStyle(
                        color: isVip
                            ? Colors.white.withValues(alpha: 0.9)
                            : MoeTokens.hintText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isVip
                      ? Colors.white.withValues(alpha: 0.2)
                      : _moe.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                  border: Border.all(
                    color: isVip
                        ? Colors.white.withValues(alpha: 0.45)
                        : _moe.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVip ? Icons.bolt_rounded : Icons.lock_outline_rounded,
                      color: isVip ? Colors.white : _moe.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVip ? '已激活' : '未开通',
                      style: TextStyle(
                        color: isVip ? Colors.white : const Color(0xFF5E5F86),
                        fontWeight: FontWeight.w700,
                        fontSize: MoeTokens.textSm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: MoeTokens.spaceLg),
          Wrap(
            spacing: MoeTokens.spaceSm,
            runSpacing: MoeTokens.spaceSm,
            children: [
              _buildVipPerkChip(isVip, Icons.palette_rounded, '专属主题'),
              _buildVipPerkChip(isVip, Icons.hd_rounded, '高清画质'),
              _buildVipPerkChip(isVip, Icons.flash_on_rounded, '极速体验'),
            ],
          ),
          if (!isVip) ...[
            SizedBox(height: MoeTokens.space2xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const VipPurchasePage()),
                  );
                  if (result == true) {
                    _loadVipInfo();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _moe.primary, // 统一使用主色
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: _moe.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(MoeTokens.radiusButton)),
                ),
                child: const Text(
                  '立即开通',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: MoeTokens.spaceMd),
            Text(
              '开通后权益才会生效，请以支付结果为准',
              style: TextStyle(
                color: MoeTokens.hintText,
                fontSize: MoeTokens.textSm,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVipPerkChip(bool isVip, IconData icon, String label) {
    final bgColor = isVip
        ? Colors.white.withValues(alpha: 0.2)
        : _moe.primary.withValues(alpha: 0.08);
    final iconColor = isVip ? Colors.white : _moe.primary;
    final textColor = isVip ? Colors.white : const Color(0xFF5E5F86);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRecordCard() {
    final record = _activeRecord!;
    return Container(
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        boxShadow: MoeTokens.shadowMd(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MoeTokens.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _moe.primary),
                SizedBox(width: MoeTokens.spaceSm),
                const Text(
                  '当前套餐详情',
                  style: TextStyle(
                    fontSize: MoeTokens.textLg,
                    fontWeight: FontWeight.bold,
                    color: MoeTokens.titleText,
                  ),
                ),
              ],
            ),
            SizedBox(height: MoeTokens.spaceLg),
            _buildInfoRow('套餐名称', record.planName),
            Padding(
              padding: EdgeInsets.symmetric(vertical: MoeTokens.spaceSm),
              child: Divider(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            _buildInfoRow(
              '开始时间',
              record.startAtDateTime != null
                  ? '${record.startAtDateTime!.year}-${record.startAtDateTime!.month.toString().padLeft(2, '0')}-${record.startAtDateTime!.day.toString().padLeft(2, '0')}'
                  : record.startAt,
            ),
            SizedBox(height: MoeTokens.spaceSm),
            _buildInfoRow(
              '结束时间',
              record.endAtDateTime != null
                  ? '${record.endAtDateTime!.year}-${record.endAtDateTime!.month.toString().padLeft(2, '0')}-${record.endAtDateTime!.day.toString().padLeft(2, '0')}'
                  : record.endAt,
            ),
          ],
        ),
      ),
    );
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

  Widget _buildAutoRenewCard() {
    // 这里使用 MoeMenuCard 风格的单个项
    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: Icons.autorenew_rounded,
          title: '自动续费',
          subtitle: 'VIP 到期后自动使用钱包余额续期',
          color: Colors.green,
          onTap: () => _toggleAutoRenew(!_autoRenew),
          trailing: Switch.adaptive(
            value: _autoRenew,
            activeThumbColor: _moe.primary,
            activeTrackColor: _moe.primary.withValues(alpha: 0.5),
            onChanged: _toggleAutoRenew,
          ),
        ),
      ],
    );
  }

  /// 加载骨架屏
  Widget _buildLoadingSkeleton() {
    return Stack(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_moe.primary, MoeTokens.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(MoeTokens.space3xl),
              bottomRight: Radius.circular(MoeTokens.space3xl),
            ),
          ),
        ),
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
          child: Column(
            children: [
              // VIP 卡片骨架
              Padding(
                padding: EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
                  ),
                ),
              ),
              SizedBox(height: MoeTokens.space2xl),
              // 菜单骨架
              Padding(
                padding: EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: MoeTokens.cardBackground,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                    boxShadow: MoeTokens.shadowSm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
