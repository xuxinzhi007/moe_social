import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/gift.dart';

/// 礼物特效管理类
class GiftEffectManager {
  /// 获取礼物特效组件
  static Widget getGiftEffect(Gift gift, {required Animation<double> animation}) {
    switch (gift.id) {
      case 'heart':
        return _HeartGiftEffect(gift: gift, animation: animation);
      case 'flower':
        return _FlowerGiftEffect(gift: gift, animation: animation);
      case 'thumbsup':
        return _ThumbsUpGiftEffect(gift: gift, animation: animation);
      case 'clap':
        return _ClapGiftEffect(gift: gift, animation: animation);
      case 'hug':
        return _HugGiftEffect(gift: gift, animation: animation);
      case 'coffee':
        return _CoffeeGiftEffect(gift: gift, animation: animation);
      case 'cake':
        return _CakeGiftEffect(gift: gift, animation: animation);
      case 'ice_cream':
        return _IceCreamGiftEffect(gift: gift, animation: animation);
      case 'wine':
        return _WineGiftEffect(gift: gift, animation: animation);
      case 'diamond':
        return _DiamondGiftEffect(gift: gift, animation: animation);
      case 'crown':
        return _CrownGiftEffect(gift: gift, animation: animation);
      case 'rocket':
        return _RocketGiftEffect(gift: gift, animation: animation);
      case 'rainbow':
        return _RainbowGiftEffect(gift: gift, animation: animation);
      case 'fireworks':
        return _FireworksGiftEffect(gift: gift, animation: animation);
      case 'unicorn':
        return _UnicornGiftEffect(gift: gift, animation: animation);
      default:
        return _DefaultGiftEffect(gift: gift, animation: animation);
    }
  }
}

/// 爱心礼物特效
class _HeartGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _HeartGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.5)
          .chain(CurveTween(curve: Curves.elasticOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 1).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 鲜花礼物特效
class _FlowerGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _FlowerGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.2)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 0.5).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 点赞礼物特效
class _ThumbsUpGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _ThumbsUpGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.3)
          .chain(CurveTween(curve: Curves.bounceOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 掌声礼物特效
class _ClapGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _ClapGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.2)
          .chain(CurveTween(curve: Curves.easeInOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 0.2).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 拥抱礼物特效
class _HugGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _HugGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.4)
          .chain(CurveTween(curve: Curves.elasticOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 咖啡礼物特效
class _CoffeeGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _CoffeeGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.2)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 蛋糕礼物特效
class _CakeGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _CakeGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.3)
          .chain(CurveTween(curve: Curves.bounceOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 冰淇淋礼物特效
class _IceCreamGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _IceCreamGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.2)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 香槟礼物特效
class _WineGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _WineGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.3)
          .chain(CurveTween(curve: Curves.bounceOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 钻石礼物特效
class _DiamondGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _DiamondGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.5)
          .chain(CurveTween(curve: Curves.elasticOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 1).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 皇冠礼物特效
class _CrownGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _CrownGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.4)
          .chain(CurveTween(curve: Curves.bounceOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 0.5).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 火箭礼物特效
class _RocketGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _RocketGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.3)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(animation),
      child: Transform.translate(
        offset: Offset(0, -animation.value * 20),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 彩虹礼物特效
class _RainbowGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _RainbowGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.5)
          .chain(CurveTween(curve: Curves.elasticOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 1).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 烟花礼物特效
class _FireworksGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _FireworksGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.6)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}

/// 独角兽礼物特效
class _UnicornGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _UnicornGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.4)
          .chain(CurveTween(curve: Curves.elasticOut))
          .animate(animation),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 0.3).animate(animation),
        child: SvgPicture.asset(
          gift.svgPath!,
          width: 64,
          height: 64,
          color: gift.color.withOpacity(animation.value),
        ),
      ),
    );
  }
}

/// 默认礼物特效
class _DefaultGiftEffect extends StatelessWidget {
  final Gift gift;
  final Animation<double> animation;

  const _DefaultGiftEffect({required this.gift, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1.2)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(animation),
      child: SvgPicture.asset(
        gift.svgPath!,
        width: 64,
        height: 64,
        color: gift.color.withOpacity(animation.value),
      ),
    );
  }
}
