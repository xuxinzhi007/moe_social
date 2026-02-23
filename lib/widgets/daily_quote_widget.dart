import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

class DailyQuoteWidget extends StatefulWidget {
  final Color textColor;
  final bool embedded;

  const DailyQuoteWidget({
    super.key,
    this.textColor = Colors.white,
    this.embedded = true,
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
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    try {
      final uri = Uri.parse(
          // 控制长度，避免出现多行/省略号
          'https://api.52vmy.cn/api/chat/spark?msg=生成一句温暖治愈的每日一文，只输出一句话，不要任何前缀/解释，不要JSON/字段名，控制在18个汉字以内');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final rawText = utf8.decode(response.bodyBytes).trim();

        // 尝试解析 JSON（优先取 answer）
        try {
          final data = jsonDecode(rawText);
          String? content;
          
          if (data is Map) {
            if (data['answer'] is String) {
              content = data['answer'] as String;
            } else if (data['data'] is Map && (data['data'] as Map)['answer'] is String) {
              content = (data['data'] as Map)['answer'] as String;
            }
            if (data.containsKey('content')) {
              content ??= data['content']?.toString();
            } else if (data.containsKey('data')) {
              content ??= data['data']?.toString();
            } else if (data.containsKey('message')) {
              content ??= data['message']?.toString();
            }
          }
          
          content ??= _extractAnswerFromLooseText(rawText);
          content = _cleanQuote(content);
          if (content != null && content.isNotEmpty) {
            
            if (mounted) {
              setState(() {
                _quote = content;
                _isLoading = false;
              });
            }
            return;
          }
        } catch (_) {
          final content = _cleanQuote(_extractAnswerFromLooseText(rawText));
          if (content != null && content.isNotEmpty && mounted) {
            setState(() {
              _quote = content;
              _isLoading = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('每日一文获取失败: $e');
    }
    
    // 失败兜底
    if (mounted) {
      setState(() {
        _quote = '生活明朗，万物可爱。'; 
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbeddedContent();
    }
    
    // 独立卡片模式（备用）
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_isLoading)
          Shimmer.fromColors(
            baseColor: color.withOpacity(0.3),
            highlightColor: color.withOpacity(0.1),
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
              final fittedSize = _fitFontSizeForTwoLines(text, targetWidth);
              return Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.clip, // 不显示 ...
                softWrap: true,
                style: TextStyle(
                  fontSize: fittedSize,
                  height: 1.22,
                  color: color.withOpacity(0.95),
                  fontFamily: 'serif',
                  letterSpacing: 0.4,
                ),
              );
            },
          ),
      ],
    );
  }

  String? _cleanQuote(String? input) {
    var s = input?.trim();
    if (s == null || s.isEmpty) return s;

    // 优先从 { ... answer: xxx ... } 中裁出 answer 段（防止你截图那种全字段展示）
    s = _extractAnswerFromLooseText(s) ?? s;

    // 去掉常见字段前缀
    s = s.replaceFirst(RegExp(r'^(answer|回答)\\s*[:：]\\s*', caseSensitive: false), '');

    // 去掉可能的废话开头
    s = s.replaceFirst(
      RegExp(r'^(Skill|Answer|Response|AI|好的|当然|没问题|Here is|Sure)\\s*[，。！:：\\n]*\\s*',
          caseSensitive: false),
      '',
    );

    // 去掉首尾引号/大括号
    s = s.replaceAll(RegExp(r'^[\\s\\{\\[\"“]+'), '');
    s = s.replaceAll(RegExp(r'[\\s\\}\\]\"”]+$'), '');

    // 如果后面还有 time/questions 之类字段，截断
    s = s.split(RegExp(r'\\s*(time|questions?)\\s*[:：]', caseSensitive: false)).first.trim();

    return s.trim();
  }

  String? _extractAnswerFromLooseText(String raw) {
    final m = RegExp(r'answer\\s*[:：]\\s*([^,}\\n]+)', caseSensitive: false).firstMatch(raw);
    if (m != null) return m.group(1)?.trim();
    return null;
  }

  double _fitFontSizeForTwoLines(String text, double maxWidth) {
    // 从 13 递减到 10，找到能在 2 行内放下的字号
    for (double size = 13; size >= 10; size -= 0.5) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, height: 1.22, fontFamily: 'serif', letterSpacing: 0.4),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: maxWidth);
      if (!tp.didExceedMaxLines) return size;
    }
    return 10;
  }
}
