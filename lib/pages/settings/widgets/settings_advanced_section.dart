import 'package:flutter/material.dart';

import '../../../theme/moe_tokens.dart';
import '../../../widgets/moe_menu_card.dart';
import '../modules/ai_settings_module.dart';
import 'feishu_bind_sheet.dart';

/// 默认折叠的高级 / 开发者向设置。
class SettingsAdvancedSection extends StatefulWidget {
  const SettingsAdvancedSection({super.key});

  @override
  State<SettingsAdvancedSection> createState() =>
      _SettingsAdvancedSectionState();
}

class _SettingsAdvancedSectionState extends State<SettingsAdvancedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCardLarge),
        boxShadow: MoeTokens.cardShadow(),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(MoeTokens.radiusCardLarge),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.blueGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '高级选项',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI 模型、飞书通知等开发者/企业功能',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AiSettingsModule(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: MoeMenuCard(
                items: [
                  MoeMenuItem(
                    icon: Icons.notifications_active_rounded,
                    title: '飞书通知',
                    subtitle: '可选；机器人仅企业内成员可收推送',
                    color: const Color(0xFF3370FF),
                    onTap: () => showFeishuBindSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
