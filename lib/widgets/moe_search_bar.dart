import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';

/// 萌社交统一搜索栏 — 半透明背景 + 渐变图标容器 + 微阴影。
class MoeSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;
  final Function() onClear;

  const MoeSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
    required this.onClear,
  });

  @override
  State<MoeSearchBar> createState() => _MoeSearchBarState();
}

class _MoeSearchBarState extends State<MoeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        border: Border.all(color: MoeTokens.surfaceBorder, width: 1),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          // 渐变圆形图标容器
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: MoeTokens.gradientSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: MoeTokens.primary,
                size: 15,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: MoeTokens.hintText,
                  fontSize: MoeTokens.textBase,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(
                fontSize: MoeTokens.textBase,
                color: MoeTokens.titleText,
              ),
              onChanged: (text) {
                setState(() => _hasText = text.isNotEmpty);
                widget.onSearch(text);
              },
            ),
          ),
          if (_hasText)
            IconButton(
              onPressed: () {
                _controller.clear();
                setState(() => _hasText = false);
                widget.onClear();
              },
              icon: Icon(
                Icons.cancel_rounded,
                color: MoeTokens.hintText.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
