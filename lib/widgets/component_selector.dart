import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 虚拟形象组件选择器
/// 用于选择脸型、发型、眼睛、服装、配饰等
class ComponentSelector extends StatelessWidget {
  final String title;
  final String currentValue;
  final List<String> options;
  final String assetBasePath;
  final ValueChanged<String> onChanged;

  const ComponentSelector({
    super.key,
    required this.title,
    required this.currentValue,
    required this.options,
    required this.assetBasePath,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式网格计算
        final screenWidth = constraints.maxWidth;
        int crossAxisCount = 3;
        if (screenWidth < 400) {
          crossAxisCount = 2; // 小屏幕显示2列
        } else if (screenWidth > 600) {
          crossAxisCount = 4; // 大屏幕显示4列
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.9, // 略微高一点，适应不同内容
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == currentValue;

                    return _ComponentOption(
                      option: option,
                      assetPath: option == 'none'
                          ? null
                          : '$assetBasePath$option.svg',
                      isSelected: isSelected,
                      onTap: () => onChanged(option),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComponentOption extends StatelessWidget {
  final String option;
  final String? assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _ComponentOption({
    required this.option,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            // 内容区域
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildOptionContent(),
              ),
            ),

            // 选中指示器
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionContent() {
    // 处理"无"选项
    if (option == 'none') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.close,
            color: Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            '无',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    // 显示SVG预览
    if (assetPath != null) {
      return FutureBuilder<bool>(
        future: _checkAssetExists(assetPath!),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: SvgPicture.asset(
                    assetPath!,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getOptionDisplayName(option),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          } else {
            // 占位符
            return _buildPlaceholder();
          }
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey[400],
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getOptionDisplayName(option),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 获取选项的显示名称
  String _getOptionDisplayName(String option) {
    // 可以根据需要自定义显示名称
    final nameMap = {
      'face_1': '圆脸',
      'face_2': '瓜子脸',
      'face_3': '方脸',
      'hair_1': '短发',
      'hair_2': '长发',
      'hair_3': '卷发',
      'hair_4': '马尾',
      'eyes_1': '大眼',
      'eyes_2': '小眼',
      'eyes_3': '眯眼',
      'clothes_1': 'T恤',
      'clothes_2': '衬衫',
      'clothes_3': '连衣裙',
      'clothes_4': '外套',
      'glasses_1': '圆框眼镜',
      'glasses_2': '方框眼镜',
      'hat_1': '帽子',
      'none': '无',
    };

    return nameMap[option] ?? option;
  }

  /// 检查资源是否存在
  Future<bool> _checkAssetExists(String assetPath) async {
    try {
      // 简化实现，实际项目中可能需要更复杂的检查
      return true;
    } catch (e) {
      return false;
    }
  }
}