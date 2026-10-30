part of 'companion_chat_page.dart';

const _companionThinkPrefKey = 'companion_chat_think';

String _formatContextTokens(int tokens) {
  if (tokens >= 1000) {
    final value = tokens / 1000;
    final digits = value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(digits)}k';
  }
  return '$tokens';
}

class _InlineThink {
  const _InlineThink(this.thinking, this.answer);

  final String thinking;
  final String answer;
}

/// 有的模型会把思考写进正文的 `<think>`，和请求上的思考开关不是一回事。
_InlineThink _splitInlineThink(String raw) {
  const openTag = '<think>';
  const closeTag = '</think>';
  final think = StringBuffer();
  final answer = StringBuffer();
  var rest = raw;
  var open = false;
  while (rest.isNotEmpty) {
    if (!open) {
      final start = rest.indexOf(openTag);
      if (start < 0) {
        final partial = _partialTagSuffix(rest, openTag);
        answer.write(rest.substring(0, rest.length - partial));
        break;
      }
      answer.write(rest.substring(0, start));
      rest = rest.substring(start + openTag.length);
      open = true;
      continue;
    }
    final end = rest.indexOf(closeTag);
    if (end < 0) {
      final partial = _partialTagSuffix(rest, closeTag);
      think.write(rest.substring(0, rest.length - partial));
      break;
    }
    think.write(rest.substring(0, end));
    rest = rest.substring(end + closeTag.length);
    open = false;
  }
  return _InlineThink(think.toString().trim(), answer.toString().trim());
}

int _partialTagSuffix(String text, String tag) {
  final max = tag.length - 1;
  final n = text.length < max ? text.length : max;
  for (var len = n; len > 0; len--) {
    if (tag.startsWith(text.substring(text.length - len))) return len;
  }
  return 0;
}

class _ComposerTrayPill extends StatelessWidget {
  const _ComposerTrayPill({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? MoeTokens.primary.withValues(alpha: 0.12)
        : MoeTokens.softChipBg;
    final border = active
        ? MoeTokens.primary.withValues(alpha: 0.32)
        : MoeTokens.surfaceBorder;
    final fg = active ? MoeTokens.primary : MoeTokens.inkMuted;

    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: MoeTokens.textXs,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyChip extends StatelessWidget {
  const _JourneyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '打开历程，现在是$label',
      child: Material(
        color: MoeTokens.cardBackground,
        shape: const StadiumBorder(
          side: BorderSide(color: AiBrandTokens.companionBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: MoeTokens.pastelPink,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
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

class _ComposerCircleButton extends StatelessWidget {
  const _ComposerCircleButton({
    required this.size,
    required this.child,
    required this.background,
    required this.borderColor,
    this.onTap,
    this.tooltip,
  });

  final double size;
  final Widget child;
  final Color background;
  final Color borderColor;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SpeakChip extends StatelessWidget {
  const _SpeakChip({
    required this.speaking,
    required this.onTap,
    this.busy = false,
  });

  final bool speaking;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = speaking || busy;
    final tooltip = busy ? '合成中，点此停止' : (speaking ? '停止朗读' : '朗读这条');
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 6, 2),
            child: Icon(
              active ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 16,
              color: active ? MoeTokens.primary : MoeTokens.hintText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerStatus extends StatelessWidget {
  const _ComposerStatus({required this.label, required this.listening});

  final String label;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            listening ? Icons.graphic_eq_rounded : Icons.auto_awesome_rounded,
            size: 14,
            color: AiBrandTokens.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AiBrandTokens.companionInkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatItem {
  final String role;
  final String content;
  final String thinking;
  final bool isStreaming;
  final bool isError;
  final String? meta;

  const _ChatItem({
    required this.role,
    required this.content,
    this.thinking = '',
    this.isStreaming = false,
    this.isError = false,
    this.meta,
  });
}

class _ThinkingTrace extends StatefulWidget {
  const _ThinkingTrace({
    required this.text,
    required this.streaming,
    this.indent = 40,
  });

  final String text;
  final bool streaming;
  final double indent;

  @override
  State<_ThinkingTrace> createState() => _ThinkingTraceState();
}

class _ThinkingTraceState extends State<_ThinkingTrace> {
  final _scroll = ScrollController();
  Timer? _tick;
  int _seconds = 0;
  bool _open = false;
  bool _userToggled = false;

  @override
  void initState() {
    super.initState();
    _open = widget.streaming;
    if (widget.streaming) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _seconds = 0;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.streaming) return;
      setState(() => _seconds++);
    });
  }

  @override
  void didUpdateWidget(covariant _ThinkingTrace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streaming && !oldWidget.streaming) _startTick();
    if (!widget.streaming && oldWidget.streaming) _tick?.cancel();
    if (!_userToggled && oldWidget.streaming != widget.streaming) {
      _open = widget.streaming;
    }
    if (_open && widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: widget.indent, bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MoeTokens.softLavenderBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() {
                _userToggled = true;
                _open = !_open;
              }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology_alt_rounded,
                      size: 14,
                      color: MoeTokens.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.streaming ? '正在思考 · $_seconds 秒' : '思考过程',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: MoeTokens.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_open && widget.streaming && widget.text.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  '思考的字会显示在这里',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: MoeTokens.hintText,
                  ),
                ),
              ),
            if (_open && widget.text.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: MoeTokens.hintText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
