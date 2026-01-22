import 'package:flutter/material.dart';
import 'models/user.dart';
import 'models/virtual_item.dart';
import 'widgets/dynamic_avatar.dart';
// import 'auth_service.dart';
import 'services/api_service.dart';

class InventoryPage extends StatefulWidget {
  final User user;
  final Function(User) onUserUpdate;

  const InventoryPage({super.key, required this.user, required this.onUserUpdate});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late User _currentUser;
  final List<VirtualItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    // 模拟从背包ID列表加载物品详情
    // 实际项目中应该调用 ApiService.getInventoryItems(ids)
    
    // 这里我们直接用 mockItems 匹配
    final allItems = VirtualItem.mockItems;
    final List<VirtualItem> loadedItems = [];
    
    // 去重显示，或者显示数量？
    // 这里简单去重显示
    final uniqueIds = _currentUser.inventory.toSet();
    
    for (var id in uniqueIds) {
      try {
        final item = allItems.firstWhere((e) => e.id == id);
        loadedItems.add(item);
      } catch (e) {
        // item not found
      }
    }
    
    if (mounted) {
      setState(() {
        _items.clear();
        _items.addAll(loadedItems);
        _isLoading = false;
      });
    }
  }

  Future<void> _equipItem(String itemId) async {
    try {
      final updatedUser = await ApiService.updateUserInfo(
        _currentUser.id,
        equippedFrameId: itemId,
      );
      
      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
        });
        
        widget.onUserUpdate(_currentUser);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('佩戴成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('佩戴失败: $e')),
        );
      }
    }
  }

  Future<void> _unequipItem() async {
    try {
      final updatedUser = await ApiService.updateUserInfo(
        _currentUser.id, 
        clearEquippedFrame: true
      );
      
      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
        });
        widget.onUserUpdate(_currentUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已卸下头像框')),
        );
      }
    } catch (e) {
      // 如果API失败，本地回退或者提示
      print('卸下失败: $e');
      if (mounted) {
        // 尝试本地更新作为降级方案
        setState(() {
          _currentUser = _currentUser.copyWith(clearEquippedFrame: true);
        });
        widget.onUserUpdate(_currentUser);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: const Text('我的背包', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // 顶部展示当前形象
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                DynamicAvatar(
                  avatarUrl: _currentUser.avatar,
                  size: 80,
                  frameId: _currentUser.equippedFrameId,
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser.username,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_currentUser.equippedFrameId != null)
                      OutlinedButton(
                        onPressed: _unequipItem,
                        child: const Text('卸下头像框'),
                      )
                    else
                      const Text('暂未佩戴头像框', style: TextStyle(color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 物品列表
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty 
                ? const Center(child: Text('背包空空如也，快去抽奖吧！'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isEquipped = item.id == _currentUser.equippedFrameId;
                      
                      return GestureDetector(
                        onTap: () {
                          if (item.type == ItemType.avatarFrame) {
                            if (!isEquipped) {
                              _equipItem(item.id);
                            }
                          } else {
                            // 其他类型物品详情
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('选择了: ${item.name}')),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isEquipped ? Colors.orange : Colors.grey[200]!,
                              width: isEquipped ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isEquipped)
                                const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.check_circle, color: Colors.orange, size: 16),
                                  ),
                                ),
                              Expanded(
                                child: Center(
                                  child: item.type == ItemType.avatarFrame
                                    ? SizedBox(
                                        width: 50, 
                                        height: 50, 
                                        child: DynamicAvatar(avatarUrl: _currentUser.avatar, size: 50, frameId: item.id)
                                      )
                                    : Icon(Icons.card_giftcard, size: 40, color: Color(item.rarityColor)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      item.rarityLabel,
                                      style: TextStyle(
                                        color: Color(item.rarityColor), 
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.type == ItemType.avatarFrame && !isEquipped)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '点击佩戴',
                                      style: TextStyle(fontSize: 10, color: Colors.orange),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
