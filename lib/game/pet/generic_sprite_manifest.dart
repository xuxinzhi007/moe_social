import 'dart:convert';

/// A serializable grid description for a generic sprite sheet.
class GenericSpriteAnimation {
  const GenericSpriteAnimation({
    required this.cols,
    required this.rows,
  });

  factory GenericSpriteAnimation.fromJson(Map<String, dynamic> json) {
    return GenericSpriteAnimation(
      cols: (json['cols'] as num).toInt(),
      rows: (json['rows'] as num).toInt(),
    );
  }

  final int cols;
  final int rows;

  Map<String, dynamic> toJson() => {
        'cols': cols,
        'rows': rows,
      };
}

/// Manifest contract for one standalone, grid-based sprite sheet.
class GenericSpriteManifest {
  const GenericSpriteManifest({
    required this.specVersion,
    required this.sheet,
    required this.cellSize,
    required this.directionRows,
    required this.animations,
  });

  factory GenericSpriteManifest.fromJson(Map<String, dynamic> json) {
    final animationJson = json['animations'] as Map<String, dynamic>;
    return GenericSpriteManifest(
      specVersion: json['specVersion'] as String,
      sheet: json['sheet'] as String,
      cellSize: (json['cellSize'] as num).toDouble(),
      directionRows: List<String>.from(json['directionRows'] as List),
      animations: {
        for (final entry in animationJson.entries)
          entry.key: GenericSpriteAnimation.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
    );
  }

  factory GenericSpriteManifest.fromJsonString(String source) {
    return GenericSpriteManifest.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  final String specVersion;
  final String sheet;
  final double cellSize;
  final List<String> directionRows;
  final Map<String, GenericSpriteAnimation> animations;

  GenericSpriteAnimation animation(String name) {
    final value = animations[name];
    if (value == null) {
      throw ArgumentError.value(name, 'name', 'Unknown sprite animation');
    }
    return value;
  }

  Map<String, dynamic> toJson() => {
        'specVersion': specVersion,
        'sheet': sheet,
        'cellSize': cellSize,
        'directionRows': directionRows,
        'animations': {
          for (final entry in animations.entries)
            entry.key: entry.value.toJson(),
        },
      };

  String toJsonString() => jsonEncode(toJson());
}
