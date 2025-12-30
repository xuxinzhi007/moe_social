import 'package:flutter/material.dart';
import '../models/topic_tag.dart';
import 'topic_tag_selector.dart';

/// 紧凑版话题标签选择器 - 适用于发布页面等空间有限的场景
class CompactTopicSelector extends StatefulWidget {
  final List<TopicTag> selectedTags;
  final Function(List<TopicTag>) onTagsChanged;
  final String userId;
  final int maxTags;

  const CompactTopicSelector({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.userId,
    this.maxTags = 3,
  });

  @override
  State<CompactTopicSelector> createState() => _CompactTopicSelectorState();
}

class _CompactTopicSelectorState extends State<CompactTopicSelector> {
  bool _isExpanded = false;
  final TopicTagService _tagService = TopicTagService();

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _showFullSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // 顶部拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    '选择话题标签',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),

            // 标签选择器
            Expanded(
              child: TopicTagSelector(
                selectedTags: widget.selectedTags,
                onTagsChanged: widget.onTagsChanged,
                userId: widget.userId,
                maxTags: widget.maxTags,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              const Icon(
                Icons.label_outline,
                size: 18,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              const Text(
                '话题标签',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (widget.selectedTags.isEmpty)
                GestureDetector(
                  onTap: _showFullSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '添加标签',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _showFullSelector,
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),

          // 已选择的标签或推荐标签
          if (widget.selectedTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.selectedTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tag.color.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: tag.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          final newTags = widget.selectedTags
                              .where((t) => t.id != tag.id)
                              .toList();
                          widget.onTagsChanged(newTags);
                        },
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: tag.color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            // 显示推荐标签的精简版
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _tagService.getPopularTags(limit: 4).map((tag) {
                  return GestureDetector(
                    onTap: () {
                      if (widget.selectedTags.length < widget.maxTags) {
                        widget.onTagsChanged([...widget.selectedTags, tag]);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.add,
                            size: 12,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 超级紧凑版 - 单行显示
class MiniTopicSelector extends StatelessWidget {
  final List<TopicTag> selectedTags;
  final Function(List<TopicTag>) onTagsChanged;
  final String userId;
  final int maxTags;

  const MiniTopicSelector({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.userId,
    this.maxTags = 3,
  });

  void _showFullSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // 顶部拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    '选择话题标签',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),

            // 标签选择器
            Expanded(
              child: TopicTagSelector(
                selectedTags: selectedTags,
                onTagsChanged: onTagsChanged,
                userId: userId,
                maxTags: maxTags,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tag,
              size: 16,
              color: selectedTags.isNotEmpty ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              selectedTags.isNotEmpty
                ? '${selectedTags.length} 个标签'
                : '添加话题',
              style: TextStyle(
                fontSize: 13,
                color: selectedTags.isNotEmpty ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (selectedTags.isNotEmpty) ...[
              const SizedBox(width: 6),
              ...selectedTags.take(2).map((tag) => Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tag.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: tag.color,
                  ),
                ),
              )).toList(),
              if (selectedTags.length > 2) ...[
                const SizedBox(width: 4),
                Text(
                  '+${selectedTags.length - 2}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}