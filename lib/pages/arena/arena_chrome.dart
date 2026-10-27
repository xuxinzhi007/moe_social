part of 'arena_page.dart';

class _TowerStatusChip extends StatelessWidget {
  const _TowerStatusChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _ArenaColors.ink.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border:
              Border.all(color: _ArenaColors.goldLight.withValues(alpha: .34)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _ArenaColors.goldLight),
            const SizedBox(width: 5),
            Text(
              '$label  $value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: MoeTokens.textXs,
                fontWeight: MoeTokens.fontWeightTitle,
              ),
            ),
          ],
        ),
      );
}

class _ArenaTextButton extends StatelessWidget {
  const _ArenaTextButton({
    required this.label,
    required this.onPressed,
    required this.textColor,
    required this.decoration,
    this.fontSize = 11,
    this.minHeight = 34,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  final String label;
  final VoidCallback onPressed;
  final Color textColor;
  final Decoration decoration;
  final double fontSize;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          alignment: Alignment.center,
          padding: padding,
          decoration: decoration,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _ArenaColors {
  static const ink = Color(0xFF30263C);
  static const violet = Color(0xFF614682);
  static const violetLight = Color(0xFF9B7FC0);
  static const cream = Color(0xFFFFF8E9);
  static const gold = Color(0xFFD9A94F);
  static const goldLight = Color(0xFFFFE39B);
  static const muted = Color(0xFF806B83);
}

Color _rarityAccent(ArenaRarity rarity) {
  switch (rarity) {
    case ArenaRarity.ssr:
      return _ArenaColors.gold;
    case ArenaRarity.sr:
      return const Color(0xFF9B7FC0);
    case ArenaRarity.r:
      return const Color(0xFF7EB4D8);
  }
}

Color _raritySurface(ArenaRarity rarity) => Color.alphaBlend(
    _rarityAccent(rarity).withValues(alpha: .16), Colors.white);

IconData _roleIcon(String role) {
  switch (role) {
    case '剑士':
      return Icons.auto_fix_high_rounded;
    case '法师':
      return Icons.flare_rounded;
    case '射手':
      return Icons.gps_fixed_rounded;
    case '辅助':
      return Icons.volunteer_activism_rounded;
    case '守卫':
      return Icons.shield_rounded;
    default:
      return Icons.stars_rounded;
  }
}

class _LobbyBackground extends StatelessWidget {
  const _LobbyBackground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF73528A),
              Color(0xFFE4B7AD),
              Color(0xFF526D9B),
            ],
          ),
        ),
        child: SizedBox.expand(child: CustomPaint(painter: _WindowPainter())),
      );
}

class _SummonBackground extends StatelessWidget {
  const _SummonBackground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.2),
            radius: .95,
            colors: [
              Color(0xFFFFF6CE),
              Color(0xFF72BCD4),
              Color(0xFF73528A),
              Color(0xFF3D2E55),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _SummonBackgroundPainter(progress),
          child: const SizedBox.expand(),
        ),
      );
}

class _SummonBackgroundPainter extends CustomPainter {
  const _SummonBackgroundPainter(this.progress);

  final double progress;

