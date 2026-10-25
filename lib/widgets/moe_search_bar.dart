import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';

/// 萌社交统一搜索条。页面内筛选和列表搜索都用这一套，避免再套全局输入框主题。
class MoeSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const MoeSearchBar({
    super.key,
    required this.hintText,
    required this.onSearch,
    required this.onClear,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  State<MoeSearchBar> createState() => _MoeSearchBarState();
}

class _MoeSearchBarState extends State<MoeSearchBar> {
  TextEditingController? _owned;
  bool _hasText = false;

  TextEditingController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = TextEditingController();
    }
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_syncHasText);
  }

  @override
  void didUpdateWidget(covariant MoeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    (oldWidget.controller ?? _owned)?.removeListener(_syncHasText);
    if (widget.controller == null && _owned == null) {
      _owned = TextEditingController();
    }
    if (widget.controller != null) {
      _owned?.dispose();
      _owned = null;
    }
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_syncHasText);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncHasText);
    _owned?.dispose();
    super.dispose();
  }

  void _syncHasText() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText == _hasText || !mounted) return;
    setState(() => _hasText = hasText);
  }

  void _clear() {
    _controller.clear();
    widget.onSearch('');
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.search_rounded,
            color: MoeTokens.hintText,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w600,
                color: MoeTokens.titleText,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  color: MoeTokens.hintText,
                  fontSize: MoeTokens.textSm,
                  fontWeight: FontWeight.w500,
                ),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onSearch,
              onSubmitted: widget.onSubmitted,
            ),
          ),
          if (_hasText)
            IconButton(
              onPressed: _clear,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                Icons.cancel_rounded,
                color: MoeTokens.hintText.withValues(alpha: 0.7),
                size: 16,
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
