import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pet_state.dart';
import 'pet_art.dart';

/// 单片在深度表中的角色（后 → 前绘制）。
enum PetStackKind {
  shoes,
  bottom,
  legs,
  torso,
  topBack,
  arms,
  topFront,
  head,
  ear,
  hat,
}

/// 已解析的一层；[wearSlot] 非空时用 [PetWearLayout] 偏移绘制。
class PetStackLayer {
  const PetStackLayer({
    required this.kind,
    required this.image,
    this.wearSlot,
  });

  final PetStackKind kind;
  final ui.Image image;
  final String? wearSlot;
}

/// 资源到位情况（换衣间提示用）。
class PetAvatarLayerStatus {
  const PetAvatarLayerStatus({
    required this.id,
    required this.label,
    required this.path,
    required this.ready,
  });

  final String id;
  final String label;
  final String path;
  final bool ready;
}

/// 从 [avatar_stack.json] 读取的深度配置 + 模型锚点。
class PetAvatarStackConfig {
  const PetAvatarStackConfig({
    required this.order,
    required this.bodyPaths,
    required this.wearAnchors,
  });

  final List<String> order;
  final Map<String, String> bodyPaths;
  final PetWearLayout wearAnchors;

  static final defaults = PetAvatarStackConfig(
    order: const [
      'shoes',
      'bottom',
      'legs',
      'torso',
      'top_back',
      'arms',
      'top_front',
      'head',
      'hat',
    ],
    bodyPaths: const {
      'legs': PetArt.legs,
      'torso': PetArt.torso,
      'arms': PetArt.arms,
      'head': PetArt.head,
      'ear': PetArt.ear,
      'fallbackWhole': PetArt.model,
    },
    wearAnchors: PetWearLayout.defaults,
  );

  static PetAvatarStackConfig? _cache;

  /// 测试/热更配置时清缓存。
  static void clearCache() => _cache = null;

  static Future<PetAvatarStackConfig> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(PetArt.avatarStackConfig);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final body = Map<String, dynamic>.from(map['body'] as Map? ?? {});
      final order = (map['order'] as List?)?.map((e) => '$e').toList() ??
          defaults.order;
      final paths = <String, String>{
        for (final e in defaults.bodyPaths.entries) e.key: e.value,
        for (final e in body.entries) e.key: '${e.value}',
      };
      final anchorsRaw = map['wearAnchors'];
      final anchors = anchorsRaw is Map
          ? PetWearLayout.fromJson(Map<String, dynamic>.from(anchorsRaw))
          : PetWearLayout.defaults;
      return _cache = PetAvatarStackConfig(
        order: order,
        bodyPaths: paths,
        wearAnchors: anchors,
      );
    } catch (_) {
      return _cache = defaults;
    }
  }

  PetWearLayer anchorOf(String slot) => wearAnchors.slot(slot);

  /// 身体层 checklist（配置路径是否存在）。
  static Future<List<PetAvatarLayerStatus>> diagnose() async {
    final cfg = await load();
    const labels = {
      'legs': '腿',
      'torso': '躯干(无脸)',
      'arms': '手臂',
      'head': '头(夹衣关键)',
      'ear': '耳',
      'fallbackWhole': '合体全身',
    };
    final ids = ['torso', 'head', 'legs', 'arms', 'ear', 'fallbackWhole'];
    final out = <PetAvatarLayerStatus>[];
    for (final id in ids) {
      final path = cfg.bodyPaths[id] ?? '';
      out.add(
        PetAvatarLayerStatus(
          id: id,
          label: labels[id] ?? id,
          path: path,
          ready: path.isNotEmpty && await PetArt.exists(path),
        ),
      );
    }
    return out;
  }
}

/// QQ 秀轻量栈：身体拆层 + 服装插槽。SSOT：`docs/dev/pet-layered-avatar.md`。
class PetAvatarStack {
  PetAvatarStack._(
    this.layers, {
    required this.layeredBody,
    required this.orderIds,
  });

  final List<PetStackLayer> layers;
  final bool layeredBody;
  final List<String> orderIds;