  static const _stars = <Offset>[
    Offset(.08, .16),
    Offset(.16, .36),
    Offset(.24, .12),
    Offset(.34, .28),
    Offset(.44, .10),
    Offset(.58, .18),
    Offset(.68, .08),
    Offset(.78, .32),
    Offset(.90, .14),
    Offset(.12, .68),
    Offset(.30, .76),
    Offset(.46, .64),
    Offset(.62, .78),
    Offset(.84, .70),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .53, size.height * .46);
    final phase = progress * math.pi * 2;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _ArenaColors.goldLight.withValues(alpha: .42),
          _ArenaColors.violetLight.withValues(alpha: .18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 170));
    canvas.drawCircle(center, 170, glowPaint);

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _stars.length; i++) {
      final anchor = _stars[i];
      final drift = math.sin(phase + i) * 6;
      final opacity = .38 + math.sin(phase * 1.5 + i * .7) * .22;
      starPaint.color = Colors.white.withValues(alpha: opacity.clamp(.18, .70));
      canvas.drawCircle(
        Offset(anchor.dx * size.width + drift, anchor.dy * size.height),
        i.isEven ? 1.8 : 1.2,
        starPaint,
      );
    }

    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: .0),
          _ArenaColors.goldLight.withValues(alpha: .72),
          Colors.white.withValues(alpha: .0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.18 + i * .20) + math.sin(phase + i) * 10;
      final x = (progress * size.width * 1.35 + i * 210) % (size.width + 220);
      canvas.drawLine(
        Offset(x - 190, y + 34),
        Offset(x, y),
        trailPaint,
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * .18);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _ArenaColors.goldLight.withValues(alpha: .82);
    for (var i = 0; i < 3; i++) {
      final radius = 62 + i * 25 + math.sin(phase + i) * 3;
      canvas.drawCircle(Offset.zero, radius, ringPaint);
    }
    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: .62);
    for (var i = 0; i < 8; i++) {
      canvas.rotate(math.pi / 4);
      canvas.drawLine(const Offset(0, -44), const Offset(0, -115), runePaint);
      canvas.drawCircle(const Offset(0, -126), 4, runePaint);
    }
    canvas.restore();

    final floorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .14);
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .52, size.height * (.78 + i * .035)),
          width: size.width * (.48 + i * .10),
          height: 24 + i * 8,
        ),
        floorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SummonBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SummonHeroReel extends StatelessWidget {
  const _SummonHeroReel({
    required this.heroes,
    required this.progress,
    required this.onPreviewTap,
  });

  final List<ArenaHero> heroes;
  final double progress;
  final VoidCallback onPreviewTap;

  static const double _cardWidth = 54;
  static const double _cardGap = 8;

  @override
  Widget build(BuildContext context) {
    if (heroes.isEmpty) return const SizedBox.shrink();
    final loopWidth = heroes.length * (_cardWidth + _cardGap);
    final offset = -progress * loopWidth;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ArenaColors.ink.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border:
            Border.all(color: _ArenaColors.goldLight.withValues(alpha: .42)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3330263C),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_motion_rounded,
                color: _ArenaColors.goldLight,
                size: 14,
              ),
              const SizedBox(width: 5),
              const Text(
                '星轨巡礼',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              MoePressable(
                onTap: onPreviewTap,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ArenaColors.goldLight.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    border: Border.all(
                      color: _ArenaColors.goldLight.withValues(alpha: .42),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '卡池预览',
                        style: TextStyle(
                          color: Color(0xFFFFF0C2),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.expand_more_rounded,
                        color: Color(0xFFFFF0C2),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SummonReelLightPainter(progress),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(offset, 0),
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: loopWidth * 2,
                      maxWidth: loopWidth * 2,
                      child: Row(
                        children: [
                          for (final hero in [...heroes, ...heroes])
                            Padding(
                              padding: const EdgeInsets.only(right: _cardGap),
                              child: _SummonReelCard(
                                hero: hero,
                                width: _cardWidth,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummonReelCard extends StatelessWidget {
  const _SummonReelCard({
    required this.hero,
    required this.width,
  });

  final ArenaHero hero;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(hero.rarity);
    final imageAsset = hero.imageAsset;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent,
              accent.withValues(alpha: .42),
            ],
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageAsset == null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(hero.color).withValues(alpha: .90),
                        _ArenaColors.ink,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _roleIcon(hero.role),
                      color: _ArenaColors.goldLight,
                      size: 22,
                    ),
                  ),
                )
              else
                Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      _ArenaColors.ink.withValues(alpha: .84),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Text(
                  hero.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [
                      Shadow(color: _ArenaColors.ink, blurRadius: 4),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _RarityMark(hero.rarity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummonPoolHeroCard extends StatelessWidget {
  const _SummonPoolHeroCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.up,
    required this.onTap,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final bool up;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(hero.rarity);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              up ? _ArenaColors.goldLight : accent.withValues(alpha: .82),
              accent.withValues(alpha: owned ? .34 : .20),
            ],
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? Colors.white : accent.withValues(alpha: .72),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected || up
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: .34),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: owned
                ? _ArenaColors.cream.withValues(alpha: .96)
                : _ArenaColors.ink.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              _AvatarCircle(hero: hero, locked: !owned),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            up ? '${hero.name} · 本期UP' : hero.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: owned ? _ArenaColors.ink : Colors.white,
                              fontSize: MoeTokens.textXs,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _RarityMark(hero.rarity),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _HeroMetaChip(
                          icon: _roleIcon(hero.role),
                          label: hero.role,
                          color: accent,
                        ),
                        _HeroMetaChip(
                          icon: Icons.flag_rounded,
                          label: hero.faction,
                          color: owned ? _ArenaColors.violet : Colors.white70,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummonReelLightPainter extends CustomPainter {
  const _SummonReelLightPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sweepX = (size.width + 80) * progress - 40;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: .0),
          _ArenaColors.goldLight.withValues(alpha: .24),
          Colors.white.withValues(alpha: .0),
        ],
      ).createShader(Rect.fromLTWH(sweepX - 34, 0, 68, size.height));
    final path = Path()
      ..moveTo(sweepX - 28, size.height)
      ..lineTo(sweepX + 2, 0)
      ..lineTo(sweepX + 34, 0)
      ..lineTo(sweepX + 4, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SummonReelLightPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CharacterBackground extends StatelessWidget {
  const _CharacterBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFC4DFF1),
              Color(0xFFFFF1D0),
              Color(0xFFC2AAD1),
            ],
          ),
        ),
        child: SizedBox.expand(),
      );
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: _ArenaColors.violet,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFFFF1D1), fontSize: 11),
          ),
        ],
      );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(MoeTokens.spaceMd),
        decoration: BoxDecoration(
          color: _ArenaColors.cream.withValues(alpha: .95),
          border: Border.all(color: const Color(0xFFE6C67E)),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332E2440),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MoePressable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.all(MoeTokens.spaceSm),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8E9),
                Color(0xFFFFEFC4),
              ],
            ),
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            border: Border.all(color: _ArenaColors.gold.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2430263C),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ArenaColors.violet.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    ),
                    child: Icon(
                      icon,
                      color: _ArenaColors.violet,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.ink,
                        fontSize: MoeTokens.textSm,
                        fontWeight: MoeTokens.fontWeightTitle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ArenaColors.muted,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LobbyPrimaryAction extends StatelessWidget {
  const _LobbyPrimaryAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MoeTokens.spaceMd),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_ArenaColors.goldLight, _ArenaColors.gold],
            ),
            borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
            border: Border.all(color: Colors.white.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FFE39B),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
                child: const Icon(
                  Icons.generating_tokens_rounded,
                  color: _ArenaColors.violet,
                  size: 22,
                ),
              ),
              const SizedBox(width: MoeTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.ink,
                        fontSize: MoeTokens.textMd,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.violet,
                        fontSize: MoeTokens.textXs,
                        fontWeight: MoeTokens.fontWeightTitle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _LobbyMiniAction extends StatelessWidget {
  const _LobbyMiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MoePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _ArenaColors.cream.withValues(alpha: .90),
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            border: Border.all(color: _ArenaColors.gold.withValues(alpha: .55)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _ArenaColors.violet, size: 18),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ArenaColors.violet,
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LobbyResourceLine extends StatelessWidget {
  const _LobbyResourceLine({
    required this.crystals,
    required this.floor,
  });

  final int crystals;
  final int floor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _ArenaColors.ink.withValues(alpha: .40),
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border:
              Border.all(color: _ArenaColors.goldLight.withValues(alpha: .28)),
        ),
        child: Text(
          '星晶 $crystals  ·  爬塔第 $floor 层',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: MoeTokens.textXs,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _LobbyGoalCard extends StatelessWidget {
  const _LobbyGoalCard({
    required this.title,
    required this.body,
    required this.progressLabel,
    required this.progress,
  });

  final String title;
  final String body;
  final String progressLabel;
  final double progress;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: _ArenaColors.violet,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ArenaColors.violet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ArenaColors.muted,
                fontSize: MoeTokens.textXs,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1).toDouble(),
                      minHeight: 6,
                      color: _ArenaColors.gold,
                      backgroundColor:
                          _ArenaColors.violet.withValues(alpha: .12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  progressLabel,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({
    required this.hero,
    this.locked = false,
    this.showFrame = false,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool locked;
  final bool showFrame;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? hero.imageAsset;
    Widget portrait = asset == null
        ? _LargeHeroPlaceholder(color: hero.color)
        : ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          );
    if (tint != null && asset != null) {
      portrait = ColorFiltered(
        colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
        child: portrait,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border:
            showFrame ? Border.all(color: _ArenaColors.gold, width: 2) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x4430263C),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          portrait,
          if (locked)
            DecoratedBox(
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .48),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 34),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .74),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${hero.name} · ${hero.rarity.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeHeroPlaceholder extends StatelessWidget {
  const _LargeHeroPlaceholder({required this.color});

  final int color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Color(color).withValues(alpha: .86),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Text(
            '✦',
            style: TextStyle(fontSize: 42, color: Color(0xFFFFF4D0)),
          ),
        ),
      );
}

class _FormationSlot extends StatelessWidget {
  const _FormationSlot({
    required this.hero,
    required this.selected,
    required this.positionLabel,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero? hero;
  final bool selected;
  final String positionLabel;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final currentHero = hero;
    final rarityColor = currentHero == null
        ? _ArenaColors.goldLight
        : _rarityAccent(currentHero.rarity);
    return Container(
      width: 108,
      height: 118,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            selected ? Colors.white : rarityColor,
            rarityColor.withValues(alpha: .50),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: rarityColor.withValues(alpha: .55),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: currentHero == null
            ? const ColoredBox(
                color: Colors.white12,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: _ArenaColors.goldLight,
                    size: 32,
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  _FormationSlotPortrait(
                    hero: currentHero,
                    imageAsset: imageAsset,
                    tint: tint,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x0030263C),
                          Color(0xCC30263C),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _ArenaColors.ink.withValues(alpha: .58),
                        borderRadius:
                            BorderRadius.circular(MoeTokens.radiusFull),
                      ),
                      child: Text(
                        positionLabel,
                        style: const TextStyle(
                          color: _ArenaColors.goldLight,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _RarityMark(currentHero.rarity),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentHero.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: _ArenaColors.ink, blurRadius: 5),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              _roleIcon(currentHero.role),
                              color: _ArenaColors.goldLight,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${currentHero.role} · ${currentHero.faction}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFF0C2),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      color: _ArenaColors.ink,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FormationSlotPortrait extends StatelessWidget {
  const _FormationSlotPortrait({
    required this.hero,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? hero.imageAsset;
    if (asset != null) {
      Widget image = Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
      if (tint != null) {
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
          child: image,
        );
      }
      return image;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(hero.color).withValues(alpha: .86),
            _ArenaColors.ink.withValues(alpha: .92),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _roleIcon(hero.role),
          color: _ArenaColors.goldLight.withValues(alpha: .86),
          size: 34,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.inFormation,
    required this.stars,
    required this.onTap,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final bool inFormation;
  final int stars;
  final VoidCallback onTap;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityAccent(hero.rarity);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Opacity(
        opacity: owned ? 1 : .55,
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                rarityColor.withValues(alpha: selected ? .96 : .72),
                _ArenaColors.cream,
              ],
            ),
            border: Border.all(color: rarityColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected || inFormation
                ? [
                    BoxShadow(
                      color: rarityColor.withValues(alpha: .34),
                      blurRadius: 14,
                      spreadRadius: selected ? 1 : 0,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: owned
                  ? _ArenaColors.cream.withValues(alpha: .96)
                  : _ArenaColors.ink.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                _AvatarCircle(
                  hero: hero,
                  locked: !owned,
                  imageAsset: imageAsset,
                  tint: tint,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hero.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _RarityMark(hero.rarity),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _HeroMetaChip(
                        icon: _roleIcon(hero.role),
                        label: hero.role,
                        color: rarityColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inFormation
                            ? '上阵中 · ${hero.faction}'
                            : owned
                                ? '${hero.faction} · $stars星'
                                : '未解锁 · ${hero.faction}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: inFormation
                              ? _ArenaColors.violet
                              : _ArenaColors.muted,
                          fontWeight:
                              inFormation ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCollectionCard extends StatelessWidget {
  const _HeroCollectionCard({
    required this.hero,
    required this.owned,
    required this.selected,
    required this.shards,
    required this.stars,
    required this.power,
    required this.inFormation,
    required this.onTap,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool owned;
  final bool selected;
  final int shards;
  final int stars;
  final int power;
  final bool inFormation;
  final VoidCallback onTap;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityAccent(hero.rarity);
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              rarityColor.withValues(alpha: owned ? .86 : .42),
              _raritySurface(hero.rarity).withValues(alpha: owned ? .92 : .46),
            ],
          ),
          border: Border.all(color: rarityColor, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected || inFormation
              ? [
                  BoxShadow(
                    color: rarityColor.withValues(alpha: .30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: owned
                ? _ArenaColors.cream.withValues(alpha: .96)
                : _ArenaColors.ink.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _AvatarCircle(
                hero: hero,
                locked: !owned,
                imageAsset: imageAsset,
                tint: tint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            owned ? hero.name : '${hero.name} · 未解锁',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: owned ? _ArenaColors.ink : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _RarityMark(hero.rarity),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _HeroMetaChip(
                          icon: _roleIcon(hero.role),
                          label: hero.role,
                          color: rarityColor,
                        ),
                        _HeroMetaChip(
                          icon: Icons.flag_rounded,
                          label: hero.faction,
                          color: _ArenaColors.violet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      owned
                          ? '战力 $power · ${hero.skillName}'
                          : '碎片 $shards / 40',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: owned ? _ArenaColors.violet : Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (inFormation)
                    _MiniStatusPill('上阵')
                  else
                    _MiniStatusPill(owned ? '$stars星' : '召唤'),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: owned ? _ArenaColors.muted : Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _ArenaColors.violet.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ArenaColors.violet,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _RarityMark extends StatelessWidget {
  const _RarityMark(this.rarity);

  final ArenaRarity rarity;

  @override
  Widget build(BuildContext context) {
    final accent = _rarityAccent(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .18),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(3),
          bottomLeft: Radius.circular(3),
          bottomRight: Radius.circular(7),
        ),
        border: Border.all(color: accent.withValues(alpha: .82)),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          color: rarity == ArenaRarity.ssr ? _ArenaColors.ink : accent,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: color.withValues(alpha: .26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 8, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.hero,
    this.locked = false,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero hero;
  final bool locked;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset ?? hero.imageAsset;
    Widget child;
    if (locked && asset == null) {
      child = const _LockedAvatarSilhouette();
    } else if (asset == null) {
      child = const Center(
        child: Text(
          '✦',
          style: TextStyle(color: Color(0xFFFFF3C7), fontSize: 18),
        ),
      );
    } else {
      Widget image = Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
      if (tint != null) {
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
          child: image,
        );
      }
      child = ClipOval(
        child: locked
            ? ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF30263C),
                  BlendMode.saturation,
                ),
                child: image,
              )
            : image,
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(hero.color),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335A3F7D),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (locked)
            DecoratedBox(
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .46),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }
}

class _LockedAvatarSilhouette extends StatelessWidget {
  const _LockedAvatarSilhouette();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5C4A6C), Color(0xFF21192D)],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.person_rounded,
            color: Colors.white.withValues(alpha: .34),
            size: 26,
          ),
        ),
      );
}

class _BattleUnit extends StatelessWidget {
  const _BattleUnit({
    required this.label,
    required this.hp,
    this.maxHp = ArenaViewModel.enemyMaxHp,
    this.hero,
    this.intentLabel,
    this.enemy = false,
    this.active = false,
    this.selected = false,
    this.onTap,
    this.imageAsset,
    this.tint,
  });

  final ArenaHero? hero;
  final String label;
  final String? intentLabel;
  final int hp;
  final int maxHp;
  final bool enemy;
  final bool active;
  final bool selected;
  final VoidCallback? onTap;
  final String? imageAsset;
  final int? tint;

  @override
  Widget build(BuildContext context) {
    if (!enemy && hero == null) {
      return const Align(
        alignment: Alignment.bottomCenter,
        child: _EmptyFormationSlot(),
      );
    }
    final unitColor =
        enemy ? _ArenaColors.ink : Color(hero?.color ?? 0xFFB88BCE);
    final portraitAsset = imageAsset ?? hero?.imageAsset;
    Widget portrait = portraitAsset == null
        ? _UnitPlaceholder(color: unitColor, enemy: enemy)
        : Image.asset(
            portraitAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          );
    if (portraitAsset != null && tint != null) {
      portrait = ColorFiltered(
        colorFilter: ColorFilter.mode(Color(tint!), BlendMode.modulate),
        child: portrait,
      );
    }
    final unit = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, active ? -5 : 0, 0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (intentLabel != null)
            Positioned(
              top: 0,
              child: _EnemyIntentPill(intentLabel!),
            ),
          if (selected)
            Positioned(
              bottom: 2,
              child: Container(
                width: 86,
                height: 24,
                decoration: BoxDecoration(
                  color: _ArenaColors.goldLight.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x88FFE39B),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 72,
              height: 18,
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .20),
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              width: 70,
              height: 86,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enemy
                      ? const [Color(0xFF5B466A), Color(0xFF241A31)]
                      : [unitColor.withValues(alpha: .88), _ArenaColors.cream],
                ),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : active
                          ? _ArenaColors.goldLight
                          : _ArenaColors.gold,
                  width: selected || active ? 3 : 2,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5530263C),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: portrait,
            ),
          ),
          Positioned(
            bottom: 3,
            left: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _ArenaColors.ink.withValues(alpha: .78),
                borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                    child: LinearProgressIndicator(
                      value: (hp / (maxHp <= 0 ? 1 : maxHp))
                          .clamp(0, 1)
                          .toDouble(),
                      minHeight: 4,
                      color: enemy
                          ? const Color(0xFFD47E9B)
                          : const Color(0xFF79B9B0),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return unit;
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: unit,
    );
  }
}

class _EmptyFormationSlot extends StatelessWidget {
  const _EmptyFormationSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _ArenaColors.cream.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ArenaColors.gold.withValues(alpha: .7)),
      ),
      child: const Text(
        '空位',
        style: TextStyle(
          color: _ArenaColors.violet,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UnitPlaceholder extends StatelessWidget {
  const _UnitPlaceholder({required this.color, required this.enemy});

  final Color color;
  final bool enemy;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _UnitPlaceholderPainter(color: color, enemy: enemy),
        child: const SizedBox.expand(),
      );
}

class _EnemyIntentPill extends StatelessWidget {
  const _EnemyIntentPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF3B2A4C).withValues(alpha: .88),
          borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
          border: Border.all(color: const Color(0xFFFFC4D4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4430263C),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFFC4D4),
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

class _BattlePile extends StatelessWidget {
  const _BattlePile({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _ArenaColors.ink.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: _ArenaColors.goldLight.withValues(alpha: .45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: _ArenaColors.goldLight,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleHandStack extends StatelessWidget {
  const _BattleHandStack({
    required this.cards,
    required this.energy,
    required this.finished,
    required this.lastPlayedCardIndex,
    this.queuedCards = const [],
    this.hiddenCards = const [],
    required this.pulse,
    required this.onPlay,
  });

  final List<ArenaCard> cards;
  final int energy;
  final bool finished;
  final int lastPlayedCardIndex;
  final List<ArenaCard> queuedCards;
  final List<ArenaCard> hiddenCards;
  final double pulse;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (cards.isEmpty) return const SizedBox.shrink();
        const cardWidth = 72.0;
        const cardHeight = 100.0;
        const maxStep = 64.0;
        final available = constraints.maxWidth;
        final step = cards.length <= 1
            ? 0.0
            : math.min(maxStep, (available - cardWidth) / (cards.length - 1));
        final handWidth = cardWidth + step * (cards.length - 1);
        final start = math.max(0.0, (available - handWidth) / 2);
        final middle = (cards.length - 1) / 2;
        final cardTop = math.max(0.0, constraints.maxHeight - cardHeight);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < cards.length; index++)
              _queuedHandCard(
                index: index,
                cards: cards,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                start: start,
                step: step,
                middle: middle,
                cardTop: cardTop,
              ),
          ],
        );
      },
    );
  }

  Widget _queuedHandCard({
    required int index,
    required List<ArenaCard> cards,
    required double cardWidth,
    required double cardHeight,
    required double start,
    required double step,
    required double middle,
    required double cardTop,
  }) {
    final queuedAt =
        queuedCards.indexWhere((card) => identical(card, cards[index]));
    final raised = index == lastPlayedCardIndex || queuedAt >= 0;
    final lift = queuedAt >= 0 && queuedCards.length > 1 ? 28.0 : 16.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      left: start + step * index,
      top: cardTop - (raised ? lift : 0),
      child: Transform.rotate(
        angle: (index - middle) * .04,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity:
              hiddenCards.any((card) => identical(card, cards[index])) ? 0 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _SkillCard(
                card: cards[index],
                enabled: !finished && energy >= cards[index].cost,
                highlighted: raised,
                pulse: pulse,
                width: cardWidth,
                height: cardHeight,
                onTap: () => onPlay(index),
              ),
              if (queuedAt >= 0)
                Positioned(
                  right: -4,
                  top: -6,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: _ArenaColors.violet,
                    child: Text(
                      '${queuedAt + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.card,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
    this.pulse = 0,
    this.width = 78,
    this.height = 124,
  });

  final ArenaCard card;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;
  final double pulse;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final glow = enabled ? (.45 + math.sin(pulse * math.pi * 2) * .18) : .16;
    return MoePressable(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : .54,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.bottomCenter,
          transform: Matrix4.translationValues(0, highlighted ? -10 : 0, 0)
            ..scaleByDouble(
              highlighted ? 1.06 : 1.0,
              highlighted ? 1.06 : 1.0,
              1,
              1,
            ),
          width: width,
          height: height,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(card.color).withValues(alpha: .95),
                _ArenaColors.cream,
              ],
            ),
            border: Border.all(
              color: highlighted
                  ? Colors.white
                  : enabled
                      ? _ArenaColors.goldLight.withValues(alpha: glow + .30)
                      : _ArenaColors.goldLight.withValues(alpha: .52),
              width: highlighted ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? Colors.white.withValues(alpha: .48)
                    : _ArenaColors.goldLight.withValues(alpha: glow),
                blurRadius: highlighted ? 16 : 8 + glow * 8,
                spreadRadius: enabled ? 1 : 0,
                offset: const Offset(0, 5),
              ),
              const BoxShadow(
                color: Color(0x44302B42),
                blurRadius: 9,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${card.elements.join('·')}${card.trait == '无' ? '' : ' · ${card.trait}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ArenaColors.violet,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: _ArenaColors.cream,
                    child: Text(
                      '${card.cost}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _ArenaColors.violet,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(
                    card.icon,
                    style: const TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: _ArenaColors.violet, blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                card.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8, color: _ArenaColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BattleComboCast extends StatelessWidget {
  const _BattleComboCast({
    required this.cards,
    required this.t,
    required this.target,
    required this.impact,
  });

  final List<ArenaCard> cards;
  final double t;
  final Alignment target;
  final int? impact;

  static const double _gatherEnd = .36;
  static const double _fuseEnd = .56;
  static const double _hitAt = .74;

  @override
  Widget build(BuildContext context) {
    final meet = Alignment(target.x * .42, target.y - .22);
    return IgnorePointer(
      child: Stack(
        children: [
          if (t < _fuseEnd) ..._gathering(meet),
          if (t >= _gatherEnd) _fusedBolt(meet),
          if (t >= _hitAt) _impactBurst(),
        ],
      ),
    );
  }

  List<Widget> _gathering(Alignment meet) {
    final gather = Curves.easeOutBack.transform((t / _gatherEnd).clamp(0, 1));
    final fuse = t <= _gatherEnd
        ? 0.0
        : ((t - _gatherEnd) / (_fuseEnd - _gatherEnd)).clamp(0.0, 1.0);
    return [
      for (var index = 0; index < cards.length; index++)
        _card(
          cards[index],
          Alignment.lerp(
            Alignment(-.42 + index * .28, 1.2),
            meet,
            gather,
          )!,
          (1 - fuse).clamp(0.0, 1.0),
          .9 + .2 * gather,
          (index - (cards.length - 1) / 2) * .35 * (1 - gather),
        ),
    ];
  }

  Widget _fusedBolt(Alignment meet) {
    final fuse = ((t - _gatherEnd) / (_fuseEnd - _gatherEnd)).clamp(0.0, 1.0);
    final travel = t <= _fuseEnd
        ? 0.0
        : Curves.easeIn.transform(
            ((t - _fuseEnd) / (_hitAt - _fuseEnd)).clamp(0.0, 1.0),
          );
    final pos = Alignment.lerp(meet, target, travel)!;
    final flash = t >= _hitAt ? (1 - (t - _hitAt) / .16).clamp(0.0, 1.0) : fuse;
    final lead = cards.first;
    return Align(
      alignment: pos,
      child: Transform.rotate(
        angle: travel * .8,
        child: Opacity(
          opacity: t >= _hitAt ? flash : 1,
          child: Container(
            width: 54 + 28 * fuse,
            height: 74 + 18 * fuse,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(lead.color),
                  Color(cards.last.color),
                  Colors.white,
                ],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: .85),
                  blurRadius: 18 + 24 * fuse,
                  spreadRadius: 2 + 8 * fuse,
                ),
                BoxShadow(
                  color: Color(lead.color).withValues(alpha: .8),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Text(
              lead.icon,
              style: const TextStyle(fontSize: 30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _impactBurst() {
    final p = ((t - _hitAt) / (1 - _hitAt)).clamp(0.0, 1.0);
    final label = impact == null
        ? ''
        : impact! < 0
            ? '+${-impact!}'
            : '-$impact';
    return Stack(
      children: [
        Align(
          alignment: target,
          child: Opacity(
            opacity: (1 - p).clamp(0.0, 1.0),
            child: Container(
              width: 48 + 140 * p,
              height: 48 + 140 * p,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4 * (1 - p),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _ArenaColors.goldLight.withValues(alpha: .7),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (label.isNotEmpty)
          Align(
            alignment: target,
            child: Transform.translate(
              offset: Offset(0, -36 - 52 * p),
              child: Text(
                label,
                style: TextStyle(
                  color: impact! < 0
                      ? const Color(0xFF2F8F78)
                      : const Color(0xFFFF4D6A),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(
    ArenaCard card,
    Alignment alignment,
    double opacity,
    double scale,
    double angle,
  ) {
    return Align(
      alignment: alignment,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 58,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(card.color),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Color(card.color).withValues(alpha: .75),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Text(card.icon, style: const TextStyle(fontSize: 26)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleCastFlight extends StatelessWidget {
  const _BattleCastFlight({
    required this.card,
    required this.t,
    required this.target,
  });

  final ArenaCard card;
  final double t;
  final Alignment target;

  @override
  Widget build(BuildContext context) {
    final travel = Curves.easeIn.transform((t / .42).clamp(0.0, 1.0));
    final fade = t < .42 ? 1.0 : (1 - (t - .42) / .2).clamp(0.0, 1.0);
    final base = Alignment.lerp(const Alignment(0, 1.15), target, travel)!;
    final arched = Alignment(base.x, base.y - math.sin(travel * math.pi) * .48);
    final smash = t < .42 ? 0.0 : ((t - .42) / .14).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Stack(
        children: [
          _flyingCard(card, arched, fade, travel, smash, 68, 90),
          if (smash > 0)
            Align(
              alignment: target,
              child: Opacity(
                opacity: (1 - smash).clamp(0.0, 1.0),
                child: Container(
                  width: 36 + 80 * smash,
                  height: 36 + 80 * smash,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _flyingCard(
    ArenaCard card,
    Alignment alignment,
    double opacity,
    double travel,
    double smash,
    double width,
    double height,
  ) {
    final scaleX = 1.16 - .22 * travel + .5 * smash;
    final scaleY = 1.16 - .18 * travel - .4 * smash;
    return Align(
      alignment: alignment,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: -.6 * (1 - travel) + .4 * travel,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
            child: Container(
              width: width,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(card.color),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Color(card.color).withValues(alpha: .8),
                    blurRadius: 18 + 16 * smash,
                    spreadRadius: 2 + 4 * smash,
                  ),
                ],
              ),
              child: Text(card.icon, style: TextStyle(fontSize: width * .44)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleStrikeLayer extends StatelessWidget {
  const _BattleStrikeLayer({
    required this.strike,
    required this.t,
  });

  final ArenaStrike strike;
  final double t;

  List<Alignment> get _anchors {
    switch (strike.targeting) {
      case ArenaCardTargeting.allEnemies:
        return _enemySlots;
      case ArenaCardTargeting.allyTeam:
        return _friendlySlots;
      case ArenaCardTargeting.singleEnemy:
        final index = strike.targetIndex.clamp(0, _enemySlots.length - 1);
        return [_enemySlots[index]];
    }
  }

  @override
  Widget build(BuildContext context) {
    final impact = t < .08 ? 0.0 : ((t - .08) / .92).clamp(0.0, 1.0);
    final color = Color(strike.color);
    final label =
        strike.damage < 0 ? '+${-strike.damage}' : '-${strike.damage}';
    final labelColor =
        strike.damage < 0 ? const Color(0xFF2F8F78) : const Color(0xFFD4476A);
    return IgnorePointer(
      child: Stack(
        children: [
          for (final target in _anchors) ...[
            _impactMark(strike.school, target, impact, color),
            for (var spark = 0; spark < 6; spark++)
              Align(
                alignment: target,
                child: Transform.translate(
                  offset: Offset(
                    math.cos(spark * math.pi / 3) * 36 * impact,
                    math.sin(spark * math.pi / 3) * 28 * impact,
                  ),
                  child: Opacity(
                    opacity: impact <= 0 ? 0 : (1 - impact).clamp(0.0, 1.0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: target,
              child: Transform.translate(
                offset: Offset(0, -28 - 48 * impact),
                child: Opacity(
                  opacity: impact <= 0 ? 0 : (1 - impact * .2).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: impact < .22
                        ? .35 + impact / .22 * 1.05
                        : 1.4 - impact * .45,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _impactMark(
    String school,
    Alignment target,
    double impact,
    Color color,
  ) {
    final fade = impact <= 0 ? 0.0 : (1 - impact).clamp(0.0, 1.0);
    switch (school) {
      case '爆发':
        return Align(
          alignment: target,
          child: Opacity(
            opacity: fade,
            child: Container(
              width: 28 + 90 * impact,
              height: 28 + 90 * impact,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4 * (1 - impact * .6)),
              ),
            ),
          ),
        );
      case '庇护':
        return Align(
          alignment: target,
          child: Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(0, -20 * impact),
              child: Icon(
                Icons.favorite_rounded,
                color: const Color(0xFF2F8F78),
                size: 18 + 22 * impact,
              ),
            ),
          ),
        );
      case '敌袭':
        return Align(
          alignment: target,
          child: Opacity(
            opacity: fade,
            child: Transform.rotate(
              angle: .4,
              child: Icon(
                Icons.flash_on_rounded,
                color: const Color(0xFFD4476A),
                size: 22 + 28 * impact,
              ),
            ),
          ),
        );
      default:
        return Align(
          alignment: target,
          child: Opacity(
            opacity: fade,
            child: Transform.rotate(
              angle: -.8,
              child: Container(
                width: 18 + 78 * impact,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, color, Colors.white],
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _BattleComboBurst extends StatelessWidget {
  const _BattleComboBurst({
    required this.combo,
    required this.card,
    this.charged = false,
  });

  final ArenaCombo combo;
  final ArenaCard card;
  final bool charged;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          scale: charged ? 1.12 : 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Container(
              key: ValueKey('${card.name}-${combo.name}'),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: .0),
                    _ArenaColors.ink.withValues(alpha: .84),
                    Color(card.color).withValues(alpha: .78),
                    Colors.white.withValues(alpha: .0),
                  ],
                ),
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6630263C),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    color: _ArenaColors.goldLight,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    combo.name,
                    style: const TextStyle(
                      color: _ArenaColors.goldLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: _ArenaColors.ink, blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    combo.formula,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${card.sourceHeroName} · ${card.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BattleRewardPanel extends StatelessWidget {
  const _BattleRewardPanel({
    required this.choices,
    required this.crystalReward,
    required this.onChoose,
    required this.onShare,
  });

  final List<ArenaCard> choices;
  final int crystalReward;
  final ValueChanged<int> onChoose;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => _SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '胜利奖励 · 星晶 +$crystalReward',
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: MoeTokens.textSm,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
                const Spacer(),
                const Text(
                  '选 1 张放进牌组',
                  style: TextStyle(
                    color: _ArenaColors.muted,
                    fontSize: MoeTokens.textXs,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MoeTokens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                choices.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MoeTokens.spaceXs,
                  ),
                  child: _SkillCard(
                    card: choices[index],
                    enabled: true,
                    highlighted: false,
                    onTap: () => onChoose(index),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MoeTokens.spaceXs),
            MoePressable(
              onTap: onShare,
              borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      size: 14,
                      color: _ArenaColors.violet,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '分享战绩',
                      style: TextStyle(
                        color: _ArenaColors.violet,
                        fontSize: MoeTokens.textXs,
                        fontWeight: MoeTokens.fontWeightSubtitle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _SummonResultCard extends StatelessWidget {
  const _SummonResultCard({required this.result});

  final ArenaSummonResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(result.hero.color).withValues(alpha: .28),
            _ArenaColors.cream,
          ],
        ),
        border: Border.all(
          color: result.hero.rarity == ArenaRarity.ssr
              ? _ArenaColors.gold
              : const Color(0xFFE6D5B4),
          width: result.hero.rarity == ArenaRarity.ssr ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AvatarCircle(hero: result.hero),
          const SizedBox(height: 4),
          Text(
            result.hero.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          Text(
            result.isNew ? 'NEW' : '+${result.shards} 碎片',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: _ArenaColors.violet,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterProgressCard extends StatelessWidget {
  const _CharacterProgressCard({
    required this.hero,
    required this.owned,
    required this.shards,
  });

  final ArenaHero hero;
  final bool owned;
  final int shards;

  @override
  Widget build(BuildContext context) {
    final target = hero.rarity == ArenaRarity.ssr ? 60 : 40;
    final progress = (shards / target).clamp(0.0, 1.0);
    return _SurfaceCard(
      child: Row(
        children: [
          _AvatarCircle(hero: hero, locked: !owned),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owned ? '碎片升星' : '召唤解锁',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: MoeTokens.textSm,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  owned
                      ? '碎片 $shards / $target · 重复角色会自动转化'
                      : '未解锁 · 可通过当前召唤池获得',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: MoeTokens.textXs,
                    color: _ArenaColors.muted,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  child: LinearProgressIndicator(
                    value: owned ? progress : 0,
                    minHeight: 6,
                    color: _rarityAccent(hero.rarity),
                    backgroundColor: _ArenaColors.violet.withValues(alpha: .12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CultivationRow extends StatelessWidget {
  const _CultivationRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.ready,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: ready
              ? _ArenaColors.goldLight.withValues(alpha: .28)
              : _ArenaColors.violet.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          border: Border.all(
            color: ready
                ? _ArenaColors.gold.withValues(alpha: .36)
                : _ArenaColors.violet.withValues(alpha: .12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: ready ? _ArenaColors.violet : _ArenaColors.muted,
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 62,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ArenaColors.violet,
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ArenaColors.muted,
                  fontSize: MoeTokens.textXs,
                  fontWeight: MoeTokens.fontWeightSubtitle,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EquipmentSlot extends StatelessWidget {
  const _EquipmentSlot(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: _ArenaColors.ink.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            border: Border.all(color: _ArenaColors.gold.withValues(alpha: .32)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 13,
                color: _ArenaColors.violet,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ArenaColors.violet,
                    fontSize: MoeTokens.textXs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatBox extends StatelessWidget {
  const _StatBox(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D3),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: _ArenaColors.muted),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _ArenaColors.violet,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _WindowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .3);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .30,
        size.height * .18,
        size.width * .4,
        size.height * .55,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .48, size.height * .18, 4, size.height * .55),
      Paint()..color = const Color(0x5573568A),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .30, size.height * .43, size.width * .4, 4),
      Paint()..color = const Color(0x5573568A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnitPlaceholderPainter extends CustomPainter {
  _UnitPlaceholderPainter({required this.color, required this.enemy});

  final Color color;
  final bool enemy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .55);
    final body = Paint()
      ..color = enemy ? const Color(0xFF241A31) : color.withValues(alpha: .92);
    final accent = Paint()
      ..color = enemy
          ? const Color(0xFF6F5A7C).withValues(alpha: .70)
          : _ArenaColors.goldLight.withValues(alpha: .88);

    canvas.drawCircle(
      Offset(center.dx, size.height * .26),
      size.width * .18,
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width * .52,
          height: size.height * .55,
        ),
        const Radius.circular(20),
      ),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .23, size.height * .36)
        ..quadraticBezierTo(size.width * .50, size.height * .18,
            size.width * .77, size.height * .36)
        ..lineTo(size.width * .62, size.height * .44)
        ..quadraticBezierTo(size.width * .50, size.height * .32,
            size.width * .38, size.height * .44)
        ..close(),
      accent,
    );
    if (!enemy) {
      canvas.drawCircle(
        Offset(size.width * .57, size.height * .24),
        2.2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(size.width * .57, size.height * .24),
        1.0,
        Paint()..color = _ArenaColors.violet,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UnitPlaceholderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.enemy != enemy;
}

class _FormationLanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ArenaColors.goldLight.withValues(alpha: .50)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .08, size.height * .50),
      Offset(size.width * .92, size.height * .50),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TowerPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final node0 = Offset(size.width * .16, size.height * .66);
    final node1 = Offset(size.width * .35, size.height * .40);
    final node2 = Offset(size.width * .52, size.height * .64);
    final node3 = Offset(size.width * .64, size.height * .34);
    final node4 = Offset(size.width * .82, size.height * .50);
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..shader = LinearGradient(
        colors: [
          _ArenaColors.goldLight.withValues(alpha: .22),
          _ArenaColors.goldLight.withValues(alpha: .78),
          Colors.white.withValues(alpha: .42),
        ],
      ).createShader(Offset.zero & size);
    final dimRoutePaint = Paint()
      ..color = Colors.white.withValues(alpha: .20)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    void drawRoute(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var index = 1; index < points.length; index++) {
        final previous = points[index - 1];
        final current = points[index];
        final control = Offset(
          (previous.dx + current.dx) / 2,
          math.min(previous.dy, current.dy) - size.height * .08,
        );
        path.quadraticBezierTo(control.dx, control.dy, current.dx, current.dy);
      }
      canvas.drawPath(path, paint);
    }

    drawRoute([node0, node1, node3, node4], routePaint);
    drawRoute([node0, node2, node3], dimRoutePaint);
    drawRoute([node2, node4], dimRoutePaint);

    final islandPaint = Paint()
      ..color = _ArenaColors.ink.withValues(alpha: .16)
      ..style = PaintingStyle.fill;
    for (final node in [node0, node1, node2, node3, node4]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(node.dx, node.dy + 31),
          width: 92,
          height: 18,
        ),
        islandPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
