import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/services/api_service.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/app_message_widget.dart';
import '../../providers/loading_provider.dart';
import '../../theme/moe_theme_extension.dart';
import '../../theme/moe_tokens.dart';

class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  MoeTheme get _moe => MoeTheme.of(context);

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(text: '余额充值');
  double _currentBalance = 0.0;
  
  // 预设充值金额
  final List<int> _presetAmounts = [10, 50, 100, 200, 500, 1000];
  int? _selectedAmount;

  // Moe 风格配色（build 时读取，避免在字段初始化器里访问 context）
  Color get _primaryColor => _moe.primary;
  Color get _accentColor => MoeTokens.secondary;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userId = AuthService.currentUser;
      if (userId == null) return;
      final userInfo = await ApiService.getUserInfo(userId);
      if (mounted) {
        setState(() {
          _currentBalance = userInfo.balance;
        });
      }
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  Future<void> _handleRecharge() async {
    if (_amountController.text.isEmpty) {
      _showError('请输入充值金额');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('请输入有效的充值金额');
      return;
    }

    final loadingProvider = context.read<LoadingProvider>();
    loadingProvider.setOperationLoading(LoadingKeys.recharge, true);

    try {
      final userId = AuthService.currentUser;
      if (userId == null) return;
      
      await ApiService.recharge(
        userId,
        amount,
        _descriptionController.text,
      );

      final userInfo = await ApiService.getUserInfo(userId);
      if (mounted) {
        setState(() {
          _currentBalance = userInfo.balance;
        });
      }

      _showSuccess('充值成功！\n当前余额: ${_currentBalance.toStringAsFixed(2)} 元');
      _amountController.clear();
      setState(() {
        _selectedAmount = null;
      });
    } catch (e) {
      print('充值失败: $e');
      _showError('充值失败: ${e.toString()}');
    } finally {
      if (mounted) {
        context.read<LoadingProvider>().setOperationLoading(LoadingKeys.recharge, false);
      }
    }
  }

  void _showError(String message) {
    MoeToast.error(context, message);
  }

  void _showSuccess(String message) {
    MoeToast.success(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _moe.pageBackground,
      appBar: AppBar(
        title: const Text('余额充值', style: TextStyle(fontWeight: FontWeight.bold, color: MoeTokens.titleText)),
        centerTitle: true,
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: MoeTokens.titleText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前余额显示 - 样式与钱包页统一
            FadeInUp(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '当前余额',
                      style: TextStyle(
                        fontSize: MoeTokens.textLg,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 使用 FittedBox 确保大额数字不溢出
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '¥${_currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            // 快捷充值金额
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择充值金额',
                    style: TextStyle(
                      fontSize: MoeTokens.textLg,
                      fontWeight: FontWeight.bold,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: _presetAmounts.length,
                    itemBuilder: (context, index) {
                      final amount = _presetAmounts[index];
                      final isSelected = _selectedAmount == amount;
                      
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAmount = amount;
                              _amountController.text = amount.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? _primaryColor : MoeTokens.cardBackground,
                              borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.1),
                                width: 1,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: _primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                else
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '¥$amount',
                              style: TextStyle(
                                color: isSelected ? Colors.white : MoeTokens.bodyText,
                                fontWeight: FontWeight.bold,
                                fontSize: MoeTokens.textLg,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // 自定义金额输入
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '其他金额',
                    style: TextStyle(
                      fontSize: MoeTokens.textLg,
                      fontWeight: FontWeight.bold,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: MoeTokens.cardBackground,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                      boxShadow: [
                        BoxShadow(
                          color: _moe.primary.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: MoeInputField(
                      controller: _amountController,
                      hintText: '请输入具体金额',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.attach_money_rounded, color: _primaryColor),
                      filled: false,
                      onTap: () {
                        // 如果用户手动输入，清除预设选择
                        if (_selectedAmount != null) {
                          setState(() {
                            _selectedAmount = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // 充值说明
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: MoeTokens.cardBackground,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: _moe.primary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: MoeInputField(
                  controller: _descriptionController,
                  hintText: '备注说明（可选）',
                  maxLines: 1,
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: MoeTokens.hintText),
                  filled: false,
                ),
              ),
            ),
            
            const SizedBox(height: 40),

            // 充值按钮
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: LoadingButton(
                operationKey: LoadingKeys.recharge,
                onPressed: _handleRecharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 8,
                  shadowColor: _primaryColor.withValues(alpha: 0.4),
                ),
                child: const Text(
                  '确认支付',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 充值提示
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4).withValues(alpha: 0.3), // 浅黄色背景
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  border: Border.all(color: const Color(0xFFFFE082).withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: Colors.orange[400]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '温馨提示：\n1. 本次充值为模拟充值，不会产生真实扣费\n2. 充值金额将直接添加到您的测试账户余额\n3. 遇到问题请联系客服',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
