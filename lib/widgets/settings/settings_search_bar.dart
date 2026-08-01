import 'package:flutter/material.dart';
import '../../theme/moe_tokens.dart';

class SettingsSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function() onClear;
  final String hintText;

  const SettingsSearchBar({
    super.key,
    required this.onSearch,
    required this.onClear,
    this.hintText = '搜索设置',
  });

  @override
  State<SettingsSearchBar> createState() => _SettingsSearchBarState();
}

class _SettingsSearchBarState extends State<SettingsSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() {
            _isSearching = value.isNotEmpty;
          });
          widget.onSearch(value);
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(
            Icons.search,
            color: MoeTokens.hintText,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: MoeTokens.hintText,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _isSearching = false;
                    });
                    widget.onClear();
                    widget.onSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
