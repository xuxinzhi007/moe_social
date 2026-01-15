import 'package:flutter/material.dart';
import 'models/avatar_configuration.dart';
import 'widgets/avatar_preview.dart';
import 'widgets/component_selector.dart';
import 'widgets/color_selector.dart';
import 'services/avatar_service.dart';
import 'services/avatar_asset_service.dart';
import 'avatars/avatar_data.dart';
import 'auth_service.dart';

class AvatarEditorPage extends StatefulWidget {
  final AvatarConfiguration? initialConfig;

  const AvatarEditorPage({super.key, this.initialConfig});

  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  late AvatarConfiguration _currentConfig;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isLoading = false;
  Map<String, List<String>> _availableOptions = {};

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.initialConfig ?? const AvatarConfiguration();
    _initializeAvatar();
  }

  /// 初始化虚拟形象数据
  Future<void> _initializeAvatar() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 并行加载动态选项和现有配置
      await Future.wait([
        _loadAvailableOptions(),
        if (widget.initialConfig == null) _loadExistingAvatar(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 加载可用选项
  Future<void> _loadAvailableOptions() async {
    try {
      final options = await AvatarAssetService.instance.getAvailableOptions();

      // 调试：打印检测到的资源
      await AvatarAssetService.instance.printAllAssets();

      if (mounted) {
        setState(() {
          _availableOptions = options;
        });
      }
    } catch (e) {
      print('加载虚拟形象选项失败: $e');
      // 使用默认选项作为后备
      setState(() {
        _availableOptions = {
          'faces': ['face_1', 'face_2', 'face_3'],
          'hairs': ['hair_1', 'hair_2', 'hair_3', 'hair_4'],
          'eyes': ['eyes_1', 'eyes_2', 'eyes_3'],
          'clothes': ['clothes_1', 'clothes_2', 'clothes_3', 'clothes_4'],
          'accessories': ['none', 'glasses_1', 'glasses_2', 'hat_1'],
        };
      });
    }
  }

  // 从后端UserAvatar格式转换为AvatarConfiguration
  AvatarConfiguration _convertFromUserAvatar(UserAvatar userAvatar) {
    return AvatarConfiguration(
      faceType: userAvatar.baseConfig.faceShape,
      hairStyle: userAvatar.baseConfig.hairStyle,
      eyeStyle: userAvatar.baseConfig.eyeType,
      clothesStyle: userAvatar.currentOutfit.clothes,
      accessoryStyle: userAvatar.currentOutfit.accessories.isNotEmpty
          ? userAvatar.currentOutfit.accessories.first
          : '',
      hairColor: userAvatar.baseConfig.hairColor,
      skinColor: userAvatar.baseConfig.skinColor,
    );
  }

  // 加载用户现有的虚拟形象配置
  Future<void> _loadExistingAvatar() async {
    try {
      final userId = await AuthService.getUserId();
      final avatarService = AvatarService();
      final userAvatar = await avatarService.getUserAvatar(userId);

      if (userAvatar != null && mounted) {
        setState(() {
          _currentConfig = _convertFromUserAvatar(userAvatar);
          _hasChanges = false;
        });
      }
    } catch (e) {
      // 如果加载失败，使用默认配置，不显示错误（用户可能是第一次使用）
      print('加载虚拟形象配置失败: $e');
    }
  }

  void _updateConfig(AvatarConfiguration newConfig) {
    setState(() {
      _currentConfig = newConfig;
      _hasChanges = newConfig != widget.initialConfig;
    });
  }

  // 将AvatarConfiguration转换为后端期望的UserAvatar格式
  UserAvatar _convertToUserAvatar(AvatarConfiguration config, String userId) {
    return UserAvatar(
      userId: userId,
      baseConfig: BaseConfig(
        faceShape: config.faceType.isEmpty ? 'face_1' : config.faceType,
        skinColor: config.skinColor,
        eyeType: config.eyeStyle.isEmpty ? 'eyes_1' : config.eyeStyle,
        hairStyle: config.hairStyle.isEmpty ? 'hair_1' : config.hairStyle,
        hairColor: config.hairColor,
      ),
      currentOutfit: OutfitConfig(
        clothes: config.clothesStyle.isEmpty ? 'clothes_1' : config.clothesStyle,
        accessories: config.accessoryStyle.isEmpty ? [] : [config.accessoryStyle],
        background: 'default',
      ),
      ownedOutfits: [], // 用户拥有的装扮物品，默认为空
    );
  }

  Future<void> _saveAvatar() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // 获取当前用户ID
      final userId = await AuthService.getUserId();

      // 转换配置格式
      final userAvatar = _convertToUserAvatar(_currentConfig, userId);

      // 保存到服务器
      final avatarService = AvatarService();
      final result = await avatarService.updateUserAvatar(userId, userAvatar);

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('虚拟形象保存成功！'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _hasChanges = false; // 保存成功后重置更改状态
        });
        Navigator.pop(context, _currentConfig);
      } else if (mounted) {
        throw Exception('服务器返回空结果');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '保存失败';
        if (e.toString().contains('用户未登录')) {
          errorMessage = '用户未登录，请先登录';
        } else if (e.toString().contains('网络')) {
          errorMessage = '网络连接失败，请检查网络';
        } else {
          errorMessage = '保存失败: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置虚拟形象'),
        content: const Text('确定要重置为默认形象吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _updateConfig(const AvatarConfiguration());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '编辑虚拟形象',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.refresh),
            tooltip: '重置',
          ),
          const SizedBox(width: 8),
          _isSaving || _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _hasChanges && !_isLoading ? _saveAvatar : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _hasChanges && !_isLoading ? Colors.blue : Colors.grey,
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 响应式布局计算
          final isSmallScreen = constraints.maxHeight < 600;
          final previewHeight = isSmallScreen ? 200.0 : 280.0;

          return Column(
            children: [
              // 预览区域 - 响应式高度
              Container(
                width: double.infinity,
                height: previewHeight,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              '加载虚拟形象中...',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : AvatarPreview(
                        configuration: _currentConfig,
                        size: previewHeight - 32, // 减去padding
                      ),
              ),

              // 编辑面板 - 使用Flexible而不是Expanded
              Flexible(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : DefaultTabController(
                length: 6,
                child: Column(
                  children: [
                    // Tab选项卡
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 0.2),
                        ),
                      ),
                      child: TabBar(
                        isScrollable: true,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue,
                        tabs: const [
                          Tab(icon: Icon(Icons.face, size: 20), text: '脸型'),
                          Tab(icon: Icon(Icons.content_cut, size: 20), text: '发型'),
                          Tab(icon: Icon(Icons.visibility, size: 20), text: '眼睛'),
                          Tab(icon: Icon(Icons.checkroom, size: 20), text: '服装'),
                          Tab(icon: Icon(Icons.face_retouching_natural, size: 20), text: '配饰'),
                          Tab(icon: Icon(Icons.palette, size: 20), text: '颜色'),
                        ],
                      ),
                    ),

                    // Tab内容区域 - 使用Flexible避免溢出
                    Flexible(
                      child: TabBarView(
                        children: [
                          // 脸型选择
                          ComponentSelector(
                            title: '选择脸型',
                            currentValue: _currentConfig.faceType,
                            options: _availableOptions['faces'] ?? ['face_1'],
                            assetBasePath: 'assets/avatars/faces/',
                            onChanged: (value) {
                              _updateConfig(_currentConfig.copyWith(faceType: value));
                            },
                          ),

                          // 发型选择
                          ComponentSelector(
                            title: '选择发型',
                            currentValue: _currentConfig.hairStyle,
                            options: _availableOptions['hairs'] ?? ['hair_1'],
                            assetBasePath: 'assets/avatars/hairs/',
                            onChanged: (value) {
                              _updateConfig(_currentConfig.copyWith(hairStyle: value));
                            },
                          ),

                          // 眼睛选择
                          ComponentSelector(
                            title: '选择眼型',
                            currentValue: _currentConfig.eyeStyle,
                            options: _availableOptions['eyes'] ?? ['eyes_1'],
                            assetBasePath: 'assets/avatars/eyes/',
                            onChanged: (value) {
                              _updateConfig(_currentConfig.copyWith(eyeStyle: value));
                            },
                          ),

                          // 服装选择
                          ComponentSelector(
                            title: '选择服装',
                            currentValue: _currentConfig.clothesStyle,
                            options: _availableOptions['clothes'] ?? ['clothes_1'],
                            assetBasePath: 'assets/avatars/clothes/',
                            onChanged: (value) {
                              _updateConfig(_currentConfig.copyWith(clothesStyle: value));
                            },
                          ),

                          // 配饰选择
                          ComponentSelector(
                            title: '选择配饰',
                            currentValue: _currentConfig.accessoryStyle,
                            options: _availableOptions['accessories'] ?? ['none'],
                            assetBasePath: 'assets/avatars/accessories/',
                            onChanged: (value) {
                              _updateConfig(_currentConfig.copyWith(accessoryStyle: value));
                            },
                          ),

                          // 颜色选择
                          SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 肤色选择
                                  const Text(
                                    '肤色',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ColorSelector(
                                    colors: AvatarConfiguration.skinColors,
                                    currentColor: _currentConfig.skinColor,
                                    onChanged: (color) {
                                      _updateConfig(_currentConfig.copyWith(skinColor: color));
                                    },
                                  ),

                                  const SizedBox(height: 24),

                                  // 发色选择
                                  const Text(
                                    '发色',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ColorSelector(
                                    colors: AvatarConfiguration.hairColors,
                                    currentColor: _currentConfig.hairColor,
                                    onChanged: (color) {
                                      _updateConfig(_currentConfig.copyWith(hairColor: color));
                                    },
                                  ),

                                  // 添加一些底部间距，避免内容被截断
                                  const SizedBox(height: 40),
                                ],
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
          ),

          // 底部安全区域 - 给TabBarView留出空间
          const SizedBox(height: 16),
        ],
      );
    },
  ),
      // 底部保存按钮 - 使用bottomNavigationBar避免溢出
      bottomNavigationBar: _isLoading
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _hasChanges && !_isSaving && !_isLoading ? _saveAvatar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasChanges && !_isLoading ? Colors.blue : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isLoading ? '加载中...' : '保存虚拟形象',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}