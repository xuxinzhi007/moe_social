import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../services/daily_quote_service.dart';

class DailyQuoteWidget extends StatefulWidget {
  final Color textColor;
  final bool embedded;
  final int maxLines;

  const DailyQuoteWidget({
    super.key,
    this.textColor = Colors.white,
    this.embedded = true,
    this.maxLines = 2,
  });

  @override
  State<DailyQuoteWidget> createState() => _DailyQuoteWidgetState();
}

class _DailyQuoteWidgetState extends State<DailyQuoteWidget> {
  String? _quote;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final quote = await DailyQuoteService.fetchQuote();
    if (!mounted) return;
    setState(() {
      _quote = quote;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbeddedContent();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildEmbeddedContent(forceDarkText: true),
    );
  }

  Widget _buildEmbeddedContent({bool forceDarkText = false}) {
    final color = forceDarkText ? Colors.black87 : widget.textColor;
    final text = _quote ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          Shimmer.fromColors(
            baseColor: color.withValues(alpha: 0.3),
            highlightColor: color.withValues(alpha: 0.1),
            child: Container(
              height: 14,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final targetWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width;
              final fittedSize = _fitFontSizeForLineLimit(text, targetWidth);
              return Text(
                text,
                textAlign: TextAlign.start,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TextStyle(
                  fontSize: fittedSize,
                  height: 1.3,
                  color: color.withValues(alpha: 0.95),
                  fontFamily: 'serif',
                  letterSpacing: 0.4,
                ),
              );
            },
          ),
      ],
    );
  }

  double _fitFontSizeForLineLimit(String text, double maxWidth) {
    for (double size = 13; size >= 10; size -= 0.5) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            height: 1.22,
            fontFamily: 'serif',
            letterSpacing: 0.4,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: widget.maxLines,
      )..layout(maxWidth: maxWidth);
      if (!tp.didExceedMaxLines) return size;
    }
    return 10;
  }
}
