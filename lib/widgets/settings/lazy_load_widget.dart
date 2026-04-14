import 'package:flutter/material.dart';

/// 延迟加载组件，当组件进入视口时才会构建
class LazyLoadWidget extends StatefulWidget {
  final Widget child;
  final double offset; // 预加载偏移量
  final bool once; // 是否只加载一次

  const LazyLoadWidget({
    Key? key,
    required this.child,
    this.offset = 100.0,
    this.once = true,
  }) : super(key: key);

  @override
  _LazyLoadWidgetState createState() => _LazyLoadWidgetState();
}

class _LazyLoadWidgetState extends State<LazyLoadWidget> {
  late final ScrollController _scrollController;
  bool _isVisible = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasLoaded && widget.once) return;

    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null) return;

    final position = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

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
