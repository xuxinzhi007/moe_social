import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'widgets/dynamic_avatar.dart';
import 'widgets/gacha_machine_display.dart';
import 'models/user.dart';
import 'models/virtual_item.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'inventory_page.dart';
import 'recharge_page.dart';

class GachaPage extends StatefulWidget {
  const GachaPage({super.key});

  @override
  State<GachaPage> createState() => _GachaPageState();
}

class _GachaPageState extends State<GachaPage> with SingleTickerProviderStateMixin {
  late AnimationController _ballDropController;

  final Random _random = Random();
  bool _isPlaying = false;
  
  // 抽奖结果相关
  List<VirtualItem> _gachaResults = [];
  Color _currentBallColor = Colors.blueAccent;

  final List<GachaBall> _balls = [];
  final List<Color> _ballColors = [
    const Color(0xFFFF9A9E), // Pink - SSR
    const Color(0xFFA18CD1), // Purple - SR
    const Color(0xFF8FD3F4), // Blue - R
    const Color(0xFFE2E2E2), // Grey - N
  ];

  // 用户数据
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initBalls();
    
    _ballDropController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  Future<void> _loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId != null) {
      try {
        final user = await ApiService.getUserInfo(userId);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      } catch (e) {
        print('Failed to load user info: $e');
      }
    }
  }

  void _initBalls() {
    // 初始化小球 (位置在底部堆叠)
    for (int i = 0; i < 12; i++) {
      _balls.add(GachaBall(
        x: 0.2 + _random.nextDouble() * 0.6,
        y: 0.8 + _random.nextDouble() * 0.1,
        vx: (_random.nextDouble() - 0.5) * 0.01,
        vy: 0,
        color: _ballColors[i % _ballColors.length],
        rotation: _random.nextDouble() * 2 * pi,
        rotateSpeed: (_random.nextDouble() - 0.5) * 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _ballDropController.dispose();
    super.dispose();
  }

  // 开始抽奖逻辑
  void _startGacha(int count) async {
    if (_isPlaying || _currentUser == null) return;

    // 1. 检查余额
    double cost = count == 10 ? 45.0 : 5.0 * count;
    if (_currentUser!.balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('余额不足，请充值'),
          action: SnackBarAction(
            label: '充值',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RechargePage()),
              ).then((_) {
                _loadUserInfo(); // 充值返回后刷新余额
              });
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _isPlaying = true;
      _gachaResults.clear();
      // 随机选一个球色作为主色调 (其实应该根据结果定，这里先随机)
      _currentBallColor = _ballColors[_random.nextInt(_ballColors.length)];
    });

    // 2. 扣费 (调用后端 API)
    try {
      await ApiService.recharge(
        _currentUser!.id, 
        -cost, 
        '扭蛋消费'
      );
      
      // 更新本地余额显示
      setState(() {
        _currentUser = _currentUser!.copyWith(
          balance: _currentUser!.balance - cost
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扣费失败: $e')),
      );
      return;
    }

    // 3. 启动物理循环 (通过 isPlaying 状态自动触发)

    // 4. 生成结果 (模拟后端算法)
    await _generateGachaResults(count);

    // 持续搅动 2.0秒
    await Future.delayed(const Duration(milliseconds: 2000));

    // 5. 停止搅动
    setState(() {
      _isPlaying = false;
    });
    
    // 6. 出货动画
    await _ballDropController.forward();

    // 7. 显示结果
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _showResultDialog();
    }

    _ballDropController.reset();
  }

  Future<void> _generateGachaResults(int count) async {
    await Future.delayed(const Duration(milliseconds: 500));
    List<VirtualItem> results = [];
    final mockPool = VirtualItem.mockItems;
    
    // 辅助函数：从列表中随机获取一个
    VirtualItem getRandomItem(List<VirtualItem> items) {
      if (items.isEmpty) return mockPool[0];
      return items[_random.nextInt(items.length)];
    }

    for (int i = 0; i < count; i++) {
      int roll = _random.nextInt(100);
      // 保底机制：十连抽的第10发必出SR或以上 (如果前9发没出)
      if (count == 10 && i == 9 && roll > 12) {
        roll = _random.nextInt(12); // 强制落在 0-11 区间 (SSR or SR)
      }
      
      VirtualItem item;
      if (roll < 2) { // 2% SSR
        final ssrItems = mockPool.where((e) => e.rarity == ItemRarity.ssr).toList();
        item = getRandomItem(ssrItems);
      } else if (roll < 12) { // 10% SR
        final srItems = mockPool.where((e) => e.rarity == ItemRarity.sr).toList();
        item = getRandomItem(srItems);
      } else if (roll < 42) { // 30% R
        final rItems = mockPool.where((e) => e.rarity == ItemRarity.r).toList();
        item = getRandomItem(rItems);
      } else { // 58% N
        final nItems = mockPool.where((e) => e.rarity == ItemRarity.n).toList();
        item = getRandomItem(nItems);
      }
      results.add(item);
    }
    
    if (_currentUser != null) {
      // 抽奖前先刷新用户信息，确保 inventory 是最新的，避免覆盖旧数据
      try {
        final latestUser = await ApiService.getUserInfo(_currentUser!.id);
        if (mounted) {
           _currentUser = latestUser;
        }
      } catch (e) {
        print('Failed to refresh user info before saving: $e');
        // 如果刷新失败，继续使用本地状态，但有覆盖风险
      }

      final newInventory = List<String>.from(_currentUser!.inventory);
      for (var item in results) {
        newInventory.add(item.id);
      }
      
      // 调用后端 API 保存背包数据
      try {
        await ApiService.updateUserInfo(
          _currentUser!.id,
          inventory: newInventory,
          avatar: _currentUser!.avatar.isEmpty ? null : _currentUser!.avatar,
        );
      } catch (e) {
        print('Failed to save inventory: $e');
        // 即使保存失败，本地也先显示结果，用户可能重试或者下次加载时丢失（这是风险）
      }

      setState(() {
        _currentUser = _currentUser!.copyWith(inventory: newInventory);
        _gachaResults = results;
        
        // 根据最高稀有度改变球的颜色
        var maxRarity = results.map((e) => e.rarity.index).reduce(max);
        if (maxRarity == ItemRarity.ssr.index) _currentBallColor = _ballColors[0];
        else if (maxRarity == ItemRarity.sr.index) _currentBallColor = _ballColors[1];
        else if (maxRarity == ItemRarity.r.index) _currentBallColor = _ballColors[2];
        else _currentBallColor = _ballColors[3];
      });
    }
  }

  void _showResultDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _currentBallColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _gachaResults.length > 1 ? '十连大满足!' : '获得物品',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _currentBallColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 结果列表
                    Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: _gachaResults.length == 1 
                        ? _buildSingleResult(_gachaResults.first)
                        : _buildMultiResult(_gachaResults),
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentBallColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('收入背包'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProbabilityDialog() {
    final pool = VirtualItem.mockItems;
    final Map<ItemRarity, List<VirtualItem>> groups = {
      ItemRarity.ssr: [],
      ItemRarity.sr: [],
      ItemRarity.r: [],
      ItemRarity.n: [],
    };
    for (final item in pool) {
      groups[item.rarity]?.add(item);
    }

    String joinNames(List<VirtualItem> items) {
      if (items.isEmpty) return '暂无';
      return items.map((e) => e.name).join('、');
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('概率说明'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '当前概率（单抽）：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'SSR：2%  (${joinNames(groups[ItemRarity.ssr] ?? [])})',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'SR：10% (${joinNames(groups[ItemRarity.sr] ?? [])})',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'R：30% (${joinNames(groups[ItemRarity.r] ?? [])})',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'N：58% (${joinNames(groups[ItemRarity.n] ?? [])})',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  '十连第10发保底 SR 及以上。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  void _showGachaPoolDialog() {
    final pool = VirtualItem.mockItems;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '奖池预览',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showProbabilityDialog();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: pool.length,
                    itemBuilder: (context, index) {
                      final item = pool[index];
                      return _buildPoolItemCard(item);
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleResult(VirtualItem item) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Color(item.rarityColor).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: item.type == ItemType.avatarFrame
                ? DynamicAvatar(avatarUrl: _currentUser?.avatar ?? '', size: 80, frameId: item.id)
                : Icon(Icons.card_giftcard, size: 50, color: Color(item.rarityColor)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          item.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          item.rarityLabel,
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: Color(item.rarityColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMultiResult(List<VirtualItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildResultCard(item);
      },
    );
  }

  Widget _buildResultCard(VirtualItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Color(item.rarityColor).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(item.rarityColor).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: item.type == ItemType.avatarFrame
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: DynamicAvatar(
                        avatarUrl: _currentUser?.avatar ?? '',
                        size: 40,
                        frameId: item.id,
                      ),
                    )
                  : Icon(
                      Icons.card_giftcard,
                      size: 30,
                      color: Color(item.rarityColor),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            item.rarityLabel,
            style: TextStyle(
              fontSize: 10,
              color: Color(item.rarityColor),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildPoolItemCard(VirtualItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Color(item.rarityColor).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: item.type == ItemType.avatarFrame
                  ? SizedBox(
                      width: 46,
                      height: 46,
                      child: DynamicAvatar(
                        avatarUrl: _currentUser?.avatar ?? '',
                        size: 46,
                        frameId: item.id,
                      ),
                    )
                  : Icon(
                      Icons.card_giftcard,
                      size: 32,
                      color: Color(item.rarityColor),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.rarityLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(item.rarityColor),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: const Text('心情扭蛋机', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          // 背包按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.backpack_outlined, color: Colors.blueAccent),
              onPressed: () {
                if (_currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryPage(
                        user: _currentUser!,
                        onUserUpdate: (updatedUser) {
                          setState(() {
                            _currentUser = updatedUser;
                          });
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          // 余额显示
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 16, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(
                  _currentUser?.balance.toStringAsFixed(2) ?? '0.00',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand, 
        children: [
          // 装饰背景
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.pink[50],
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // 机器主体 (略微上移)
          Align(
            alignment: const Alignment(0, -0.05),
            child: Container(
              width: 280,
              height: 400,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB7C5), Color(0xFFFFA5B5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Column(
                children: [
                  // 玻璃罩
                  Container(
                    margin: const EdgeInsets.all(20),
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(-5, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: GachaMachineDisplay(
                        isPlaying: _isPlaying,
                        balls: _balls,
                        onPhysicsUpdate: (balls) {
                          // 如果需要处理物理回调
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 状态文字
                  _isPlaying 
                    ? const Text(
                        '正在扭蛋中...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.white.withOpacity(0.6), size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Moe Gacha',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Courier', 
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 顶部奖品池按钮
          Positioned(
            top: kToolbarHeight + 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _showGachaPoolDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.card_giftcard, size: 16, color: Color(0xFF7F7FD5)),
                      SizedBox(width: 6),
                      Text(
                        '当前奖品池',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF999999)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 32,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildGachaButton(
                        label: '单抽',
                        price: '¥5.0',
                        color: const Color(0xFF7F7FD5),
                        onTap: () => _startGacha(1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGachaButton(
                        label: '十连',
                        price: '¥45.0',
                        subLabel: '必出SR',
                        color: const Color(0xFFFF9A9E),
                        onTap: () => _startGacha(10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGachaButton({
    required String label,
    required String price,
    String? subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: _isPlaying ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: color.withOpacity(0.5),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 2),
                Text(
                  price,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            if (subLabel != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  subLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
