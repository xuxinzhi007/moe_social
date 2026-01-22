import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/widgets/custom_button.dart';
import 'package:moe_social/widgets/custom_text_field.dart';
import 'widgets/fade_in_up.dart';

class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(text: '余额充值');
  bool _isLoading = false;
  double _currentBalance = 0.0;
  
  // 预设充值金额
  final List<int> _presetAmounts = [10, 50, 100, 200, 500, 1000];
  int? _selectedAmount;

  // 定义页面主色调，与钱包页保持一致
  final Color _primaryColor = const Color(0xFF2C3E50); // 深蓝
  final Color _accentColor = const Color(0xFF4CA1AF); // 青色

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userId = await AuthService.getUserId();
      final userInfo = await ApiService.getUserInfo(userId);
      setState(() {
        _currentBalance = userInfo.balance;
      });
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

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await AuthService.getUserId();
      await ApiService.recharge(
        userId,
        amount,
        _descriptionController.text,
      );

      final userInfo = await ApiService.getUserInfo(userId);
      setState(() {
        _currentBalance = userInfo.balance;
      });

      _showSuccess('充值成功！\n当前余额: ${_currentBalance.toStringAsFixed(2)} 元');
      _amountController.clear();
      setState(() {
        _selectedAmount = null;
      });
    } catch (e) {
      print('充值失败: $e');
      _showError('充值失败: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('余额充值', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '当前余额',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAmount = amount;
                            _amountController.text = amount.toString();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? _accentColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '¥$amount',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CustomTextField(
                      controller: _amountController,
                      labelText: '充值金额',
                      hintText: '请输入具体金额',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.attach_money_rounded,
                      inputDecoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.attach_money_rounded, color: _accentColor),
                        hintText: '请输入具体金额',
                      ),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomTextField(
                  controller: _descriptionController,
                  labelText: '备注说明',
                  hintText: '可选',
                  maxLines: 1,
                  prefixIcon: Icons.edit_note_rounded,
                  inputDecoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.grey),
                    hintText: '可选',
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),

            // 充值按钮
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: CustomButton(
                onPressed: _isLoading ? null : () => _handleRecharge(),
                text: _isLoading ? '正在充值...' : '确认支付',
                isLoading: _isLoading,
                width: double.infinity,
                height: 56,
                fontSize: 18,
                borderRadius: BorderRadius.circular(28),
                backgroundColor: _primaryColor, // 保持深色
              ),
            ),

            // 充值提示
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '温馨提示：\n1. 本次充值为模拟充值，不会产生真实扣费\n2. 充值金额将直接添加到您的测试账户余额\n3. 遇到问题请联系客服',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[800],
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
