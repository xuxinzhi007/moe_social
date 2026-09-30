import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// 会员页展示的权益文案。只写已经落地的能力；未接入的玩法单独标注。
class VipBenefitCopy {
  const VipBenefitCopy({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tint,
    this.pending = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color tint;
  final bool pending;
}

/// 会员每个上海自然日赠送的星辉结晶，与后端单次召唤消耗一致。
const int vipDailyStarCrystals = 300;

/// 签到加成、私信留存和星辉每日结晶都已生效。
const List<VipBenefitCopy> vipMembershipBenefits = [
  VipBenefitCopy(
    icon: Icons.today_rounded,
    title: '签到经验',
    detail: '每日签到 ×1.5',
    tint: MoeTokens.primary,
  ),
  VipBenefitCopy(
    icon: Icons.forum_outlined,
    title: '私信留存',
    detail: '对话保留 90 天',
    tint: MoeTokens.pastelBlue,
  ),
  VipBenefitCopy(
    icon: Icons.auto_awesome_rounded,
    title: '星辉结晶',
    detail: '每日赠送 $vipDailyStarCrystals',
    tint: MoeTokens.pastelOrange,
  ),
];

/// 把后端 `expires_at` 收成「2026.06.23 19:43」，避免秒级时间把卡片撑开。
String formatVipExpiryLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return '有效期待同步';
  }
  final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (parsed == null) {
    return raw.trim();
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}.${two(parsed.month)}.${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

/// 会员中心、购买页共用的权益区。
class VipBenefitPanel extends StatelessWidget {
  const VipBenefitPanel({super.key, this.showIntro = true, this.caption});

  final bool showIntro;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '会员权益',
              style: TextStyle(
                fontSize: MoeTokens.textLg,
                fontWeight: MoeTokens.fontWeightTitle,
                color: MoeTokens.titleText,
              ),
            ),
            if (caption != null && caption!.isNotEmpty) ...[
              const SizedBox(width: MoeTokens.spaceSm),
              Expanded(
                child: Text(
                  caption!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: MoeTokens.hintText,
                    fontSize: MoeTokens.textXs,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showIntro) ...[
          const SizedBox(height: MoeTokens.spaceXs),
          Text(
            '星辉结晶在进入星辉远征时到账，每个自然日一次。',
            style: TextStyle(
              color: MoeTokens.hintText,
              fontSize: MoeTokens.textSm,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: MoeTokens.spaceMd),
        for (var i = 0; i < vipMembershipBenefits.length; i++) ...[
          if (i > 0) const SizedBox(height: MoeTokens.spaceSm),
          _VipBenefitTile(benefit: vipMembershipBenefits[i]),
        ],
      ],
    );
  }
}

class _VipBenefitTile extends StatelessWidget {
  const _VipBenefitTile({required this.benefit});

  final VipBenefitCopy benefit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceMd,
        vertical: MoeTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: benefit.tint.withValues(alpha: benefit.pending ? 0.06 : 0.1),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: benefit.tint.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(benefit.icon, size: 16, color: benefit.tint),
          const SizedBox(width: MoeTokens.spaceSm),
          Expanded(
            child: Text(
              benefit.title,
              style: const TextStyle(
                fontSize: MoeTokens.textSm,
                fontWeight: MoeTokens.fontWeightSubtitle,
                color: MoeTokens.titleText,
              ),
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          Text(
            benefit.detail,
            style: const TextStyle(
              fontSize: MoeTokens.textSm,
              color: MoeTokens.inkMuted,
            ),
          ),
          if (benefit.pending) ...[
            const SizedBox(width: MoeTokens.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: MoeTokens.cardBackground,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              ),
              child: const Text(
                '接入中',
                style: TextStyle(
                  fontSize: MoeTokens.textXs,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                  color: MoeTokens.inkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
