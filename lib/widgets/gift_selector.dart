import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../models/user.dart';
import '../auth_service.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';

/// 礼物选择器组件
class GiftSelector extends StatefulWidget {
  final String targetId; // 目标ID（帖子ID或用户ID）
  final String targetType; // 'post' 或 'user'
  final String receiverId; // 接收者用户ID
  final Function(Gift)? onGiftSent; // 礼物发送成功回调

  const GiftSelector({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.receiverId,
    this.onGiftSent,
  });

  @override
  State<GiftSelector> createState() => _GiftSelectorState();
}

class _GiftSelectorState extends State<GiftSelector>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Gift> _gifts = [];
  bool _isLoading = false;
  double _userBalance = 0.0;
  Gift? _selectedGift;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: GiftCategory.values.length + 1, vsync: this);
    _loadGifts();
    _loadUserBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadGifts() {
    setState(() {
      _gifts = Gift.defaultGifts;
    });
  }

  Future<void> _loadUserBalance() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;

    try {
      final user = await ApiService.getUserInfo(userId);
      setState(() {
        _userBalance = user.balance;
      });
    } catch (e) {
      print('加载用户余额失败: $e');
    }
  }

  Future<void> _sendGift(Gift gift) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      ErrorHandler.showError(context, '请先登录');
      return;
    }

    if (_userBalance < gift.price) {
      ErrorHandler.showError(context, '余额不足，请先充值');
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedGift = gift;
    });

    try {
      // 这里应该调用发送礼物的API
      // await ApiService.sendGift(gift.id, widget.receiverId, widget.targetType, widget.targetId);

      // 模拟API调用
      await Future.delayed(const Duration(seconds: 1));

      // 扣除余额
      setState(() {
        _userBalance -= gift.price;
      });

      if (mounted) {
        ErrorHandler.showSuccess(context, '礼物发送成功！🎁');
        widget.onGiftSent?.call(gift);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedGift = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '送礼物',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          size: 16, color: Colors.orange[600]),
                      const SizedBox(width: 4),
                      Text(
                        '余额: ¥${_userBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // 分类标签栏
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[600],
              indicatorWeight: 3,
              tabs: [
                const Tab(text: '热门'),
                ...GiftCategory.values.map((category) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.icon),
                      const SizedBox(width: 4),
                      Text(category.displayName),
                    ],
                  ),
                )),
              ],
            ),
          ),

          // 礼物网格
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGiftGrid(Gift.getPopularGifts(limit: 12)),
                ...GiftCategory.values.map((category) =>
                    _buildGiftGrid(Gift.getGiftsByCategory(category))),
              ],
            ),
          ),

          // 底部操作栏
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('正在发送礼物...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(List<Gift> gifts) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final canAfford = _userBalance >= gift.price;
        final isSelected = _selectedGift?.id == gift.id;

        return GestureDetector(
          onTap: canAfford && !_isLoading
              ? () => _sendGift(gift)
              : () => ErrorHandler.showError(context, '余额不足'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? gift.color.withOpacity(0.2)
                  : (canAfford ? Colors.white : Colors.grey[100]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? gift.color
                    : (canAfford ? Colors.grey[300]! : Colors.grey[200]!),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gift.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 礼物表情
                      AnimatedScale(
                        scale: isSelected ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          gift.emoji,
                          style: TextStyle(
                            fontSize: 28,
                            color: canAfford ? null : Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 礼物名称
                      Text(
                        gift.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: canAfford ? Colors.grey[800] : Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // 价格
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: canAfford
                              ? gift.color.withOpacity(0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '¥${gift.price.toStringAsFixed(gift.price == gift.price.roundToDouble() ? 0 : 1)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: canAfford ? gift.color : Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 加载指示器
                if (isSelected && _isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),

                // 买不起的遮罩
                if (!canAfford)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 礼物按钮组件（用于在帖子或评论中显示）
class GiftButton extends StatelessWidget {
  final String targetId;
  final String targetType;
  final String receiverId;
  final Function(Gift)? onGiftSent;
  final double size;

  const GiftButton({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.receiverId,
    this.onGiftSent,
    this.size = 32.0,
  });

  void _showGiftSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelector(
        targetId: targetId,
        targetType: targetType,
        receiverId: receiverId,
        onGiftSent: onGiftSent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGiftSelector(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.pink[50],
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: Colors.pink[200]!, width: 1),
        ),
        child: Icon(
          Icons.card_giftcard,
          size: size * 0.5,
          color: Colors.pink[400],
        ),
      ),
    );
  }
}