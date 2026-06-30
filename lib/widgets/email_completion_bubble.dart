import 'package:flutter/material.dart';

/// 邮箱后缀快捷条：内联在输入框下方，横向胶囊，无 Overlay。
class EmailSuffixBar extends StatelessWidget {
  const EmailSuffixBar({
    super.key,
    required this.candidates,
    required this.onSelected,
    this.accentColor = const Color(0xFF7F7FD5),
  });

  final List<String> candidates;
  final ValueChanged<String> onSelected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: candidates.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final full = candidates[index];
                    final domain = _domainLabel(full);
                    return _SuffixChip(
                      label: domain,
                      accentColor: accentColor,
                      onPick: () => onSelected(full),
                    );
                  },
                ),
              ),
            ),
    );
  }

  static String _domainLabel(String full) {
    final at = full.indexOf('@');
    if (at < 0) return full;
    return full.substring(at);
  }
}

class _SuffixChip extends StatelessWidget {
  const _SuffixChip({
    required this.label,
    required this.accentColor,
    required this.onPick,
  });

  final String label;
  final Color accentColor;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '补全邮箱后缀 $label',
      child: Material(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(17),
          splashColor: accentColor.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
