import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../services/commerce_service.dart';
import '../../models/vip_plan.dart';
import 'vip_benefit_catalog.dart';
import 'vip_order_confirm_page.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';
import '../../widgets/motion/moe_motion.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_stagger.dart';
import '../../widgets/moe_toast.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';

class VipPurchasePage extends StatefulWidget {
  const VipPurchasePage({super.key});

  @override
  State<VipPurchasePage> createState() => _VipPurchasePageState();
}

class _VipPurchasePageState extends State<VipPurchasePage> {
  MoeTheme get _moe => MoeTheme.of(context);

  List<VipPlan> _plans = [];
  bool _isLoading = true;
  bool _isOpeningConfirm = false;
  String? _selectedPlanId;
  String? _loadErrorMessage;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userId = AuthService.currentUser;
      final futures = <Future<dynamic>>[
        CommerceService.getVipPlans(),
        if (userId != null) CommerceService.getUserInfo(userId),
      ];
      final results = await Future.wait(futures);
      final plans = results[0] as List<VipPlan>;

      if (!mounted) {
        return;
      }
      setState(() {
        _plans = plans;
        _loadErrorMessage = null;
        if (userId != null && results.length > 1) {
          _balance = results[1].balance as double;
        }
        if (plans.isNotEmpty) {
          final hasSelectedPlan =
              plans.any((plan) => plan.id == _selectedPlanId);
          if (!hasSelectedPlan) {
            _selectedPlanId = plans.first.id;
          }
        } else {
          _selectedPlanId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorMessage = _resolveLoadErrorMessage(e);
      });
      MoeToast.error(context, _loadErrorMessage ?? '加载VIP套餐失败，请稍后重试');
    }
  }

  String _resolveLoadErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timeout') || message.contains('超时')) {
      return '网络超时，加载失败，请下拉刷新或重试';
    }
    if (message.contains('socket') ||
        message.contains('无法连接') ||
        message.contains('network')) {
      return '网络连接异常，请检查后重试';
    }
    return '加载VIP套餐失败，请稍后重试';
  }

  Future<void> _refreshBalance() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;
    try {
      final userInfo = await CommerceService.getUserInfo(userId);
      if (mounted) {
        setState(() {
          _balance = userInfo.balance;
        });
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '刷新余额失败，请稍后重试');
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadInitialData(showLoading: false);
  }

  Future<void> _goOrderConfirm() async {
    if (_selectedPlanId == null || _isOpeningConfirm) return;

    final selectedPlan = _getSelectedPlan();
    if (selectedPlan == null) return;

    final userId = AuthService.currentUser;
    if (userId == null) {
      MoeToast.error(context, '请先登录');
      return;
    }

    setState(() {
      _isOpeningConfirm = true;
    });
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => VipOrderConfirmPage(
            plan: selectedPlan,
            initialBalance: _balance,
          ),
        ),
      );
      if (result == true) {
        await _refreshBalance();
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningConfirm = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = moeReduceMotion(context);
    return AdaptivePageScaffold(
      template: PageTemplate.form,
      title: '购买 / 续费',
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _moe.primary))
          : RefreshIndicator(
              color: _moe.primary,
              onRefresh: _handleRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  MoeTokens.spaceLg,
                  MoeTokens.spaceLg,
                  MoeTokens.spaceLg,
                  MoeTokens.space2xl,
                ),
                children: [
                  const Text(
                    '选择时长',
                    style: TextStyle(
                      fontSize: MoeTokens.textXl,
                      fontWeight: MoeTokens.fontWeightTitle,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(height: MoeTokens.spaceXs),
                  Text(
                    '用钱包余额支付。确认前不会扣款，也不会开通。',
                    style: TextStyle(
                      color: MoeTokens.hintText,
                      fontSize: MoeTokens.textSm,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: MoeTokens.spaceLg),
                  if (_plans.isEmpty && _loadErrorMessage != null)
                    _buildLoadFailedState()
                  else if (_plans.isEmpty)
                    _buildEmptyPlanState()
                  else
                    SizedBox(
                      height: 156,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          return MoeStaggerReveal(
                            index: index,
                            maxAnimated: 8,
                            staggerStep: const Duration(milliseconds: 30),
                            child: _buildPlanCard(
                              _plans[index],
                              reduceMotion: reduceMotion,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: MoeTokens.spaceXl),
                  const VipBenefitPanel(),
                  if (_planNotes().isNotEmpty) ...[
                    const SizedBox(height: MoeTokens.spaceLg),
                    ..._planNotes().map(_buildPlanNote),
                  ],
                ],
              ),
            ),
      bottomAction: _buildCheckoutBar(),
    );
  }

  Widget _buildCheckoutBar() {
    final canOpen = !_isLoading && _plans.isNotEmpty && !_isOpeningConfirm;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '¥${_getSelectedPlanPrice()}',
              style: TextStyle(
                fontSize: MoeTokens.textXl,
                fontWeight: MoeTokens.fontWeightTitle,
                color: _moe.primary,
              ),
            ),
            const SizedBox(width: MoeTokens.spaceMd),
            Expanded(
              child: Text(
                '余额 ¥${_balance.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: MoeTokens.textSm,
                  color: MoeTokens.inkMuted,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MoeTokens.spaceSm),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: canOpen ? _goOrderConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _moe.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: MoeTokens.lineSoft,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
              ),
            ),
            child: Text(
              _isOpeningConfirm ? '正在打开确认页' : '去确认订单',
              style: const TextStyle(
                fontSize: MoeTokens.textBase,
                fontWeight: MoeTokens.fontWeightTitle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getSelectedPlanPrice() {
    if (_plans.isEmpty || _selectedPlanId == null) return '0.00';
    final plan = _plans.firstWhere((p) => p.id == _selectedPlanId,
        orElse: () => _plans.first);
    return plan.price.toStringAsFixed(2);
  }

  VipPlan? _getSelectedPlan() {
    if (_plans.isEmpty || _selectedPlanId == null) return null;
    return _plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  Widget _buildPlanCard(VipPlan plan, {required bool reduceMotion}) {
    final isSelected = _selectedPlanId == plan.id;
    final motion = reduceMotion ? Duration.zero : MoeTokens.motionFast;
    return MoePressable(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
        });
      },
      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
      child: AnimatedContainer(
        duration: motion,
        curve: Curves.easeInOut,
        width: 132,
        height: 148,
        margin: const EdgeInsets.only(right: MoeTokens.spaceSm),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: Border.all(
            color: isSelected ? _moe.primary : MoeTokens.surfaceBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? MoeTokens.shadowSm() : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MoeTokens.textBase,
                      fontWeight: MoeTokens.fontWeightTitle,
                      color:
                          isSelected ? MoeTokens.titleText : MoeTokens.inkMuted,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: motion,
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: _moe.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '¥${plan.price.toStringAsFixed(plan.price.truncateToDouble() == plan.price ? 0 : 2)}',
              style: TextStyle(
                fontSize: MoeTokens.textXl,
                fontWeight: MoeTokens.fontWeightTitle,
                color: isSelected ? _moe.primary : MoeTokens.titleText,
              ),
            ),
            const SizedBox(height: MoeTokens.spaceXs),
            Text(
              '${plan.durationDays} 天',
              style: const TextStyle(
                fontSize: MoeTokens.textSm,
                color: MoeTokens.hintText,
                fontWeight: MoeTokens.fontWeightSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadFailedState() {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: _moe.primary, size: 28),
          const SizedBox(height: MoeTokens.spaceSm),
          Text(
            _loadErrorMessage ?? '加载失败，请稍后重试',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MoeTokens.titleText,
              fontWeight: MoeTokens.fontWeightSubtitle,
              fontSize: MoeTokens.textBase,
            ),
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          TextButton(
            onPressed: _loadInitialData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlanState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: const Text(
        '暂时没有可购买的套餐',
        style:
            TextStyle(color: MoeTokens.hintText, fontSize: MoeTokens.textBase),
      ),
    );
  }

  List<String> _planNotes() {
    return _extractBenefitsFromDescription(
        _getSelectedPlan()?.description ?? '');
  }

  Widget _buildPlanNote(String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MoeTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _moe.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                color: MoeTokens.inkMuted,
                fontSize: MoeTokens.textSm,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractBenefitsFromDescription(String description) {
    if (description.trim().isEmpty) {
      return [];
    }
    return description
        .split(RegExp(r'[\n;；|]'))
        .map((line) => line.replaceAll(RegExp(r'^[\-\d\.\s、]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(4)
        .toList();
  }
}
