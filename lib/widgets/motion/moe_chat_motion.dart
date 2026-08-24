import 'package:flutter/material.dart';

import '../../constants/feature_flags.dart';
import 'moe_lottie_motion.dart';
import 'moe_motion.dart';

/// 聊天品牌动效 one-shot 骨架：flag 关闭不渲染；
/// 播放完成 / 加载失败 / reduceMotion 都回调 [onComplete]，
/// 由父级移除自身（失败静默降级，不影响消息流程）。
class _MoeChatOneShotFx extends StatefulWidget {
  final String assetPath;
  final double size;
  final VoidCallback? onComplete;

  const _MoeChatOneShotFx({
    required this.assetPath,
    required this.size,
    this.onComplete,
  });

  @override
  State<_MoeChatOneShotFx> createState() => _MoeChatOneShotFxState();
}

class _MoeChatOneShotFxState extends State<_MoeChatOneShotFx> {
  bool _doneNotified = false;

  void _notifyDone() {
    if (_doneNotified) return;
    _doneNotified = true;
    widget.onComplete?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // reduceMotion 时 MoeLottieMotion 不播放也不触发完成，这里兜底通知移除。
    if (moeReduceMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyDone();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.chatBrandMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: MoeLottieMotion(
          assetPath: widget.assetPath,
          onComplete: _notifyDone,
          // 加载失败：不显示内容，直接通知父级移除。
          onError: _notifyDone,
        ),
      ),
    );
  }
}

/// 聊天品牌动效 — 发送成功对勾。
/// 一次性播放，播完通过 [onComplete] 通知父级移除自身。
class MoeSendSuccessFx extends StatelessWidget {
  final VoidCallback? onComplete;

  const MoeSendSuccessFx({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _MoeChatOneShotFx(
      assetPath: 'assets/lottie/chat/send_success.json',
      size: 40,
      onComplete: onComplete,
    );
  }
}

/// 聊天品牌动效 — 新消息弹跳。
class MoeMessagePopFx extends StatelessWidget {
  final VoidCallback? onComplete;

  const MoeMessagePopFx({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _MoeChatOneShotFx(
      assetPath: 'assets/lottie/chat/message_pop.json',
      size: 24,
      onComplete: onComplete,
    );
  }
}
