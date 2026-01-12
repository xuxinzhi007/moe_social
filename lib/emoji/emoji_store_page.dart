import 'package:flutter/material.dart';
import '../services/emoji_service.dart';
import '../emoji/emoji_data.dart';

class EmojiStorePage extends StatefulWidget {
  const EmojiStorePage({Key? key}) : super(key: key);

  @override
  State<EmojiStorePage> createState() => _EmojiStorePageState();
}

class _EmojiStorePageState extends State<EmojiStorePage> {
  final EmojiService _emojiService = EmojiService();
  List<EmojiPack>? _emojiPacks;
  List<EmojiPack>? _userEmojiPacks;
  String? _selectedCategory;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadEmojiPacks();
    _loadUserEmojiPacks();
  }

  Future<void> _loadEmojiPacks({bool isLoadMore = false}) async {
    if (_isLoading || (_isLoadingMore && isLoadMore)) return;

    setState(() {
      if (isLoadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      }
    });

    try {
      final packs = await _emojiService.getEmojiPacks(
        category: _selectedCategory,
        page: isLoadMore ? _currentPage + 1 : 1,
        pageSize: 10,
      );

      setState(() {
        if (isLoadMore) {
          _emojiPacks = [...(_emojiPacks ?? []), ...(packs ?? [])];
          _currentPage++;
          _hasMore = packs?.length == 10;
        } else {
          _emojiPacks = packs;
        }
      });
    } catch (e) {
      print('加载表情包包失败: $e');
      // TODO: 显示错误提示
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadUserEmojiPacks() async {
    try {
      // TODO: 从AuthService获取当前用户ID
      final userId = 'current_user_id';
      
      final packs = await _emojiService.getUserEmojiPacks(userId);
      setState(() {
        _userEmojiPacks = packs;
      });
    } catch (e) {
      print('加载用户表情包包失败: $e');
      // TODO: 显示错误提示
    }
  }

  Future<void> _purchaseEmojiPack(EmojiPack pack) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 从AuthService获取当前用户ID
      final userId = 'current_user_id';
      
      final result = await _emojiService.purchaseEmojiPack(pack.id, userId);
      if (result != null) {
        // 购买成功，重新加载用户表情包包列表
        await _loadUserEmojiPacks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('购买 ${pack.name} 成功！')),
        );
      }
    } catch (e) {
      print('购买表情包包失败: $e');
      // TODO: 显示错误提示
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _favoriteEmojiPack(EmojiPack pack) async {
    try {
      // TODO: 从AuthService获取当前用户ID
      final userId = 'current_user_id';
      
      final success = await _emojiService.favoriteEmojiPack(pack.id, userId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏 ${pack.name} 成功！')),
        );
      }
    } catch (e) {
      print('收藏表情包包失败: $e');
      // TODO: 显示错误提示
    }
  }

  bool _isPackOwned(String packId) {
    return _userEmojiPacks?.any((pack) => pack.id == packId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('表情包商店'),
      ),
      body: _isLoading && _emojiPacks == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCategoryFilter(),
                Expanded(
                  child: _emojiPacks == null || _emojiPacks!.isEmpty
                      ? const Center(child: Text('没有可用的表情包包'))
                      : ListView.builder(
                          itemCount: _emojiPacks!.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _emojiPacks!.length) {
                              if (_isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              } else if (_hasMore) {
                                // 加载更多
                                _loadEmojiPacks(isLoadMore: true);
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              } else {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: Text('已经到底啦')),
                                );
                              }
                            }

                            final pack = _emojiPacks![index];
                            final isOwned = _isPackOwned(pack.id);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 封面图
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            image: DecorationImage(
                                              image: NetworkImage(pack.coverImage),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    pack.name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (isOwned)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Text(
                                                        '已拥有',
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                pack.authorName,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                pack.description,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.download_outlined,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${pack.downloadCount} 下载',
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    pack.isFree ? '免费' : '¥${pack.price}',
                                                    style: TextStyle(
                                                      color: pack.isFree
                                                          ? Colors.black87
                                                          : Colors.purple,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // 表情包预览
                                    SizedBox(
                                      height: 60,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: pack.emojis.length > 5
                                            ? 5
                                            : pack.emojis.length,
                                        itemBuilder: (context, emojiIndex) {
                                          final emoji = pack.emojis[emojiIndex];
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Image.network(
                                              emoji.imageUrl,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // 操作按钮
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (!isOwned)
                                          TextButton.icon(
                                            onPressed: () => _purchaseEmojiPack(pack),
                                            icon: const Icon(Icons.shopping_cart_outlined),
                                            label: Text(pack.isFree ? '下载' : '购买'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.purple,
                                            ),
                                          ),
                                        TextButton.icon(
                                          onPressed: () => _favoriteEmojiPack(pack),
                                          icon: const Icon(Icons.favorite_border_outlined),
                                          label: const Text('收藏'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.pink,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            // TODO: 查看详情
                                          },
                                          icon: const Icon(Icons.info_outline),
                                          label: const Text('详情'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey[600],
                                          ),
                                        ),
                                      ],
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

  Widget _buildCategoryFilter() {
    final categories = ['全部', '萌系', '搞怪', '动漫', '游戏', '节日'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category ||
              (category == '全部' && _selectedCategory == null);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected && category != '全部' ? category : null;
                });
                _loadEmojiPacks();
              },
              selectedColor: Colors.purple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
