import 'package:flutter/material.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/services/api_service.dart';
import 'package:moe_social/recharge_page.dart';
// 暂时移除动画库以排查卡死问题
// import 'widgets/fade_in_up.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadWalletInfo();
      _loadTransactions();
    });
  }

  Future<void> _loadWalletInfo() async {
    try {
      final userId = AuthService.currentUser;
      if (userId == null) return;
      final userInfo = await ApiService.getUserInfo(userId);
      if (mounted) {
        setState(() {
          _balance = userInfo.balance;
        });
      }
    } catch (e) {
      print('加载钱包信息失败: $e');
    }
  }

  Future<void> _loadTransactions() async {
    if (_isLoading || !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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

      // 解析amount为double
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

      if (mounted) {
        setState(() {
          if (_page == 1) {
            _transactions = parsedTransactions;
          } else {
            _transactions.addAll(parsedTransactions);
          }
          _hasMore = _transactions.length < total;
          _page++;
        });
      }
    } catch (e) {
      print('加载交易记录失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载交易记录失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      _refresh();
    });
  }

  String _formatTransactionType(String type) {
    switch (type) {
      case 'recharge':
        return '余额充值';
      case 'consume':
        return '消费支出';
      default:
        return type;
    }
  }

  String _formatAmount(double amount, String type) {
    if (type == 'recharge') {
      return '+${amount.toStringAsFixed(2)}';
    } else {
      return '-${amount.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('我的钱包', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 余额卡片
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildBalanceCard(),
              ),
              
              // 交易明细标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 4, 
                      height: 18, 
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F7FD5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '交易明细',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 交易记录列表或空状态
              if (_transactions.isEmpty && !_isLoading)
                Container(
                  padding: const EdgeInsets.only(top: 60),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无交易记录',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _transactions.length) {
                      if (_isLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (_hasMore) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: TextButton(
                              onPressed: _loadTransactions,
                              child: const Text('点击加载更多'),
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox(height: 20); // 底部留白
                      }
                    }

                    final transaction = _transactions[index] as Map<String, dynamic>;
                    return _buildTransactionItem(transaction);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    // 移除 Stack，改用 Column + Align 线性布局
    // 解决 HitTest 异常和内容遮挡问题
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180), // 最小高度而不是固定高度
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3E50).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：图标 + 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.attach_money, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                '账户余额',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 中间：余额数字 (自适应缩放)
          const Text(
            '¥',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _balance.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 底部：充值按钮 (右对齐)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _goToRecharge,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('充值'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2C3E50),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final isRecharge = type == 'recharge';
    final color = isRecharge ? Colors.green : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isRecharge ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'] as String? ?? _formatTransactionType(type),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction['created_at'] as String,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(transaction['amount'] as double, type),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
