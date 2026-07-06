import 'package:flutter/material.dart';

import '../theme/moe_tokens.dart';
import 'motion/moe_pressable.dart';
import 'motion/moe_sheet.dart';

class MoeSelectOption<T> {
  final T value;
  final String label;
  final String? hint;
  final IconData? icon;

  const MoeSelectOption({
    required this.value,
    required this.label,
    this.hint,
    this.icon,
  });
}

class MoeSelectField<T> extends StatelessWidget {
  final String label;
  final String? helper;
  final T value;
  final List<MoeSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData leadingIcon;

  const MoeSelectField({
    super.key,
    required this.label,
    this.helper,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leadingIcon = Icons.tune_rounded,
  });

  MoeSelectOption<T> get _selectedOption {
    return options.firstWhere((option) => option.value == value);
  }

  Future<void> _openSelector(BuildContext context) async {
    final result = await MoeSheet.show<T>(
      context,
      builder: (sheetContext) {
        return _MoeSelectSheet<T>(
          title: label,
          value: value,
          options: options,
        );
      },
    );

    if (result == null || result == value) {
      return;
    }
    onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;

    return MoePressable(
      borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
      onTap: () => _openSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          border: Border.all(
            color: MoeTokens.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: MoeTokens.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MoeTokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                leadingIcon,
                color: MoeTokens.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (helper != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      helper!,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.black45,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoeSelectSheet<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<MoeSelectOption<T>> options;

  const _MoeSelectSheet({
    required this.title,
    required this.value,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '选择你想看的排序方式',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 14),
            ...options.map((option) {
              final selected = option.value == value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MoePressable(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                  onTap: () => Navigator.of(context).pop(option.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? MoeTokens.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      border: Border.all(
                        color: selected
                            ? MoeTokens.primary.withValues(alpha: 0.28)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (option.icon != null) ...[
                          Icon(
                            option.icon,
                            size: 18,
                            color: selected ? MoeTokens.primary : Colors.black54,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? MoeTokens.primary : Colors.black87,
                                ),
                              ),
                              if (option.hint != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  option.hint!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected ? MoeTokens.primary : Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
