import 'dart:async';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/vip_plan.dart';
import '../../services/achievement_hooks.dart';
import '../../services/api_client.dart' show ApiException;
import '../../services/commerce_service.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_reveal.dart';
import 'vip_benefit_catalog.dart';
import '../../widgets/moe_toast.dart';
import 'order_center_page.dart';
import 'recharge_page.dart';

class VipOrderConfirmPage extends StatefulWidget {
  const VipOrderConfirmPage({
    super.key,
    required this.plan,
    required this.initialBalance,
  });

  final VipPlan plan;
  final double initialBalance;

  @override
  State<VipOrderConfirmPage> createState() => _VipOrderConfirmPageState();
}

class _VipOrderConfirmPageState extends State<VipOrderConfirmPage> {
  MoeTheme get _moe => MoeTheme.of(context);

  late double _balance;
  bool _isAgreeProtocol = false;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _balance = widget.initialBalance;
  }

  double get _shortfall {
    final diff = widget.plan.price - _balance;
    return diff > 0 ? diff : 0;
  }

  Future<void> _refreshBalance() async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      return;
    }

    try {
      final userInfo = await CommerceService.getUserInfo(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _balance = userInfo.balance;
      });
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '刷新余额失败，请稍后重试');
      }
    }
  }

  Future<void> _goRecharge() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RechargePage()),
    );
    await _refreshBalance();
  }

  Future<void> _confirmPay() async {
    if (!_isAgreeProtocol || _isPaying) {
      return;
    }

    final userId = AuthService.currentUser;
    if (userId == null) {
      MoeToast.error(context, '请先登录');
      return;
    }

    if (_shortfall > 0) {
      MoeToast.show(
        context,
        '余额不足，请先充值',
        icon: Icons.account_balance_wallet_rounded,
        backgroundColor: const Color(0xFFFFF8E1),
        textColor: const Color(0xFF8B6914),
      );
      return;
    }

    setState(() {
      _isPaying = true;
    });

    try {
      final vipResult = await CommerceService.createVipOrderWithUnlocks(
          userId, widget.plan.id);
      final order = vipResult.order;
      await CommerceService.syncUserVipStatus(userId);
      await _refreshBalance();

      if (!mounted) {
        return;
      }
      final unlocked = vipResult.newAchievements;
      final action = await _showPaySuccessDialog(order.amount);
      if (!mounted) {
        return;
      }
      if (unlocked.isNotEmpty) {
        AchievementHooks.scheduleServerUnlocks(userId, unlocked);
      }
      if (action == 'order_center') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OrderCenterPage()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, _resolvePayErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  String _resolvePayErrorMessage(Object error) {
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      final code = error.code;
      if (message.contains('余额不足') || message.contains('insufficient')) {
        return '支付失败：钱包余额不足，请先充值后再试';
      }
      if (message.contains('超时') ||
          message.contains('timeout') ||
          message.contains('网络') ||
          message.contains('无法连接') ||
          code == 503 ||
          code == 504) {
        return '支付失败：网络异常，请检查网络后重试';
      }
      if (error.message.trim().isNotEmpty) {
        return '支付失败：${error.message}';
      }
    }
    final text = error.toString().toLowerCase();
    if (text.contains('余额不足')) {
      return '支付失败：钱包余额不足，请先充值后再试';
    }
    if (text.contains('timeout') || text.contains('网络')) {
      return '支付失败：网络异常，请稍后重试';
    }
    return '支付失败，请稍后重试';
  }

  Future<String?> _showPaySuccessDialog(double amount) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: MoeTokens.success),
                  SizedBox(width: 8),
                  Text(
                    '支付成功',
                    style: TextStyle(
                      fontSize: MoeTokens.textXl,
                      fontWeight: MoeTokens.fontWeightTitle,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              Text(
                '已使用钱包余额支付 ¥${amount.toStringAsFixed(2)}，会员权益已生效。',
                style: const TextStyle(
                  color: MoeTokens.bodyText,
                  fontSize: MoeTokens.textBase,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: MoeTokens.spaceLg),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, 'vip_center'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _moe.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(MoeTokens.radiusButton),
                    ),
                  ),
                  child: const Text('返回会员中心'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'order_center'),
                style: TextButton.styleFrom(
                  foregroundColor: _moe.primary,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('查看订单中心'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _moe.pageBackground,
      appBar: AppBar(
        title: const Text(
          '确认订单',
          style: TextStyle(
              color: MoeTokens.titleText, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: MoeTokens.titleText),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            MoeReveal(child: _buildOrderSummaryCard()),
            const SizedBox(height: 14),
            const MoeReveal(
              delay: Duration(milliseconds: 60),
              child: VipBenefitPanel(
                showIntro: false,
                caption: '使用钱包余额扣款',
              ),
            ),
            const SizedBox(height: 14),
            MoeReveal(
              delay: const Duration(milliseconds: 80),
              child: _buildAmountDetailsCard(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _moe.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: _moe.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MoeTokens.titleText,
                    fontSize: MoeTokens.textLg,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '开通 ${widget.plan.durationDays} 天',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MoeTokens.hintText,
                    fontSize: MoeTokens.textSm,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Text(
            '¥${widget.plan.price.toStringAsFixed(2)}',
            style: TextStyle(
              color: _moe.primary,
              fontSize: MoeTokens.textLg,
              fontWeight: MoeTokens.fontWeightTitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        children: [
          _buildInfoRow('套餐金额', '¥${widget.plan.price.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _buildInfoRow('当前余额', '¥${_balance.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          Divider(color: _moe.primary.withValues(alpha: 0.15)),
          const SizedBox(height: 10),
          _buildInfoRow(
            _shortfall > 0 ? '还需支付' : '支付后余额',
            _shortfall > 0
                ? '¥${_shortfall.toStringAsFixed(2)}'
                : '¥${(_balance - widget.plan.price).toStringAsFixed(2)}',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canPay = !_isPaying && _isAgreeProtocol && _shortfall <= 0;
    return Container(
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: MoeTokens.surfaceBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoePressable(
              onTap: _isPaying
                  ? null
                  : () {
                      setState(() {
                        _isAgreeProtocol = !_isAgreeProtocol;
                      });
                    },
              child: Row(
                children: [
                  IgnorePointer(
                    child: Checkbox(
                      value: _isAgreeProtocol,
                      activeColor: _moe.primary,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (_) {},
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '同意使用钱包余额支付这次订单',
                      style: TextStyle(
                        color: MoeTokens.bodyText,
                        fontSize: MoeTokens.textSm,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (_shortfall > 0)
                    TextButton(
                      onPressed: _goRecharge,
                      style: TextButton.styleFrom(
                        foregroundColor: _moe.primary,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: MoeTokens.textSm,
                        ),
                      ),
                      child: const Text('去充值'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: canPay ? _confirmPay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _moe.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCACEEB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
                  ),
                ),
                child: _isPaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _shortfall > 0
                            ? '余额不足，请先充值'
                            : '确认支付 ¥${widget.plan.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: MoeTokens.textBase,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    final color = highlight ? _moe.primary : MoeTokens.titleText;
    final weight = highlight ? FontWeight.w800 : FontWeight.w600;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: MoeTokens.bodyText,
              fontSize: MoeTokens.textBase,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: MoeTokens.textMd,
              fontWeight: weight,
            ),
          ),
        ),
      ],
    );
  }
}
