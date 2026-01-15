import 'package:flutter/material.dart';

/// 性别选择组件
/// 提供男、女、保密三个选项的单选功能
class GenderSelector extends StatelessWidget {
  final String selectedGender;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  const GenderSelector({
    super.key,
    required this.selectedGender,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  static const List<_GenderOption> _genderOptions = [
    _GenderOption(value: 'male', label: '男', icon: Icons.male),
    _GenderOption(value: 'female', label: '女', icon: Icons.female),
    _GenderOption(value: 'secret', label: '保密', icon: Icons.help_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 性别选项
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null
                  ? theme.colorScheme.error
                  : theme.dividerColor,
              width: 1.5,
            ),
            color: enabled
                ? theme.cardColor
                : theme.disabledColor.withOpacity(0.1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '性别',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? theme.textTheme.bodyMedium?.color
                      : theme.disabledColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: _genderOptions.map((option) {
                  final isSelected = selectedGender == option.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: enabled ? () => onChanged(option.value) : null,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? theme.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.dividerColor.withOpacity(0.5),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              option.icon,
                              size: 24,
                              color: isSelected
                                  ? theme.primaryColor
                                  : (enabled
                                      ? theme.textTheme.bodyMedium?.color?.withOpacity(0.6)
                                      : theme.disabledColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? theme.primaryColor
                                    : (enabled
                                        ? theme.textTheme.bodyMedium?.color
                                        : theme.disabledColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // 错误提示
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],

        // 友好提示
        if (errorText == null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '选择性别后将在个人资料中显示',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 性别选项数据模型
class _GenderOption {
  final String value;
  final String label;
  final IconData icon;

  const _GenderOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}