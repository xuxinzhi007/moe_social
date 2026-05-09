import 'package:flutter/material.dart';

/// 进入视口附近再构建子组件，减轻首屏压力。
/// 必须挂在 [Scrollable]（如 [ListView]）子树内，并监听父级 [ScrollPosition]；
/// 不能使用未 attach 的 [ScrollController]，否则永远不会触发加载。
class LazyLoadWidget extends StatefulWidget {
  final Widget child;
  final double offset;
  final bool once;

  const LazyLoadWidget({
    super.key,
    required this.child,
    this.offset = 100.0,
    this.once = true,
  });

  @override
  State<LazyLoadWidget> createState() => _LazyLoadWidgetState();
}

class _LazyLoadWidgetState extends State<LazyLoadWidget> {
  ScrollPosition? _scrollPosition;
  bool _isVisible = false;
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    final pos = scrollable?.position;
    if (identical(pos, _scrollPosition)) return;

    _scrollPosition?.removeListener(_onScrollPosition);
    _scrollPosition = pos;
    _scrollPosition?.addListener(_onScrollPosition);

    if (_scrollPosition == null) {
      // 不在可滚动区域内时直接展示，避免空白
      if (!_isVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isVisible = true;
            _hasLoaded = true;
          });
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScrollPosition());
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScrollPosition);
    super.dispose();
  }

  void _onScrollPosition() {
    if (!mounted) return;
    if (_hasLoaded && widget.once) return;

    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null || !renderObject.hasSize) return;

    final position = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;

    if (position.dy < screenHeight + widget.offset) {
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
          _hasLoaded = true;
        });
      }
    } else {
      if (_isVisible && !widget.once) {
        setState(() {
          _isVisible = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isVisible ? widget.child : SizedBox(height: widget.offset);
  }
}
