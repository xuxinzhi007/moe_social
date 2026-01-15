import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/avatar_configuration.dart';

/// 虚拟形象预览组件
/// 将多个SVG图层叠加显示，形成完整的虚拟形象
class AvatarPreview extends StatelessWidget {
  final AvatarConfiguration configuration;
  final double size;

  const AvatarPreview({
    super.key,
    required this.configuration,
    this.size = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆圈
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue[50]!,
                  Colors.blue[100]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),

          // 虚拟形象图层
          SizedBox(
            width: size * 0.8,
            height: size * 0.8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. 脸部基础 (最底层)
                if (configuration.faceType.isNotEmpty)
                  _buildAvatarLayer(
                    'assets/avatars/faces/${configuration.faceType}.svg',
                    colorFilter: ColorFilter.mode(
                      _parseColor(configuration.skinColor),
                      BlendMode.modulate,
                    ),
                  ),

                // 2. 服装
                if (configuration.clothesStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'assets/avatars/clothes/${configuration.clothesStyle}.svg',
                  ),

                // 3. 头发 (在脸部之上，眼睛之下)
                if (configuration.hairStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'assets/avatars/hairs/${configuration.hairStyle}.svg',
                    colorFilter: ColorFilter.mode(
                      _parseColor(configuration.hairColor),
                      BlendMode.modulate,
                    ),
                  ),

                // 4. 眼睛 (在头发之上)
                if (configuration.eyeStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'assets/avatars/eyes/${configuration.eyeStyle}.svg',
                  ),

                // 5. 配饰 (最顶层)
                if (configuration.accessoryStyle.isNotEmpty && configuration.accessoryStyle != 'none')
                  _buildAvatarLayer(
                    'assets/avatars/accessories/${configuration.accessoryStyle}.svg',
                  ),
              ],
            ),
          ),

          // 装饰性光晕效果
          Positioned(
            top: size * 0.15,
            left: size * 0.15,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarLayer(String assetPath, {ColorFilter? colorFilter}) {
    return FutureBuilder<bool>(
      future: _assetExists(assetPath),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return SvgPicture.asset(
            assetPath,
            width: size * 0.8,
            height: size * 0.8,
            colorFilter: colorFilter,
            fit: BoxFit.contain,
          );
        } else {
          // 如果资源不存在，显示占位符
          return _buildPlaceholder();
        }
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size * 0.8,
      height: size * 0.8,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey[400],
        size: 32,
      ),
    );
  }

  /// 解析十六进制颜色字符串为Color对象
  Color _parseColor(String colorStr) {
    try {
      final hexColor = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      // 如果解析失败，返回默认颜色
      return Colors.grey;
    }
  }

  /// 检查资源文件是否存在
  /// 注意：在实际应用中，这个方法可能需要调整
  Future<bool> _assetExists(String assetPath) async {
    try {
      // 简化处理：假设基础资源都存在
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// 简化版的虚拟形象预览，用于头像显示
class AvatarMiniPreview extends StatelessWidget {
  final AvatarConfiguration configuration;
  final double radius;

  const AvatarMiniPreview({
    super.key,
    required this.configuration,
    this.radius = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue[50],
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: ClipOval(
        child: AvatarPreview(
          configuration: configuration,
          size: radius * 2,
        ),
      ),
    );
  }
}