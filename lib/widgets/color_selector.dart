import 'package:flutter/material.dart';

/// 颜色选择器组件
/// 用于选择肤色、发色等
class ColorSelector extends StatelessWidget {
  final List<String> colors;
  final String currentColor;
  final ValueChanged<String> onChanged;

  const ColorSelector({
    super.key,
    required this.colors,
    required this.currentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((colorHex) {
        final isSelected = colorHex == currentColor;
        final color = _parseColor(colorHex);

        return GestureDetector(
          onTap: () => onChanged(colorHex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 4 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  )
                : null,
          ),
        );
      }).toList(),
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

/// 高级颜色选择器，支持自定义颜色
class AdvancedColorSelector extends StatefulWidget {
  final List<String> presetColors;
  final String currentColor;
  final ValueChanged<String> onChanged;
  final bool allowCustomColor;

  const AdvancedColorSelector({
    super.key,
    required this.presetColors,
    required this.currentColor,
    required this.onChanged,
    this.allowCustomColor = false,
  });

  @override
  State<AdvancedColorSelector> createState() => _AdvancedColorSelectorState();
}

class _AdvancedColorSelectorState extends State<AdvancedColorSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预设颜色
        ColorSelector(
          colors: widget.presetColors,
          currentColor: widget.currentColor,
          onChanged: widget.onChanged,
        ),

        // 自定义颜色按钮
        if (widget.allowCustomColor) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showColorPicker,
            icon: const Icon(Icons.palette, size: 20),
            label: const Text('自定义颜色'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择自定义颜色'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _parseColor(widget.currentColor),
            onColorChanged: (color) {
              final hexColor = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
              widget.onChanged(hexColor);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      final hexColor = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}

/// 简单的颜色块选择器
class BlockPicker extends StatelessWidget {
  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;

  const BlockPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
    ];

    return SizedBox(
      width: 280,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: colors.map((color) {
          return GestureDetector(
            onTap: () => onColorChanged(color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: pickerColor.value == color.value
                      ? Colors.black
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}