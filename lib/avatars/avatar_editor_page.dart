import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../services/avatar_service.dart';
import '../avatars/avatar_data.dart';

class AvatarEditorPage extends StatefulWidget {
  const AvatarEditorPage({Key? key}) : super(key: key);

  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  final AvatarService _avatarService = AvatarService();
  UserAvatar? _currentAvatar;
  List<AvatarOutfit>? _availableOutfits;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvatarData();
  }

  Future<void> _loadAvatarData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 从AuthService获取当前用户ID
      final userId = AuthService.currentUser;
      if (userId == null) {
        throw Exception('用户未登录');
      }
      
      // 获取用户当前形象
      final avatar = await _avatarService.getUserAvatar(userId);
      
      // 获取可用装扮列表
      final outfits = await _avatarService.getAvatarOutfits();

      setState(() {
        _currentAvatar = avatar;
        _availableOutfits = outfits;
      });
    } catch (e) {
      print('加载形象数据失败: $e');
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载形象数据失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAvatar() async {
    if (_currentAvatar == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 从AuthService获取当前用户ID
      final userId = AuthService.currentUser;
      if (userId == null) {
        throw Exception('用户未登录');
      }
      
      await _avatarService.updateUserAvatar(userId, _currentAvatar!);
      
      // 显示保存成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('形象保存成功！')),
      );
    } catch (e) {
      print('保存形象失败: $e');
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存形象失败: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _updateBaseConfig(BaseConfig newConfig) {
    setState(() {
      _currentAvatar = _currentAvatar?.copyWith(baseConfig: newConfig);
    });
  }

  void _updateCurrentOutfit(OutfitConfig newOutfit) {
    setState(() {
      _currentAvatar = _currentAvatar?.copyWith(currentOutfit: newOutfit);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑形象'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAvatar,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('保存'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentAvatar == null
              ? const Center(child: Text('加载形象失败'))
              : _buildEditorContent(),
    );
  }

  Widget _buildEditorContent() {
    return Row(
      children: [
        // 左侧：形象预览
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TODO: 实现形象渲染器
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.purple[200] ?? Colors.purple, width: 4),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 120,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '我的虚拟形象',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(),
        // 右侧：编辑面板
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBaseConfigEditor(),
                const SizedBox(height: 30),
                _buildOutfitSelector(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaseConfigEditor() {
    final baseConfig = _currentAvatar!.baseConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '基础配置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 15),
        // 脸型选择
        _buildOptionRow(
          label: '脸型',
          currentValue: baseConfig.faceShape,
          options: ['round', 'square', 'heart'],
          onOptionSelected: (value) {
            _updateBaseConfig(
              baseConfig.copyWith(faceShape: value),
            );
          },
        ),
        // 肤色选择
        _buildOptionRow(
          label: '肤色',
          currentValue: baseConfig.skinColor,
          options: ['light', 'medium', 'dark'],
          onOptionSelected: (value) {
            _updateBaseConfig(
              baseConfig.copyWith(skinColor: value),
            );
          },
        ),
        // 眼睛类型
        _buildOptionRow(
          label: '眼睛',
          currentValue: baseConfig.eyeType,
          options: ['cute', 'sharp', 'round'],
          onOptionSelected: (value) {
            _updateBaseConfig(
              baseConfig.copyWith(eyeType: value),
            );
          },
        ),
        // 发型
        _buildOptionRow(
          label: '发型',
          currentValue: baseConfig.hairStyle,
          options: ['short', 'long', 'curly'],
          onOptionSelected: (value) {
            _updateBaseConfig(
              baseConfig.copyWith(hairStyle: value),
            );
          },
        ),
        // 发色
        _buildOptionRow(
          label: '发色',
          currentValue: baseConfig.hairColor,
          options: ['black', 'brown', 'blonde', 'pink', 'blue'],
          onOptionSelected: (value) {
            _updateBaseConfig(
              baseConfig.copyWith(hairColor: value),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required String label,
    required String currentValue,
    required List<String> options,
    required Function(String) onOptionSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = currentValue == option;
            return GestureDetector(
              onTap: () => onOptionSelected(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildOutfitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '装扮选择',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 15),
        if (_availableOutfits == null || _availableOutfits!.isEmpty)
          const Center(child: Text('没有可用的装扮'))
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableOutfits!.length,
              itemBuilder: (context, index) {
                final outfit = _availableOutfits![index];
                final isOwned = _currentAvatar!.ownedOutfits.contains(outfit.id);
                final isEquipped = _currentAvatar!.currentOutfit.clothes == outfit.id;

                return Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: GestureDetector(
                    onTap: () {
                      if (isOwned) {
                        setState(() {
                          _currentAvatar!.currentOutfit = OutfitConfig(
                            clothes: outfit.id,
                            accessories: [],
                            background: '',
                          );
                        });
                      } else {
                        // TODO: 实现购买逻辑
                        _purchaseOutfit(outfit);
                      }
                    },
                    child: Container(
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isEquipped ? Colors.purple : (Colors.grey[200] ?? Colors.grey),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[200]!,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 装扮图片
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(13),
                                topRight: Radius.circular(13),
                              ),
                            ),
                            child: Center(
                              child: Image.network(
                                outfit.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outfit.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  outfit.isFree ? '免费' : '¥${outfit.price}',
                                  style: TextStyle(
                                    color: isOwned
                                        ? Colors.green
                                        : outfit.isFree
                                            ? Colors.black87
                                            : Colors.purple,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isEquipped)
                                  const SizedBox(
                                    height: 4,
                                  ),
                                if (isEquipped)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      '已装备',
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _purchaseOutfit(AvatarOutfit outfit) async {
    // TODO: 实现购买逻辑
    setState(() {
      _isLoading = true;
    });

    try {
      // 从AuthService获取当前用户ID
      final userId = AuthService.currentUser;
      if (userId == null) {
        throw Exception('用户未登录');
      }
      
      final result = await _avatarService.purchaseAvatarOutfit(outfit.id, userId);
      if (result != null) {
        // 购买成功，更新拥有的装扮列表
        setState(() {
          _currentAvatar!.ownedOutfits.add(outfit.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('购买 ${outfit.name} 成功！')),
        );
      }
    } catch (e) {
      print('购买失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('购买失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// 为UserAvatar添加copyWith方法
extension UserAvatarCopyWith on UserAvatar {
  UserAvatar copyWith({
    String? userId,
    BaseConfig? baseConfig,
    OutfitConfig? currentOutfit,
    List<String>? ownedOutfits,
  }) {
    return UserAvatar(
      userId: userId ?? this.userId,
      baseConfig: baseConfig ?? this.baseConfig,
      currentOutfit: currentOutfit ?? this.currentOutfit,
      ownedOutfits: ownedOutfits ?? this.ownedOutfits,
    );
  }
}

// 为BaseConfig添加copyWith方法
extension BaseConfigCopyWith on BaseConfig {
  BaseConfig copyWith({
    String? faceShape,
    String? skinColor,
    String? eyeType,
    String? hairStyle,
    String? hairColor,
  }) {
    return BaseConfig(
      faceShape: faceShape ?? this.faceShape,
      skinColor: skinColor ?? this.skinColor,
      eyeType: eyeType ?? this.eyeType,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
    );
  }
}
