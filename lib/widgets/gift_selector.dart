import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../auth_service.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';
import 'moe_loading.dart';
import 'gift_haptic.dart';
import 'gift_animation_manager.dart';
import '../pages/commerce/wallet_page.dart';

class GiftSelector extends StatefulWidget {
  final String targetId;
  final String targetType;
  final String receiverId;
  final Function(Gift)? onGiftSent;

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
    with SingleTickerProviderStateMixin {
  Gift? _previewGift;     // first-tap preview state
  Gift? _sendingGift;
  double _userBalance = 0.0;
  List<Gift> _serverGifts = [];
  bool _giftCatalogResolved = false;
  int _comboCount = 0;
  DateTime? _lastSendTime;
  static const _comboTimeout = Duration(seconds: 2);
  bool _isSending = false;
  late TabController _tabController;

  List<Gift> get _backpackGifts =>
      _serverGifts.where((g) => g.ownedQuantity >= 1).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserBalance();
    _loadGiftCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      setState(() {
        _serverGifts = parsed;
        _giftCatalogResolved = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverGifts = [];
          _giftCatalogResolved = true;
        });
      }
    }
  }

  Future<void> _loadUserBalance() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;
    try {
      final user = await ApiService.getUserInfo(userId);
      if (mounted) setState(() => _userBalance = user.balance);
    } catch (_) {}
  }

  void _updateCombo() {
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _comboTimeout) {
      _comboCount++;
    } else {
      _comboCount = 1;
    }
    _lastSendTime = now;
  }

  // First tap: show preview. Second tap on same gift: send.
  void _handleTap(Gift gift) {
    if (_isSending) return;
    if (!gift.canSendViaBackendApi) {
      ErrorHandler.showError(context, '礼物数据异常，请下拉刷新后重试。');
      return;
    }
    final hasStock = gift.ownedQuantity >= 1;
    final canPay = _userBalance + 1e-9 >= gift.price;
    if (!hasStock && !canPay) {
      ErrorHandler.showError(context, '背包没有该礼物且余额不足，请先充值。');
      return;
    }
    GiftHapticFeedback.forGiftSelection(gift);
    if (_previewGift?.id == gift.id) {
      // second tap → send
      setState(() => _previewGift = null);
      _sendGift(gift);
    } else {
      setState(() => _previewGift = gift);
    }
  }

  void _handleLongPress(Gift gift) {
    if (_isSending) return;
    if (!gift.canSendViaBackendApi) return;
    final hasStock = gift.ownedQuantity >= 1;
    final canPay = _userBalance + 1e-9 >= gift.price;
    if (!hasStock && !canPay) return;
    GiftHapticFeedback.forGiftConfirmation(gift);
    setState(() => _previewGift = null);
    _sendGift(gift);
  }

  Future<void> _sendGift(Gift gift) async {
    final userId = AuthService.currentUser;
    if (userId == null) return;
    if (_isSending) return;

    final hasStock = gift.ownedQuantity >= 1;

    setState(() {
      _isSending = true;
      _sendingGift = gift;
      _updateCombo();
      if (hasStock) {
        _serverGifts = [
          for (final g in _serverGifts)
            if (g.id == gift.id)
              g.copyWith(ownedQuantity: (g.ownedQuantity - 1).clamp(0, 999999))
            else
              g,
        ];
      } else {
        _userBalance = (_userBalance - gift.price).clamp(0.0, 1e15);
      }
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
      if (mounted) setState(() => _userBalance = refreshed.balance);
      await _loadGiftCatalog();
      if (mounted) {
        GiftAnimationManager().showGiftAnimation(context, gift,
            comboCount: _comboCount);
        widget.onGiftSent?.call(gift);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (hasStock) {
            _serverGifts = [
              for (final g in _serverGifts)
                if (g.id == gift.id)
                  g.copyWith(ownedQuantity: g.ownedQuantity + 1)
                else
                  g,
            ];
          } else {
            _userBalance += gift.price;
          }
        });
        ErrorHandler.handleException(context, e as Exception);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendingGift = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: screenH * 0.58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              _buildTabBar(),
              Expanded(child: _buildTabContent()),
              if (_isSending) _buildSendingBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        children: [
          const Text(
            '送礼物',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          if (_comboCount > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFAD00)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_comboCount}x 连击 🔥',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const Spacer(),
          _buildBalanceChip(),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: Colors.grey[600]),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WalletPage()));
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_rounded,
                size: 14, color: Color(0xFFE65100)),
            const SizedBox(width: 4),
            Text(
              '¥${_userBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFBF360C),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.add_circle_outline_rounded,
                size: 12, color: Color(0xFFE65100)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_rounded, size: 14),
                const SizedBox(width: 4),
                const Text('全部'),
                if (!_giftCatalogResolved)
                  const SizedBox(width: 4),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.backpack_rounded, size: 14),
                const SizedBox(width: 4),
                Text(
                  _backpackGifts.isEmpty
                      ? '背包'
                      : '背包 (${_backpackGifts.length})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (!_giftCatalogResolved) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MoeSmallLoading(size: 28),
            SizedBox(height: 12),
            Text('加载礼物中…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _serverGifts.isEmpty
            ? _buildEmptyState()
            : _buildGiftGrid(_serverGifts),
        _backpackGifts.isEmpty
            ? _buildBackpackEmpty()
            : _buildGiftGrid(_backpackGifts),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('未能获取礼物列表',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text('请确认网络连接后重试',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
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
    );
  }

  Widget _buildBackpackEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎒', style: TextStyle(fontSize: 48, color: Colors.grey[300])),
            const SizedBox(height: 12),
            const Text('背包是空的',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text('在"全部"中先从余额送出，或前往钱包充值购买',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.store_rounded, size: 16),
              label: const Text('浏览全部礼物'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftGrid(List<Gift> gifts) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) => _buildGiftCard(gifts[index]),
    );
  }

  Widget _buildGiftCard(Gift gift) {
    final hasStock = gift.ownedQuantity >= 1;
    final canPay = _userBalance + 1e-9 >= gift.price;
    final canSend = gift.canSendViaBackendApi && (hasStock || canPay);
    final isPreviewing = _previewGift?.id == gift.id;
    final isSending = _sendingGift?.id == gift.id;

    return GestureDetector(
      onTap: canSend ? () => _handleTap(gift) : null,
      onLongPress: canSend ? () => _handleLongPress(gift) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: isPreviewing
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gift.color.withValues(alpha: 0.25),
                    gift.color.withValues(alpha: 0.10),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: canSend
                      ? [Colors.white, Colors.grey.shade50]
                      : [Colors.grey.shade100, Colors.grey.shade100],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPreviewing
                ? gift.color
                : canSend
                    ? Colors.grey.shade200
                    : Colors.grey.shade200,
            width: isPreviewing ? 2 : 1,
          ),
          boxShadow: isPreviewing
              ? [
                  BoxShadow(
                    color: gift.color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: AnimatedScale(
                          scale: isPreviewing ? 1.22 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.elasticOut,
                          child: Text(
                            gift.emoji,
                            style: TextStyle(
                              fontSize: 38,
                              color: canSend ? null : Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      gift.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: canSend
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Center(child: _buildPriceTag(gift, hasStock, canPay)),
                  ],
                ),
              ),

              // 背包数量角标
              if (hasStock)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${gift.ownedQuantity}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // 豪华徽章
              if (gift.level == GiftLevel.luxury)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('👑',
                        style: TextStyle(fontSize: 8)),
                  ),
                ),

              // 发送中蒙层
              if (isSending)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: MoeSmallLoading(size: 18)),
                  ),
                ),

              // 预览提示
              if (isPreviewing && !isSending)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: gift.color,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14)),
                    ),
                    child: const Text(
                      '再点送出',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceTag(Gift gift, bool hasStock, bool canPay) {
    if (hasStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '¥${_priceText(gift.price)} 背包',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7C3AED),
          ),
        ),
      );
    }
    if (canPay) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: gift.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '¥${_priceText(gift.price)}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: gift.color,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '¥${_priceText(gift.price)}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  String _priceText(double price) {
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    }
    return price.toStringAsFixed(1);
  }

  Widget _buildSendingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        border: Border(top: BorderSide(color: Colors.pink.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MoeSmallLoading(size: 18),
          const SizedBox(width: 10),
          Text(
            _sendingGift != null
                ? '正在送出 ${_sendingGift!.emoji} ${_sendingGift!.name}…'
                : '发送中…',
            style: TextStyle(
              color: Colors.pink.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (_comboCount > 1)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '($_comboCount连击)',
                style: TextStyle(
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────
/// GiftButton — entry point to open the selector sheet
/// ────────────────────────────────────────────────────────
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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showGiftSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => GiftSelector(
        targetId: widget.targetId,
        targetType: widget.targetType,
        receiverId: widget.receiverId,
        onGiftSent: widget.onGiftSent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        GiftHapticFeedback.light();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: _showGiftSelector,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (_, __) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFC6076), Color(0xFFFF9A44)],
              ),
              borderRadius: BorderRadius.circular(widget.size / 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFC6076).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              size: widget.size * 0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
