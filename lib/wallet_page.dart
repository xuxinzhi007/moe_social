import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/recharge_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({Key? key}) : super(key: key);

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  bool _isLoading = false;
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
    _loadTransactions();
  }

  Future<void> _loadWalletInfo() async {
    try {
      final userId = AuthService.currentUser;
      if (userId == null) return;
      final userInfo = await ApiService.getUserInfo(userId);
      setState(() {
        _balance = userInfo.balance;
      });
      await _loadTransactions();
    } catch (e) {
      print('加载钱包信息失败: $e');
    }
  }

  Future<void> _loadTransactions() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.currentUser;
      if (userId == null) return;
      final result = await ApiService.getTransactions(
        userId,
        page: _page,
        pageSize: _pageSize,
      );

      final transactions = result['data'] as List;
      final total = result['total'] as int;

      // 解析amount为double，防止int/double类型错误
      final parsedTransactions = transactions.map((t) {
        if (t is Map<String, dynamic>) {
          if (t['amount'] is int) {
            t['amount'] = (t['amount'] as int).toDouble();
          }
          if (t['amount'] is String) {
            t['amount'] = double.tryParse(t['amount']) ?? 0.0;
          }
        }
        return t;
      }).toList();

      setState(() {
        if (_page == 1) {
          _transactions = parsedTransactions;
        } else {
          _transactions.addAll(parsedTransactions);
        }
        _total = total;
        _hasMore = _transactions.length < total;
        _page++;
      });
    } catch (e) {
      print('加载交易记录失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载交易记录失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    _page = 1;
    _hasMore = true;
    _transactions.clear();
    await Future.wait([
      _loadWalletInfo(),
      _loadTransactions(),
    ]);
  }

  void _goToRecharge() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RechargePage()),
    ).then((_) {
      // 返回时刷新钱包信息
      _refresh();
    });
  }

  String _formatTransactionType(String type) {
    switch (type) {
      case 'recharge':
        return '充值';
      case 'consume':
        return '消费';
      default:
        return type;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'recharge':
        return Colors.green;
      case 'consume':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatAmount(double amount, String type) {
    if (type == 'recharge') {
      return '+¥${amount.toStringAsFixed(2)}';
    } else {
      return '-¥${amount.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的钱包'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 余额卡片
              Card(
                elevation: 4,
                margin: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '当前余额',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '¥${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _goToRecharge,
                        icon: const Icon(Icons.add),
                        label: const Text('立即充值'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 交易记录标题
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '交易记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 交易记录列表
              if (_transactions.isEmpty && !_isLoading) ...[
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        '暂无交易记录',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _transactions.length) {
                      if (_isLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (_hasMore) {
                        return TextButton(
                          onPressed: _loadTransactions,
                          child: const Text('加载更多'),
                        );
                      } else {
                        return const SizedBox(height: 20);
                      }
                    }

                    final transaction = _transactions[index] as Map<String, dynamic>;
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getTransactionColor(transaction['type'] as String),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          transaction['type'] == 'recharge' 
                              ? Icons.add 
                              : Icons.remove,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        transaction['description'] as String? ?? _formatTransactionType(transaction['type'] as String),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        transaction['created_at'] as String,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      trailing: Text(
                        _formatAmount(transaction['amount'] as double, transaction['type'] as String),
                        style: TextStyle(
                          color: _getTransactionColor(transaction['type'] as String),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