  /// 异步组装贴图顺序；位移在 [paint] 时读 [layout]。
  static Future<PetAvatarStack> compose({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
  }) async {
    final cfg = await PetAvatarStackConfig.load();
    String bodyPath(String key) =>
        cfg.bodyPaths[key] ?? defaultsBody(key);

    final head = await PetArt.loadImage(
      bodyPath('head'),
      knockoutDarkBg: true,
    );
    final torso = await PetArt.loadImage(bodyPath('torso'));
    // 有无脸躯干 + 头 → 分层；仅有头也可分层（躯干回落 model）
    final layered = head != null || torso != null;

    final legs =
        layered ? await PetArt.loadImage(bodyPath('legs')) : null;
    final arms =
        layered ? await PetArt.loadImage(bodyPath('arms')) : null;
    final ear = await PetArt.loadImage(bodyPath('ear'));

    ui.Image? whole;
    if (!layered) {
      whole = await PetArt.loadImage(bodyPath('fallbackWhole')) ??
          await PetArt.loadImage(PetArt.body);
    } else if (torso == null) {
      whole = await PetArt.loadImage(
            bodyPath('fallbackWhole'),
            knockoutDarkBg: true,
          ) ??
          await PetArt.loadImage(PetArt.body);
    }

    // 空 ID =「无」，不画该服装槽（模型裸穿）。
    final shoes =
        shoesId.isEmpty ? null : await _loadClothes('shoes', shoesId);
    final bottom =
        bottomId.isEmpty ? null : await _loadClothes('bottom', bottomId);
    final topBack = topId.isEmpty
        ? null
        : await _loadClothesPiece(topId, suffix: '_back');
    final topFront = topId.isEmpty
        ? null
        : (await _loadClothesPiece(topId, suffix: '_front') ??
            await _loadClothes('top', topId));
    final hat = hatId.isEmpty ? null : await _loadClothes('hat', hatId);

    final byId = <String, PetStackLayer?>{};
    void putWear(String id, PetStackKind k, ui.Image? img, String slot) {
      if (img == null) return;
      byId[id] = PetStackLayer(kind: k, image: img, wearSlot: slot);
    }

    void putBody(String id, PetStackKind k, ui.Image? img) {
      if (img == null) return;
      byId[id] = PetStackLayer(kind: k, image: img);
    }

    putWear('shoes', PetStackKind.shoes, shoes, 'shoes');
    putWear('bottom', PetStackKind.bottom, bottom, 'bottom');

    if (layered) {
      putBody('legs', PetStackKind.legs, legs);
      putBody('torso', PetStackKind.torso, torso ?? whole);
      putWear('top_back', PetStackKind.topBack, topBack, 'top');
      putBody('arms', PetStackKind.arms, arms);
      putWear('top_front', PetStackKind.topFront, topFront, 'top');
      putBody('head', PetStackKind.head, head);
      putBody('ear', PetStackKind.ear, ear);
    } else {
      putBody('torso', PetStackKind.torso, whole);
      putWear('top_front', PetStackKind.topFront, topFront, 'top');
    }
    putWear('hat', PetStackKind.hat, hat, 'hat');

    final out = <PetStackLayer>[];
    for (final id in cfg.order) {
      final layer = byId[id];
      if (layer != null) out.add(layer);
    }
    return PetAvatarStack._(
      out,
      layeredBody: layered,
      orderIds: [
        for (final id in cfg.order)
          if (byId[id] != null) id,
      ],
    );
  }

  static String defaultsBody(String key) => switch (key) {
        'legs' => PetArt.legs,
        'torso' => PetArt.torso,
        'arms' => PetArt.arms,
        'head' => PetArt.head,
        'ear' => PetArt.ear,
        _ => PetArt.model,
      };

  static Future<ui.Image?> _loadClothes(String slot, String id) async {
    final path = await PetArt.resolveClothesPath(slot, id);
    if (path == null) return null;
    return PetArt.loadImage(path);
  }

  static Future<ui.Image?> _loadClothesPiece(
    String id, {
    required String suffix,
  }) async {
    if (id.isEmpty) return null;
    final path = PetArt.clothes('$id$suffix');
    if (!await PetArt.exists(path)) return null;
    return PetArt.loadImage(path);
  }

  void paint(Canvas canvas, Size size, PetWearLayout layout) {
    for (final layer in layers) {
      _paintOne(canvas, size, layer, layout);
    }
  }

  static void _paintOne(
    Canvas canvas,
    Size size,
    PetStackLayer layer,
    PetWearLayout layout,
  ) {
    final img = layer.image;
    final slot = layer.wearSlot;
    if (slot == null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: img,
        fit: BoxFit.contain,
      );
      return;
    }
    final wear = layout.slot(slot);
    final w = size.width * wear.scale.clamp(0.15, 1.2);
    final h = size.height * wear.scale.clamp(0.15, 1.2);
    final cx = size.width / 2 + wear.ox * size.width;
    final cy = size.height / 2 + wear.oy * size.height;
    canvas.save();
    canvas.translate(cx, cy);
    if (wear.rot != 0) {
      canvas.rotate(wear.rot * math.pi / 180);
    }
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(center: Offset.zero, width: w, height: h),
      image: img,
      fit: BoxFit.contain,
    );
    canvas.restore();
  }
}

/// Flutter 预览：与小家同一深度表。
class PetAvatarStackView extends StatelessWidget {
  const PetAvatarStackView({
    super.key,
    required this.stack,
    required this.layout,
    this.child,
  });

  final PetAvatarStack stack;
  final PetWearLayout layout;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StackPainter(stack, layout),
      child: child,
    );
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter(this.stack, this.layout);

  final PetAvatarStack stack;
  final PetWearLayout layout;

  @override
  void paint(Canvas canvas, Size size) => stack.paint(canvas, size, layout);

  @override
  bool shouldRepaint(covariant _StackPainter oldDelegate) =>
      oldDelegate.stack != stack || oldDelegate.layout != layout;
}
