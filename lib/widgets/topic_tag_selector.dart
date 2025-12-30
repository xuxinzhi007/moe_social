import 'package:flutter/material.dart';
import 'dart:async';
import '../models/topic_tag.dart';

/// 话题标签选择器 - 支持搜索、创建和选择自定义标签
class TopicTagSelector extends StatefulWidget {
  final List<TopicTag> selectedTags;
  final Function(List<TopicTag>) onTagsChanged;
  final String userId;
  final int maxTags;
  final bool showSearchBar;
  final String? placeholder;

  const TopicTagSelector({
    super.key,
    required this.selectedTags,
    required this.onTagsChanged,
    required this.userId,
    this.maxTags = 3,
    this.showSearchBar = true,
    this.placeholder,
  });

  @override
  State<TopicTagSelector> createState() => _TopicTagSelectorState();
}

class _TopicTagSelectorState extends State<TopicTagSelector> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TopicTagService _tagService = TopicTagService();

  List<TopicTag> _searchResults = [];
  List<TopicTag> _recommendedTags = [];
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendedTags();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadRecommendedTags() {
    setState(() {
      _recommendedTags = _tagService.getRecommendedTags(widget.userId);
    });
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = query.trim().isNotEmpty;
      if (_isSearching) {
        _searchResults = _tagService.searchTags(query.trim());
      } else {
        _searchResults.clear();
      }
    });
  }

  void _addTag(TopicTag tag) {
    if (widget.selectedTags.length >= widget.maxTags) {
      _showMaxTagsMessage();
      return;
    }

    // 检查是否已选择
    if (widget.selectedTags.any((t) => t.id == tag.id)) {
      return;
    }

    final newTags = [...widget.selectedTags, tag];
    widget.onTagsChanged(newTags);

    // 清空搜索
    _searchController.clear();
    _searchFocus.unfocus();
  }

  void _createAndAddTag(String name) {
    final cleanName = TopicTag.cleanTagName(name);

    if (!TopicTag.isValidTagName(cleanName)) {
      _showInvalidTagMessage();
      return;
    }

    if (widget.selectedTags.length >= widget.maxTags) {
      _showMaxTagsMessage();
      return;
    }

    // 检查是否已有同名标签
    if (widget.selectedTags.any((t) =>
        t.name.toLowerCase() == cleanName.toLowerCase())) {
      return;
    }

    final newTag = _tagService.getOrCreateTag(cleanName, widget.userId);
    _addTag(newTag);
  }

  void _removeTag(TopicTag tag) {
    final newTags = widget.selectedTags.where((t) => t.id != tag.id).toList();
    widget.onTagsChanged(newTags);
  }

  void _showMaxTagsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('最多只能选择${widget.maxTags}个标签'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showInvalidTagMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('标签名称不合法，请使用中英文、数字，长度不超过20字符'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题和已选标签
          Row(
            children: [
              const Icon(
                Icons.label_outline,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '添加话题标签 (${widget.selectedTags.length}/${widget.maxTags})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // 已选择的标签
          if (widget.selectedTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedTags.map((tag) {
                return _buildSelectedTagChip(tag);
              }).toList(),
            ),
          ],

          // 搜索输入框
          if (widget.showSearchBar) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: widget.placeholder ?? '搜索或创建新标签...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocus.unfocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _createAndAddTag(value.trim());
                }
              },
            ),
          ],

          const SizedBox(height: 16),

          // 搜索结果或推荐标签
          if (_isSearching) ...[
            _buildSearchResults(),
          ] else ...[
            _buildRecommendedTags(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedTagChip(TopicTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tag.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tag.color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag.name,
            style: TextStyle(
              color: tag.color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeTag(tag),
            child: Icon(
              Icons.close,
              size: 16,
              color: tag.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildCreateNewTagOption(_searchController.text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchResults.isNotEmpty) ...[
          const Text(
            '搜索结果',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchResults.map((tag) {
              return _buildTagChip(tag);
            }).toList(),
          ),
        ],

        // 创建新标签选项
        if (_searchController.text.trim().isNotEmpty) ...[
          if (_searchResults.isNotEmpty) const SizedBox(height: 12),
          _buildCreateNewTagOption(_searchController.text.trim()),
        ],
      ],
    );
  }

  Widget _buildCreateNewTagOption(String name) {
    final cleanName = TopicTag.cleanTagName(name);
    final isValid = TopicTag.isValidTagName(cleanName);

    return GestureDetector(
      onTap: isValid ? () => _createAndAddTag(cleanName) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isValid ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isValid ? Colors.blue : Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: isValid ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              '创建 "$cleanName"',
              style: TextStyle(
                color: isValid ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '推荐标签',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recommendedTags.map((tag) {
            return _buildTagChip(tag);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(TopicTag tag) {
    final isSelected = widget.selectedTags.any((t) => t.id == tag.id);

    return GestureDetector(
      onTap: isSelected ? null : () => _addTag(tag),
      child: Opacity(
        opacity: isSelected ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tag.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tag.color.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tag.name,
                style: TextStyle(
                  color: tag.color,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (tag.isOfficial) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 12,
                  color: tag.color,
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '${tag.usageCount}',
                style: TextStyle(
                  color: tag.color.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 简化的标签显示组件
class TopicTagDisplay extends StatelessWidget {
  final TopicTag tag;
  final double fontSize;
  final bool showUsageCount;
  final VoidCallback? onTap;

  const TopicTagDisplay({
    super.key,
    required this.tag,
    this.fontSize = 12,
    this.showUsageCount = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.8,
          vertical: fontSize * 0.4,
        ),
        decoration: BoxDecoration(
          color: tag.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(fontSize),
          border: Border.all(
            color: tag.color.withOpacity(0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.name,
              style: TextStyle(
                color: tag.color,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showUsageCount && tag.usageCount > 0) ...[
              SizedBox(width: fontSize * 0.3),
              Text(
                '${tag.usageCount}',
                style: TextStyle(
                  color: tag.color.withOpacity(0.7),
                  fontSize: fontSize * 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}