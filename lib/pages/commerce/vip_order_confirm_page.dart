import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../models/vip_plan.dart';
import '../../services/achievement_hooks.dart';
import '../../services/api_service.dart';
import '../../widgets/fade_in_up.dart';
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
      final userInfo = await ApiService.getUserInfo(userId);
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
      final order = await ApiService.createVipOrder(userId, widget.plan.id);
      await ApiService.syncUserVipStatus(userId);
      await _refreshBalance();

      if (!mounted) {
        return;
      }
      unawaited(AchievementHooks.recordVipPurchased(userId));
      final action = await _showPaySuccessDialog(order.amount);
      if (!mounted) {
        return;
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text(
                '支付成功',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            '已成功使用站内钱包余额支付 ¥${amount.toStringAsFixed(2)}，会员权益已生效。',
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'order_center'),
              child: const Text('查看订单中心'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 'vip_center'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7F7FD5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('返回会员中心'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          '确认订单',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          children: [
            FadeInUp(child: _buildOrderSummaryCard()),
            const SizedBox(height: 14),
            FadeInUp(
              delay: const Duration(milliseconds: 80),
              child: _buildAmountDetailsCard(),
            ),
            const SizedBox(height: 14),
            FadeInUp(
              delay: const Duration(milliseconds: 120),
              child: _buildWalletPayHintCard(),
            ),
            const SizedBox(height: 14),
            if (_shortfall > 0)
              FadeInUp(
                delay: const Duration(milliseconds: 140),
                child: _buildInsufficientCard(),
              ),
            const SizedBox(height: 14),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: _buildProtocolCard(),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '开通时长 ${widget.plan.durationDays} 天',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${widget.plan.price.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('套餐金额', '¥${widget.plan.price.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _buildInfoRow('当前余额', '¥${_balance.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          Divider(color: const Color(0xFF7F7FD5).withValues(alpha: 0.15)),
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

  Widget _buildInsufficientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD180)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFED6C02),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '余额不足',
                  style: TextStyle(
                    color: Color(0xFF8B6914),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '还需充值 ¥${_shortfall.toStringAsFixed(2)} 才能完成支付',
                  style: const TextStyle(
                    color: Color(0xFF8B6914),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _goRecharge,
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text('去充值'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB347),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _isAgreeProtocol,
            activeColor: const Color(0xFF7F7FD5),
            onChanged: (value) {
              setState(() {
                _isAgreeProtocol = value ?? false;
              });
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '我已阅读并同意《会员服务协议》并确认使用站内钱包余额支付本次订单',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletPayHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E3FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Color(0xFF7F7FD5),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本次将使用站内钱包余额扣款，若余额不足请先充值后再完成支付。',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final canPay = !_isPaying && _isAgreeProtocol && _shortfall <= 0;
    String helperMessage = '支付前请确认套餐和钱包余额';
    if (!_isAgreeProtocol) {
      helperMessage = '请先勾选会员服务协议';
    } else if (_shortfall > 0) {
      helperMessage = '余额不足，请先充值后再支付';
    } else if (_isPaying) {
      helperMessage = '正在创建订单并完成扣款...';
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canPay ? _confirmPay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCACEEB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _isPaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _shortfall > 0
                            ? '余额不足，请先充值'
                            : '确认支付 ¥${widget.plan.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    helperMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ),
                if (_shortfall > 0)
                  TextButton(
                    onPressed: _goRecharge,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7F7FD5),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    child: const Text('去充值'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    final color = highlight ? const Color(0xFF7F7FD5) : const Color(0xFF333333);
    final weight = highlight ? FontWeight.w800 : FontWeight.w600;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
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
              fontSize: 15,
              fontWeight: weight,
            ),
          ),
        ),
      ],
    );
  }
}
