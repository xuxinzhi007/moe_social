import 'package:flutter/material.dart';
import '../models/emotion_tag.dart';

/// 情绪标签选择器组件
class EmotionTagSelector extends StatefulWidget {
  final EmotionTag? selectedTag;
  final Function(EmotionTag?) onTagSelected;
  final bool showAllTags;

  const EmotionTagSelector({
    super.key,
    this.selectedTag,
    required this.onTagSelected,
    this.showAllTags = false,
  });

  @override
  State<EmotionTagSelector> createState() => _EmotionTagSelectorState();
}

class _EmotionTagSelectorState extends State<EmotionTagSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _selectTag(EmotionTag? tag) {
    widget.onTagSelected(tag);
    // 选择后自动收起
    if (_isExpanded && !widget.showAllTags) {
      _toggleExpand();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsToShow = widget.showAllTags
        ? EmotionTag.defaultTags
        : EmotionTag.getPopularTags();

    if (widget.showAllTags) {
      // 显示所有标签的网格布局
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '选择心情',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.selectedTag != null)
                  TextButton(
                    onPressed: () => _selectTag(null),
                    child: const Text('清除'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tagsToShow.map((tag) => _buildTagChip(tag)).toList(),
            ),
          ],
        ),
      );
    }

    // 紧凑模式，只显示选中的标签和展开按钮
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isExpanded ? 120 : null, // 修复：未展开时使用自适应高度
      constraints: BoxConstraints(
        minHeight: 36, // 设置最小高度
        maxHeight: _isExpanded ? 120 : 44, // 设置最大高度，给未展开状态更多空间
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // 修复：使用最小尺寸
        children: [
          // 顶部显示选中的标签或展开按钮
          SizedBox(
            height: 36, // 固定顶部行的高度
            child: Row(
              children: [
                if (widget.selectedTag != null) ...[
                  _buildTagChip(widget.selectedTag!, isSelected: true),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _selectTag(null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _toggleExpand,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6, // 减少垂直padding
                      ),
                      decoration: BoxDecoration(
                        color: _isExpanded ? Colors.blue[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isExpanded ? Colors.blue : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '😊',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '心情',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 展开的标签列表
          if (_isExpanded)
            Expanded(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: const EdgeInsets.only(top: 8), // 减少上边距
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tagsToShow
                          .map((tag) => _buildTagChip(tag))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(EmotionTag tag, {bool? isSelected}) {
    final bool selected = isSelected ?? (widget.selectedTag?.id == tag.id);

    return GestureDetector(
      onTap: () => _selectTag(selected ? null : tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tag.color.withOpacity(0.2) : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? tag.color : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tag.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? tag.color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 情绪标签显示组件（只读）
class EmotionTagDisplay extends StatelessWidget {
  final EmotionTag tag;
  final double size;
  final bool showName;

  const EmotionTagDisplay({
    super.key,
    required this.tag,
    this.size = 14.0,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showName ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: tag.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tag.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag.emoji,
            style: TextStyle(fontSize: size),
          ),
          if (showName) ...[
            const SizedBox(width: 4),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: size - 2,
                fontWeight: FontWeight.w500,
                color: tag.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}