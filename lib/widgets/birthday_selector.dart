import 'package:flutter/material.dart';

/// 生日选择组件
/// 提供日期选择器功能，限制选择未来日期
class BirthdaySelector extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;
  final bool enabled;

  const BirthdaySelector({
    super.key,
    this.selectedDate,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 生日选择区域
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
                : theme.disabledColor.withAlpha(25),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? () => _showDatePicker(context) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 24,
                      color: enabled
                          ? theme.primaryColor
                          : theme.disabledColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '生日',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: enabled
                                  ? theme.textTheme.bodyMedium?.color
                                  : theme.disabledColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedDate != null
                                ? _formatDisplayDate(selectedDate!)
                                : '点击选择生日',
                            style: TextStyle(
                              fontSize: 16,
                              color: selectedDate != null
                                  ? (enabled
                                      ? theme.textTheme.bodyLarge?.color
                                      : theme.disabledColor)
                                  : (enabled
                                      ? theme.textTheme.bodyMedium?.color?.withAlpha(128)
                                      : theme.disabledColor),
                            ),
                          ),
                          // 显示年龄
                          if (selectedDate != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_calculateAge(selectedDate!)}岁',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.primaryColor.withAlpha(179),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 清除按钮
                    if (selectedDate != null && enabled)
                      GestureDetector(
                        onTap: () => onChanged(null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.clear,
                            size: 20,
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(153),
                          ),
                        ),
                      ),
                    // 选择指示器
                    if (enabled)
                      Icon(
                        Icons.keyboard_arrow_right,
                        size: 24,
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(102),
                      ),
                  ],
                ),
              ),
            ),
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
              '生日信息将在个人资料中显示，可以选择不填写',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withAlpha(153),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 显示日期选择器
  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();

    // 设置日期选择器的范围：从100年前到今天
    final firstDate = DateTime(now.year - 100);
    final lastDate = now;

    try {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? DateTime(now.year - 20), // 默认20岁
        firstDate: firstDate,
        lastDate: lastDate,
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).primaryColor,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedDate != null && pickedDate != selectedDate) {
        onChanged(pickedDate);
      }
    } catch (e) {
      // 如果日期选择器出现错误，显示简单的错误提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开日期选择器'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 格式化显示日期
  String _formatDisplayDate(DateTime date) {
    final now = DateTime.now();

    // 如果是今年，显示简化格式
    if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    }

    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 计算年龄
  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;

    // 检查今年是否已经过了生日
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }
}