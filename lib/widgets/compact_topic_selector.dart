import 'package:flutter/material.dart';

import '../models/topic_tag.dart';
import '../theme/moe_tokens.dart';
import 'motion/moe_pressable.dart';
import 'motion/moe_reveal.dart';
import 'motion/moe_sheet.dart';
import 'topic_tag_selector.dart';

class CompactTopicSelector extends StatefulWidget {
  final List<TopicTag> selectedTags;
  final ValueChanged<List<TopicTag>> onTagsChanged;
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
  late List<TopicTag> _selectedTags;
  final TopicTagService _tagService = TopicTagService();

  @override
  void initState() {
    super.initState();
    _selectedTags = List<TopicTag>.from(widget.selectedTags);
  }

  @override
  void didUpdateWidget(covariant CompactTopicSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.selectedTags.map((t) => t.id).toList();
    final newIds = widget.selectedTags.map((t) => t.id).toList();
    if (oldIds.length != newIds.length) {
      _selectedTags = List<TopicTag>.from(widget.selectedTags);
      return;
    }
    for (var i = 0; i < oldIds.length; i++) {
      if (oldIds[i] != newIds[i]) {
        _selectedTags = List<TopicTag>.from(widget.selectedTags);
        return;
      }
    }
  }

  void _updateTags(List<TopicTag> next) {
    setState(() {
      _selectedTags = List<TopicTag>.from(next);
    });
    widget.onTagsChanged(_selectedTags);
  }

  Future<void> _showFullSelector() {
    return MoeSheet.show<void>(
      context,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.8,
        child: Column(
          children: [
            MoeReveal(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      '选择话题标签',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: MoeReveal(
                delay: const Duration(milliseconds: 50),
                child: TopicTagSelector(
                  selectedTags: _selectedTags,
                  onTagsChanged: _updateTags,
                  userId: widget.userId,
                  maxTags: widget.maxTags,
                ),
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
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
              if (_selectedTags.isEmpty)
                MoePressable(
                  onTap: _showFullSelector,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
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
                MoePressable(
                  onTap: _showFullSelector,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          if (_selectedTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _selectedTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tag.color.withValues(alpha: 0.5)),
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
                      MoePressable(
                        onTap: () {
                          final newTags =
                              _selectedTags.where((t) => t.id != tag.id).toList();
                          _updateTags(newTags);
                        },
                        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
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
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _tagService.getPopularTags(limit: 4).map((tag) {
                  return MoePressable(
                    onTap: () {
                      if (_selectedTags.length >= widget.maxTags) return;
                      if (_selectedTags.any((t) => t.id == tag.id)) return;
                      _updateTags([..._selectedTags, tag]);
                    },
                    borderRadius: BorderRadius.circular(16),
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

class MiniTopicSelector extends StatelessWidget {
  final List<TopicTag> selectedTags;
  final ValueChanged<List<TopicTag>> onTagsChanged;
  final String userId;
  final int maxTags;

  const MiniTopicSelector({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.userId,
    this.maxTags = 3,
  });

  Future<void> _showFullSelector(BuildContext context) {
    return MoeSheet.show<void>(
      context,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.8,
        child: Column(
          children: [
            MoeReveal(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      '选择话题标签',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: MoeReveal(
                delay: const Duration(milliseconds: 50),
                child: TopicTagSelector(
                  selectedTags: selectedTags,
                  onTagsChanged: onTagsChanged,
                  userId: userId,
                  maxTags: maxTags,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MoePressable(
      onTap: () => _showFullSelector(context),
      borderRadius: BorderRadius.circular(20),
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
              selectedTags.isNotEmpty ? '${selectedTags.length} 个标签' : '添加话题',
              style: TextStyle(
                fontSize: 13,
                color: selectedTags.isNotEmpty ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (selectedTags.isNotEmpty) ...[
              const SizedBox(width: 6),
              ...selectedTags.take(2).map(
                    (tag) => Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tag.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: tag.color,
                        ),
                      ),
                    ),
                  ),
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
