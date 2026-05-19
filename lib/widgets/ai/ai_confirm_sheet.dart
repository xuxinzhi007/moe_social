import 'package:flutter/material.dart';

import 'ai_sheet.dart';
import 'ai_theme.dart';

abstract final class AiConfirmSheet {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
    bool isDanger = false,
  }) async {
    final result = await AiSheet.show<bool>(
      context: context,
      title: title,
      initialChildSize: 0.38,
      minChildSize: 0.28,
      maxChildSize: 0.5,
      child: Text(message, style: AiTheme.body),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: isDanger
                  ? AiTheme.dangerButtonStyle()
                  : AiTheme.primaryButtonStyle(),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }
}
