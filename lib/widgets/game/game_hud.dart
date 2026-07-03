import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import '../ai/ai_brand_tokens.dart';

/// AI 状态指示灯
class AiStatusDot extends StatelessWidget {
  final bool online;

  const AiStatusDot({super.key, required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? MoeTokens.success : MoeTokens.danger;
    return Tooltip(
      message: online ? 'AI 模型在线，叙事由模型生成' : 'AI 模型离线，使用模板回复',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// 游戏 HUD 面板（场景信息、好感度、NPC/背包/探索概览）
class GameHud extends StatelessWidget {
  final String location;
  final String sceneDescription;
  final String focus;
  final String gameTime;
  final int favorability;
  final int npcCount;
  final int itemCount;
  final bool llmOnline;
  final int visitedCount;

  const GameHud({
    super.key,
    required this.location,
    required this.sceneDescription,
    required this.focus,
    required this.gameTime,
    required this.favorability,
    required this.npcCount,
    required this.itemCount,
    required this.llmOnline,
    required this.visitedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AiBrandTokens.heroGradient,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AiBrandTokens.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _hudChip(Icons.map_outlined, location),
                    if (focus.isNotEmpty)
                      _hudChip(Icons.center_focus_strong, focus),
                    _hudChip(Icons.schedule, gameTime),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AiStatusDot(online: llmOnline),
                      const SizedBox(width: 6),
                      Text(
                        llmOnline ? '在线' : '离线',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$favorability',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'NPC ×$npcCount · 🎒 ×$itemCount · 🗺️ ×$visitedCount',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (sceneDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sceneDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hudChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
