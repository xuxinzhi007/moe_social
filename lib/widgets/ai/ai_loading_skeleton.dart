import 'package:flutter/material.dart';

import 'ai_theme.dart';
import '../motion/moe_shimmer.dart';

class AiLoadingSkeleton extends StatelessWidget {
  const AiLoadingSkeleton({
    super.key,
    this.itemCount = 4,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AiTheme.pagePadding),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AiTheme.sectionGap),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return MoeShimmer(
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AiTheme.radiusAiCard),
        ),
      ),
    );
  }
}
