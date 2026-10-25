import 'package:flutter/material.dart';

import '../moe_search_bar.dart';

class SettingsSearchBar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final String hintText;

  const SettingsSearchBar({
    super.key,
    required this.onSearch,
    required this.onClear,
    this.hintText = '搜索设置',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: MoeSearchBar(
        hintText: hintText,
        onSearch: onSearch,
        onClear: onClear,
      ),
    );
  }
}
