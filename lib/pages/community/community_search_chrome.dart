import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../../widgets/moe_search_bar.dart';

/// 兴趣社区搜索框。圈子和讨论共用 [MoeSearchBar]。
class CommunitySearchField extends StatelessWidget {
  const CommunitySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: MoeSearchBar(
        controller: controller,
        hintText: hintText,
        autofocus: true,
        onSubmitted: onSubmitted,
        onSearch: (_) {},
        onClear: () {},
      ),
    );
  }
}

/// 搜索页空态和未输入时的提示。
class CommunitySearchHint extends StatelessWidget {
  const CommunitySearchHint({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: MoeTokens.hintText),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: MoeTokens.titleText,
                fontSize: MoeTokens.textLg,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MoeTokens.hintText,
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
