// Generate tiered gift_burst_*.json Lottie templates (center-safe, tintable).
// Run: dart run scripts/gen_gift_lottie.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main() {
  final out = Directory('assets/lottie/gifts')..createSync(recursive: true);
  final gold = [0.95, 0.85, 0.45];
  final white = [1.0, 1.0, 1.0];
  final soft = [0.9, 0.92, 1.0];
  final amber = [1.0, 0.75, 0.35];
  make(out, 'gift_burst_basic', 90, 10, 1, 55, [white, soft, gold]);
  make(out, 'gift_burst_medium', 120, 16, 2, 70, [white, gold, soft, amber]);
  make(out, 'gift_burst_advanced', 150, 24, 2, 85, [gold, white, amber, soft]);
  make(out, 'gift_burst_luxury', 210, 32, 3, 110, [
    gold,
    amber,
    white,
    soft,
    [1.0, 0.9, 0.5],
  ]);
  stdout.writeln('done ${out.path}');
}

List<Map<String, Object?>> kfO(List<(double, double)> timesVals) {
  final out = <Map<String, Object?>>[];
  for (var i = 0; i < timesVals.length - 1; i++) {
    final (t0, v0) = timesVals[i];
    final (_, v1) = timesVals[i + 1];
    out.add({
      't': t0,
      's': [v0],
      'e': [v1],
      'i': {
        'x': [0.667],
        'y': [1],
      },
      'o': {
        'x': [0.333],
        'y': [0],
      },
    });
  }
  out.add({'t': timesVals.last.$1});
  return out;
}

List<Map<String, Object?>> kfS(List<(double, double)> timesVals) {
  final out = <Map<String, Object?>>[];
  for (var i = 0; i < timesVals.length - 1; i++) {
    final (t0, v0) = timesVals[i];
    final (_, v1) = timesVals[i + 1];
    out.add({
      't': t0,
      's': [v0, v0],
      'e': [v1, v1],
      'i': {
        'x': [0.667, 0.667],
        'y': [1, 1],
      },
      'o': {
        'x': [0.333, 0.333],
        'y': [0, 0],
      },
    });
  }
  out.add({'t': timesVals.last.$1});
  return out;
}

Map<String, Object?> ellipseLayer({
  required String name,
  required int ix,
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  required List<double> color,
  required List<Map<String, Object?>> opacityK,
  required List<Map<String, Object?>> scaleK,
  required int frames,
  Map<String, Object?>? posK,
}) {
  return {
    'ddd': 0,
    'ind': ix,
    'ty': 4,
    'nm': name,
    'sr': 1,
    'ks': {
      'o': {'a': 1, 'k': opacityK},
      'r': {'a': 0, 'k': 0},
      'p': posK ??
          {
            'a': 0,
            'k': [cx, cy],
          },
      'a': {
        'a': 0,
        'k': [0, 0],
      },
      's': {'a': 1, 'k': scaleK},
    },
    'ao': 0,
    'shapes': [
      {
        'ty': 'el',
        'p': {
          'a': 0,
          'k': [0, 0],
        },
        's': {
          'a': 0,
          'k': [rx * 2, ry * 2],
        },
        'nm': 'Ellipse',
        'd': 1,
      },
      {
        'ty': 'fl',
        'c': {
          'a': 0,
          'k': [...color, 1],
        },
        'o': {'a': 0, 'k': 100},
        'r': 1,
        'nm': 'Fill',
      },
      {
        'ty': 'tr',
        'p': {
          'a': 0,
          'k': [0, 0],
        },
        'a': {
          'a': 0,
          'k': [0, 0],
        },
        's': {
          'a': 0,
          'k': [100, 100],
        },
        'r': {'a': 0, 'k': 0},
        'o': {'a': 0, 'k': 100},
        'sk': {'a': 0, 'k': 0},
        'sa': {'a': 0, 'k': 0},
        'nm': 'Transform',
      },
    ],
    'ip': 0,
    'op': frames,
    'st': 0,
    'bm': 0,
  };
}

