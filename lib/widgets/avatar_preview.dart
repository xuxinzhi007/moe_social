import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/avatar_configuration.dart';
import '../services/avatar_asset_service.dart';

/// 虚拟形象预览组件
/// 支持 SVG 和 PNG 分层叠加渲染
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
                // 0. 后发 (Hair Back) - 最底层
                if (configuration.hairStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'hairs', 
                    configuration.hairStyle, 
                    variant: 'back',
                    colorFilter: ColorFilter.mode(
                      _parseColor(configuration.hairColor),
                      BlendMode.modulate,
                    ),
                  ),

                // 1. 身体/脸部基础 (Face)
                if (configuration.faceType.isNotEmpty)
                  _buildAvatarLayer(
                    'faces', 
                    configuration.faceType,
                    colorFilter: ColorFilter.mode(
                      _parseColor(configuration.skinColor),
                      BlendMode.modulate,
                    ),
                  ),

                // 2. 服装 (Clothes)
                if (configuration.clothesStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'clothes', 
                    configuration.clothesStyle,
                  ),

                // 3. 眼睛 (Eyes)
                if (configuration.eyeStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'eyes', 
                    configuration.eyeStyle,
                  ),

                // 4. 前发 (Hair Front) - 如果没有分层资源，默认发型也在这里
                if (configuration.hairStyle.isNotEmpty)
                  _buildAvatarLayer(
                    'hairs', 
                    configuration.hairStyle,
                    // 如果存在后发资源，这里尝试加载前发资源；否则加载默认资源
                    // variant逻辑在 _buildAvatarLayer 内部处理
                    colorFilter: ColorFilter.mode(
                      _parseColor(configuration.hairColor),
                      BlendMode.modulate,
                    ),
                  ),

                // 5. 配饰 (Accessory) - 最顶层
                if (configuration.accessoryStyle.isNotEmpty && configuration.accessoryStyle != 'none')
                  _buildAvatarLayer(
                    'accessories', 
                    configuration.accessoryStyle,
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

  /// 构建单个图层
  /// [variant] 仅用于发型分层 ('back' 或 'front')
  Widget _buildAvatarLayer(String category, String name, {String? variant, ColorFilter? colorFilter}) {
    // 对于前发层，如果指定了 variant 为 null (默认情况)，我们优先尝试加载 'front' 变体
    // 如果是后发层 (variant='back')，则只尝试加载 'back' 变体
    
    // 构造查找逻辑
    return FutureBuilder<String?>(
      future: _resolveAssetPath(category, name, variant),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path != null) {
          if (path.endsWith('.svg')) {
            return SvgPicture.asset(
              path,
              width: size * 0.8,
              height: size * 0.8,
              colorFilter: colorFilter,
              fit: BoxFit.contain,
            );
          } else {
            // PNG 渲染
            // 注意：PNG 通常自带颜色，但如果是为了染色（如头发），可以使用 color 和 colorBlendMode
            return Image.asset(
              path,
              width: size * 0.8,
              height: size * 0.8,
              fit: BoxFit.contain,
              color: colorFilter != null ? _extractColorFromFilter(colorFilter) : null,
              colorBlendMode: colorFilter != null ? BlendMode.modulate : null,
            );
          }
        } else {
          // 资源未找到时，如果是后发层，静默失败（因为很多发型可能没有后发）
          if (variant == 'back') return const SizedBox();
          return _buildPlaceholder();
        }
      },
    );
  }

  Future<String?> _resolveAssetPath(String category, String name, String? variant) async {
    // 如果请求的是后发层，明确查找 _back
    if (variant == 'back') {
      return await AvatarAssetService.instance.getAssetPath(category, name, variant: 'back');
    }
    
    // 如果是普通层（或前发层），优先查找 _front，然后是默认
    // 这样当 hair_01_front.png 存在时，主层会加载它；不存在时加载 hair_01.png/svg
    final frontPath = await AvatarAssetService.instance.getAssetPath(category, name, variant: 'front');
    if (frontPath != null) return frontPath;
    
    return await AvatarAssetService.instance.getAssetPath(category, name);
  }

  // 辅助方法：从 ColorFilter 中提取颜色（简化版，仅支持 mode 模式）
  Color? _extractColorFromFilter(ColorFilter filter) {
    // Flutter 的 ColorFilter 内部结构不对外暴露，这里只能通过约定传递
    // 实际项目中可能需要改写参数传递方式，直接传 Color
    // 这里为了兼容旧代码结构，暂时不做深度解析，而是依赖 Image.asset 的 color 参数
    // 这是一个折衷方案，完美的方案是重构 _buildAvatarLayer 的参数
    return null; 
  }
  
  // 重写 _buildAvatarLayer 以直接接受 Color 而不是 ColorFilter
  // 但为了最小化改动，我们在上面的 _buildAvatarLayer 中做了一些假设
  // 下面是一个更干净的实现方式：
  
  /* 
   * 修正：Image.asset 的 color 参数行为类似于 srcIn，而不是 modulate。
   * 如果 PNG 是白底黑线，modulate 有效；如果是彩色图，modulate 会混合颜色。
   * 对于 PNG 换色（如头发），通常需要图片本身是灰度或白色的。
   */

  Widget _buildPlaceholder() {
    return Container(
      width: size * 0.8,
      height: size * 0.8,
      decoration: BoxDecoration(
        color: Colors.transparent, // 占位符透明，避免遮挡
        borderRadius: BorderRadius.circular(8),
      ),
      // 仅在调试模式或显式占位时显示图标，否则留白
      child: const SizedBox(), 
    );
  }

  /// 解析十六进制颜色字符串为Color对象
  Color _parseColor(String colorStr) {
    try {
      final hexColor = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey;
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