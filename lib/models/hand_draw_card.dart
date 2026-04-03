import 'dart:convert';
import 'dart:ui' show Offset, Size;

/// 手绘卡片笔迹（坐标为 0~1 归一化，便于不同屏幕回放一致）
class HandDrawStroke {
  HandDrawStroke({
    required this.colorArgb,
    required this.widthNorm,
    required this.points,
    this.erase = false,
  });

  /// 颜色 0xAARRGGBB
  final int colorArgb;

  /// 相对画布短边的线宽比例，如 0.008 ≈ 较细
  final double widthNorm;

  /// [[x,y], ...] 归一化坐标
  final List<List<double>> points;

  /// 橡皮笔迹（与背景合成时需 saveLayer + BlendMode.clear）
  final bool erase;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'c': colorArgb,
      'w': widthNorm,
      'p': points,
    };
    if (erase) m['e'] = 1;
    return m;
  }

  factory HandDrawStroke.fromJson(Map<String, dynamic> json) {
    final plist = <List<double>>[];
    final raw = json['p'];
    if (raw is List) {
      for (final e in raw) {
        if (e is List && e.length >= 2) {
          plist.add([
            (e[0] as num).toDouble(),
            (e[1] as num).toDouble(),
          ]);
        }
      }
    }
    final e = json['e'];
    final isErase = e == true || e == 1;
    return HandDrawStroke(
      colorArgb: (json['c'] as num?)?.toInt() ?? 0xFF7F7FD5,
      widthNorm: (json['w'] as num?)?.toDouble() ?? 0.01,
      points: plist,
      erase: isErase,
    );
  }
}

class HandDrawCardData {
  HandDrawCardData({
    required this.strokes,
    this.backgroundArgb = 0xFFF5F7FA,
  });

  static const int currentVersion = 1;

  final int backgroundArgb;
  final List<HandDrawStroke> strokes;

  Map<String, dynamic> toJson() => {
        'v': currentVersion,
        'bg': backgroundArgb,
        's': strokes.map((e) => e.toJson()).toList(),
      };

  factory HandDrawCardData.fromJson(Map<String, dynamic> json) {
    final sl = <HandDrawStroke>[];
    final raw = json['s'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          sl.add(HandDrawStroke.fromJson(e));
        }
      }
    }
    return HandDrawCardData(
      backgroundArgb: (json['bg'] as num?)?.toInt() ?? 0xFFF5F7FA,
      strokes: sl,
    );
  }

  static HandDrawCardData? tryParseJsonString(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final v = (m['v'] as num?)?.toInt() ?? 1;
      if (v != currentVersion) return null;
      return HandDrawCardData.fromJson(m);
    } catch (_) {
      return null;
    }
  }
}

/// 嵌入帖子正文传输（无需后端新字段）
class HandDrawCardCodec {
  HandDrawCardCodec._();

  static const _start = '<<<MOE_HAND_DRAW_V1>>>';
  static const _end = '<<<END_MOE_HAND_DRAW>>>';

  /// 展示用正文（去掉手绘 payload）
  static String stripForDisplay(String raw) {
    final i = raw.indexOf(_start);
    if (i < 0) return raw;
    return raw.substring(0, i).trimRight();
  }

  static HandDrawCardData? tryDecode(String raw) {
    final i = raw.indexOf(_start);
    if (i < 0) return null;
    final j = raw.indexOf(_end, i);
    if (j < 0) return null;
    final jsonStr = raw.substring(i + _start.length, j).trim();
    return HandDrawCardData.tryParseJsonString(jsonStr);
  }

  static String mergeCaptionAndPayload(String caption, HandDrawCardData data) {
    final trimmed = caption.trim();
    final payload = jsonEncode(data.toJson());
    if (trimmed.isEmpty) {
      return '$_start$payload$_end';
    }
    return '$trimmed\n$_start$payload$_end';
  }

  /// 归一化坐标 → 像素
  static Offset toPixel(List<double> p, Size canvas) {
    return Offset(p[0] * canvas.width, p[1] * canvas.height);
  }
}
