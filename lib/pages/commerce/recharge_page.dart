import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/widgets/custom_button.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/moe_toast.dart';

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

  // Moe 风格配色
  final Color _primaryColor = const Color(0xFF7F7FD5);
  final Color _accentColor = const Color(0xFF86A8E7);

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

    setState(() {
      _isLoading = true;
    });

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
        setState(() {
          _isLoading = false;
        });
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
                  borderRadius: BorderRadius.circular(24),
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
                    Text(
                      '当前余额',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF555555),
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
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? _primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                else
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
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
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7F7FD5).withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '请输入具体金额',
                        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                        prefixIcon: Icon(Icons.attach_money_rounded, color: _primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7F7FD5).withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: '备注说明',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    hintText: '可选',
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                backgroundColor: _primaryColor, // 使用薰衣草色
                shadowColor: _primaryColor.withOpacity(0.4),
                elevation: 8,
              ),
            ),

            // 充值提示
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4).withOpacity(0.3), // 浅黄色背景
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE082).withOpacity(0.5)),
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
