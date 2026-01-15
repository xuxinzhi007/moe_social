import 'dart:convert';
import 'package:flutter/services.dart';

/// 虚拟形象资源管理服务
/// 动态读取assets文件夹中的SVG文件，无需手动维护文件列表
class AvatarAssetService {
  static AvatarAssetService? _instance;
  static AvatarAssetService get instance => _instance ??= AvatarAssetService._();
  AvatarAssetService._();

  // 缓存的资源列表
  Map<String, List<String>>? _cachedAssets;

  /// 获取所有可用的avatar组件选项
  Future<Map<String, List<String>>> getAvailableOptions() async {
    if (_cachedAssets != null) {
      return _cachedAssets!;
    }

    try {
      // 读取assets清单
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final Map<String, List<String>> options = {
        'faces': [],
        'hairs': [],
        'eyes': [],
        'clothes': [],
        'accessories': ['none'], // 始终包含"无配饰"选项
      };

      // 扫描所有assets文件
      for (final String key in manifestMap.keys) {
        if (key.startsWith('assets/avatars/') && key.endsWith('.svg')) {
          final parts = key.split('/');
          if (parts.length >= 4) {
            final category = parts[2]; // faces, hairs, eyes, clothes, accessories
            final fileName = parts[3].replaceAll('.svg', ''); // 去掉扩展名

            if (options.containsKey(category)) {
              options[category]!.add(fileName);
            }
          }
        }
      }

      // 对每个分类进行排序
      for (final category in options.keys) {
        final files = options[category]!;
        if (category != 'accessories') {
          files.sort();
        } else {
          // accessories保持'none'在第一位，其余排序
          final List<String> sorted = files.where((f) => f != 'none').toList();
          sorted.sort();
          options[category] = ['none', ...sorted];
        }
      }

      _cachedAssets = options;
      return options;
    } catch (e) {
      print('读取avatar资源失败: $e');
      // 返回默认选项作为后备
      return _getDefaultOptions();
    }
  }

  /// 检查指定的SVG文件是否存在
  Future<bool> assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取指定分类的所有选项
  Future<List<String>> getCategoryOptions(String category) async {
    final options = await getAvailableOptions();
    return options[category] ?? [];
  }

  /// 清除缓存，强制重新读取资源
  void clearCache() {
    _cachedAssets = null;
  }

  /// 默认选项（作为后备）
  Map<String, List<String>> _getDefaultOptions() {
    return {
      'faces': ['face_1', 'face_2', 'face_3'],
      'hairs': ['hair_1', 'hair_2', 'hair_3', 'hair_4'],
      'eyes': ['eyes_1', 'eyes_2', 'eyes_3'],
      'clothes': ['clothes_1', 'clothes_2', 'clothes_3', 'clothes_4'],
      'accessories': ['none', 'glasses_1', 'glasses_2', 'hat_1'],
    };
  }

  /// 获取资源统计信息（用于调试）
  Future<Map<String, int>> getAssetStats() async {
    final options = await getAvailableOptions();
    return options.map((key, value) => MapEntry(key, value.length));
  }

  /// 打印所有检测到的SVG文件（调试用）
  Future<void> printAllAssets() async {
    final options = await getAvailableOptions();
    print('🎨 检测到的虚拟形象资源:');
    for (final category in options.keys) {
      final files = options[category]!;
      print('  $category (${files.length}个): ${files.join(', ')}');
    }
    final stats = await getAssetStats();
    final total = stats.values.fold(0, (a, b) => a + b);
    print('📊 总计: $total 个选项');
  }
}