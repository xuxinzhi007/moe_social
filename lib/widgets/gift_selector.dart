import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../auth_service.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';
import 'moe_loading.dart';
import 'gift_haptic.dart';
import 'gift_animation.dart';

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

class _GiftSelectorState extends State<GiftSelector> {
  bool _isLoading = false;
  double _userBalance = 0.0;
  Gift? _selectedGift;
  /// 后端 `/api/gifts` 全量列表（唯一数据源）
  List<Gift> _serverGifts = [];
  /// 已结束一次拉取（成功或失败）
  bool _giftCatalogResolved = false;

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
    _loadGiftCatalog();
  }

  Future<void> _loadGiftCatalog() async {
    try {
      final uid = AuthService.currentUser;
      final rows = await ApiService.getGifts(
        page: 1,
        pageSize: 80,
        viewerUserId: uid,
      );
      if (!mounted) return;
      final parsed = rows.map(Gift.fromCatalogApi).toList();
      if (parsed.isNotEmpty) {
        setState(() {
          _serverGifts = parsed;
          _giftCatalogResolved = true;
        });
      } else {
        setState(() {
          _serverGifts = [];
          _giftCatalogResolved = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverGifts = [];
          _giftCatalogResolved = true;
        });
      }
    }
  }

  Future<void> _purchaseGift(Gift gift) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      ErrorHandler.showError(context, '请先登录');
      return;
    }
    if (!gift.canSendViaBackendApi) return;
    if (_userBalance < gift.price) {
      ErrorHandler.showError(context, '余额不足，请先充值');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.purchaseGift(
        userId: userId,
        giftId: gift.id,
        quantity: 1,
      );
      await _loadGiftCatalog();
      final u = await ApiService.getUserInfo(userId);
      if (mounted) {
        setState(() => _userBalance = u.balance);
        ErrorHandler.showSuccess(context, '已购买 ${gift.name} ×1');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      debugPrint('加载用户余额失败: $e');
    }
  }

  Future<void> _sendGift(Gift gift) async {
    final userId = AuthService.currentUser;
    if (userId == null) {
      ErrorHandler.showError(context, '请先登录');
      return;
    }

    if (!gift.canSendViaBackendApi) {
      ErrorHandler.showError(context, '礼物数据异常，请下拉刷新礼物列表后重试。');
      return;
    }

    if (gift.ownedQuantity < 1) {
      ErrorHandler.showError(
        context,
        '背包里没有该礼物。请先在「心意」用余额购买，或点格子右下角 + 购买。',
      );
      return;
    }

    await GiftHapticFeedback.forGiftConfirmation(gift);

    setState(() {
      _isLoading = true;
      _selectedGift = gift;
    });

    try {
      await ApiService.sendGift(
        fromUserId: userId,
        toUserId: widget.receiverId,
        giftId: gift.id,
        quantity: 1,
      );

      await GiftHapticFeedback.forGiftSuccess(gift);

      final refreshed = await ApiService.getUserInfo(userId);
      if (mounted) {
        setState(() {
          _userBalance = refreshed.balance;
        });
        _showGiftSuccessAnimation(gift);
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

  void _showGiftSuccessAnimation(Gift gift) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (context) => Center(
        child: GiftSendAnimation(
          gift: gift,
          onAnimationComplete: () {
            Navigator.of(context).pop();
            ErrorHandler.showSuccess(context, '礼物发送成功！🎁');
            widget.onGiftSent?.call(gift);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
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
                  tooltip: '关闭',
                ),
              ],
            ),
          ),

          // 礼物列表（仅服务端 /api/gifts）
          Expanded(
            child: !_giftCatalogResolved
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MoeSmallLoading(size: 28),
                        SizedBox(height: 12),
                        Text('正在加载礼物…'),
                      ],
                    ),
                  )
                : _serverGifts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              const Text(
                                '未获取到礼物列表',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '请确认后端已启动且已同步礼物数据，然后重试。',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() => _giftCatalogResolved = false);
                                  _loadGiftCatalog();
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('重新加载'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildGiftGrid(_serverGifts),
          ),

          // 底部操作栏
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MoeSmallLoading(size: 22),
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
        final canBuyOne = _userBalance >= gift.price;
        final canSendOut =
            gift.canSendViaBackendApi && gift.ownedQuantity >= 1;
        final isSelected = _selectedGift?.id == gift.id;
        final backendOk = gift.canSendViaBackendApi;

        return GestureDetector(
          onTap: () {
            if (_isLoading) return;
            if (!backendOk) {
              ErrorHandler.showError(context, '礼物数据异常，请重新打开礼物面板。');
              return;
            }
            if (!canSendOut) {
              ErrorHandler.showError(
                context,
                '背包数量为 0，无法赠送。请点右下角 + 用心意余额购买后再送。',
              );
              return;
            }
            GiftHapticFeedback.forGiftSelection(gift);
            _sendGift(gift);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? gift.color.withValues(alpha: 0.2)
                  : (canSendOut ? Colors.white : Colors.grey[100]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? gift.color
                    : (canSendOut
                        ? Colors.grey[300]!
                        : Colors.grey[200]!),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gift.color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
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
                            color: canSendOut ? null : Colors.grey[400],
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
                          color:
                              canSendOut ? Colors.grey[800] : Colors.grey[400],
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
                          color: canBuyOne
                              ? gift.color.withValues(alpha: 0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '¥${gift.price.toStringAsFixed(gift.price == gift.price.roundToDouble() ? 0 : 1)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: canBuyOne ? gift.color : Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (backendOk)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.deepPurple.shade100, width: 0.5),
                      ),
                      child: Text(
                        '×${gift.ownedQuantity}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.deepPurple.shade800,
                        ),
                      ),
                    ),
                  ),

                if (backendOk)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isLoading
                            ? null
                            : () {
                                if (!canBuyOne) {
                                  ErrorHandler.showError(
                                      context, '余额不足，请先充值');
                                  return;
                                }
                                _purchaseGift(gift);
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: canBuyOne
                                ? const Color(0xFF7F7FD5).withValues(alpha: 0.15)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: canBuyOne
                                ? const Color(0xFF7F7FD5)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 加载指示器
                if (isSelected && _isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: MoeSmallLoading(size: 20),
                      ),
                    ),
                  ),

                // 背包为 0 时的弱提示（仍可点 + 购买）
                if (backendOk && !canSendOut)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
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
class GiftButton extends StatefulWidget {
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

  @override
  State<GiftButton> createState() => _GiftButtonState();
}

class _GiftButtonState extends State<GiftButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showGiftSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelector(
        targetId: widget.targetId,
        targetType: widget.targetType,
        receiverId: widget.receiverId,
        onGiftSent: widget.onGiftSent,
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    GiftHapticFeedback.light();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () => _showGiftSelector(context),
      onLongPress: () {
        GiftHapticFeedback.medium();
        _showGiftSelector(context);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _isPressed
                    ? Colors.pink[100]
                    : Colors.pink[50],
                borderRadius: BorderRadius.circular(widget.size / 2),
                border: Border.all(
                  color: _isPressed
                      ? Colors.pink[400]!
                      : Colors.pink[200]!,
                  width: 1,
                ),
                boxShadow: _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Icon(
                Icons.card_giftcard,
                size: widget.size * 0.5,
                color: _isPressed
                    ? Colors.pink[600]
                    : Colors.pink[400],
              ),
            ),
          );
        },
      ),
    );
  }
}
