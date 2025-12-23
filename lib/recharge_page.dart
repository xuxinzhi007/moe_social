import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/widgets/custom_button.dart';
import 'package:moe_social/widgets/custom_text_field.dart';

class RechargePage extends StatefulWidget {
  const RechargePage({Key? key}) : super(key: key);

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(text: '余额充值');
  bool _isLoading = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await AuthService.getUserInfo();
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
      final result = await ApiService.recharge(
        userId,
        amount,
        _descriptionController.text,
      );

      // 更新当前余额
      setState(() {
        _currentBalance = result['new_balance'] ?? _currentBalance + amount;
      });

      _showSuccess('充值成功！\n当前余额: ${_currentBalance.toStringAsFixed(2)} 元');
      _amountController.clear();
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
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('余额充值'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 当前余额显示
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      '当前余额',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¥${_currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 充值金额输入
            const Text(
              '请输入充值金额',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _amountController,
              labelText: '充值金额',
              hintText: '请输入金额',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.money,
            ),
            const SizedBox(height: 20),

            // 快捷充值金额
            const Text(
              '快捷充值',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var amount in [10, 50, 100, 200, 500, 1000])
                  ElevatedButton(
                    onPressed: () {
                      _amountController.text = amount.toString();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('¥$amount'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // 充值说明
            CustomTextField(
              controller: _descriptionController,
              labelText: '充值说明',
              hintText: '可选',
              maxLines: 2,
              prefixIcon: Icons.description,
            ),
            const SizedBox(height: 30),

            // 充值按钮
            CustomButton(
              onPressed: _isLoading ? null : () => _handleRecharge(),
              text: _isLoading ? '充值中...' : '确认充值',
              isLoading: _isLoading,
              width: double.infinity,
              height: 50,
              fontSize: 18,
            ),

            // 充值提示
            const SizedBox(height: 20),
            const Text(
              '提示：\n1. 本次充值为模拟充值，不会产生真实支付\n2. 充值金额将直接添加到您的账户余额\n3. 请根据实际需求选择充值金额',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