void make(
  Directory out,
  String name,
  int frames,
  int particleCount,
  int ringCount,
  double glowSize,
  List<List<double>> colors,
) {
  final layers = <Map<String, Object?>>[];
  var ix = 1;
  layers.add(
    ellipseLayer(
      name: 'glow',
      ix: ix++,
      cx: 200,
      cy: 200,
      rx: glowSize,
      ry: glowSize,
      color: colors[0],
      opacityK: kfO([
        (0, 0),
        (frames * 0.12, 70),
        (frames * 0.55, 45),
        (frames * 0.9, 0),
        (frames.toDouble(), 0),
      ]),
      scaleK: kfS([
        (0, 20),
        (frames * 0.15, 100),
        (frames * 0.7, 110),
        (frames.toDouble(), 40),
      ]),
      frames: frames,
    ),
  );

  for (var r = 0; r < ringCount; r++) {
    final size = 40.0 + r * 28;
    final delay = frames * 0.08 * r;
    layers.add(
      ellipseLayer(
        name: 'ring$r',
        ix: ix++,
        cx: 200,
        cy: 200,
        rx: size,
        ry: size,
        color: colors[math.min(r, colors.length - 1)],
        opacityK: kfO([
          (delay, 0),
          (delay + 8, 55),
          (delay + frames * 0.45, 20),
          (delay + frames * 0.7, 0),
          (frames.toDouble(), 0),
        ]),
        scaleK: kfS([
          (delay, 30),
          (delay + frames * 0.35, 160 + r * 20),
          (delay + frames * 0.7, 200 + r * 30),
          (frames.toDouble(), 220),
        ]),
        frames: frames,
      ),
    );
  }

  for (var i = 0; i < particleCount; i++) {
    final ang = (2 * math.pi * i) / particleCount + (i % 3) * 0.2;
    const dist0 = 30.0;
    final dist1 = 90 + (i % 5) * 18;
    final x0 = 200 + math.cos(ang) * dist0;
    final y0 = 200 + math.sin(ang) * dist0;
    final x1 = 200 + math.cos(ang) * dist1;
    final y1 = 200 + math.sin(ang) * dist1;
    final delay = frames * 0.12 + (i % 4) * 2;
    final posK = {
      'a': 1,
      'k': [
        {
          't': delay,
          's': [x0, y0, 0],
          'e': [x1, y1, 0],
          'i': {'x': 0.667, 'y': 1},
          'o': {'x': 0.333, 'y': 0},
        },
        {'t': delay + frames * 0.55},
      ],
    };
    final sz = 4.0 + (i % 4) * 2;
    final c = colors[i % colors.length];
    layers.add({
      'ddd': 0,
      'ind': ix++,
      'ty': 4,
      'nm': 'p$i',
      'sr': 1,
      'ks': {
        'o': {
          'a': 1,
          'k': kfO([
            (delay, 0),
            (delay + 4, 100),
            (delay + frames * 0.5, 60),
            (delay + frames * 0.75, 0),
            (frames.toDouble(), 0),
          ]),
        },
        'r': {'a': 0, 'k': 0},
        'p': posK,
        'a': {
          'a': 0,
          'k': [0, 0],
        },
        's': {
          'a': 1,
          'k': kfS([
            (delay, 40),
            (delay + 8, 120),
            (delay + frames * 0.6, 60),
            (frames.toDouble(), 20),
          ]),
        },
      },
      'ao': 0,
      'shapes': [
        {
          'ty': 'el',
          'p': {
            'a': 0,
            'k': [0, 0],
          },
          's': {
            'a': 0,
            'k': [sz * 2, sz * 2],
          },
          'nm': 'E',
          'd': 1,
        },
        {
          'ty': 'fl',
          'c': {
            'a': 0,
            'k': [...c, 1],
          },
          'o': {'a': 0, 'k': 100},
          'r': 1,
          'nm': 'F',
        },
        {
          'ty': 'tr',
          'p': {
            'a': 0,
            'k': [0, 0],
          },
          'a': {
            'a': 0,
            'k': [0, 0],
          },
          's': {
            'a': 0,
            'k': [100, 100],
          },
          'r': {'a': 0, 'k': 0},
          'o': {'a': 0, 'k': 100},
          'sk': {'a': 0, 'k': 0},
          'sa': {'a': 0, 'k': 0},
          'nm': 'T',
        },
      ],
      'ip': 0,
      'op': frames,
      'st': 0,
      'bm': 0,
    });
  }

  final doc = {
    'v': '5.7.4',
    'fr': 60,
    'ip': 0,
    'op': frames,
    'w': 400,
    'h': 400,
    'nm': name,
    'ddd': 0,
    'assets': <Object?>[],
    'layers': layers.reversed.toList(),
  };
  final path = File('${out.path}/$name.json');
  path.writeAsStringSync(jsonEncode(doc));
  stdout.writeln('${path.path} ${path.lengthSync()} bytes layers=${layers.length}');
}
