import 'dart:convert';

class GameNarrativeLine {
  final String type;
  final String content;
  final String name;

  const GameNarrativeLine({
    required this.type,
    required this.content,
    this.name = '',
  });

  /// 展示用正文：若后端误传 JSON，只取 prose 字段。
  String get displayContent => extractProseFromPayload(content) ?? content;

  factory GameNarrativeLine.fromMap(Map<String, dynamic> map) {
    return GameNarrativeLine(
      type: map['type']?.toString() ?? 'prose',
      content: map['content']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }

  bool get isActionEcho => type == 'action_echo';
  bool get isProse => type == 'prose' || type == 'system' || type == 'npc';
  bool get isHint => type == 'hint';
  bool get isThought => type == 'thought';
  bool get isHighlight => type == 'highlight';
  bool get isEvent => type == 'event';
}

String? extractProseFromPayload(String raw) {
  final text = raw.trim();
  if (!text.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;
    final prose = decoded['prose']?.toString().trim() ?? '';
    if (prose.length < 12) return null;
    const blocked = ['150-280', 'favor_deltas', 'flags_patch', '更新后的时间'];
    for (final marker in blocked) {
      if (prose.contains(marker)) return null;
    }
    return prose;
  } catch (_) {
    return null;
  }
}

class GameNpc {
  final int id;
  final String name;
  final String persona;
  final int favorability;

  const GameNpc({
    required this.id,
    required this.name,
    required this.persona,
    required this.favorability,
  });

  factory GameNpc.fromMap(Map<String, dynamic> map) {
    return GameNpc(
      id: _asInt(map['id']),
      name: map['name']?.toString() ?? '',
      persona: map['persona']?.toString() ?? '',
      favorability: _asInt(map['favorability'], fallback: 50),
    );
  }
}

class GameItem {
  final int id;
  final String name;
  final String description;
  final bool inInventory;

  const GameItem({
    required this.id,
    required this.name,
    required this.description,
    this.inInventory = true,
  });

  factory GameItem.fromMap(Map<String, dynamic> map) {
    return GameItem(
      id: _asInt(map['id']),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      inInventory: map['in_inventory'] == true ||
          map['inInventory'] == true ||
          map['in_inventory']?.toString() == 'true',
    );
  }
}

class GameScene {
  final int id;
  final String name;
  final String description;
  final List<String> exits;

  const GameScene({
    required this.id,
    required this.name,
    required this.description,
    required this.exits,
  });

  factory GameScene.fromMap(Map<String, dynamic> map) {
    final rawExits = map['exits'];
    final exits = rawExits is List
        ? rawExits.map((e) => e.toString()).toList()
        : <String>[];
    return GameScene(
      id: _asInt(map['id']),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      exits: exits,
    );
  }

  GameScene copyWithName(String name) {
    if (name.isEmpty) return this;
    return GameScene(
      id: id,
      name: name,
      description: description,
      exits: exits,
    );
  }
}

class GameSessionState {
  final int sessionId;
  final GameScene scene;
  final List<GameNpc> npcs;
  final String gameTime;
  final int overallFavorability;
  final String playerFocus;
  final List<GameNarrativeLine> opening;
  final List<GameNarrativeLine> history;
  final bool llmOnline;
  final List<GameItem> inventory;
  final List<String> visitedScenes;
  final List<String> storyArcTitles;

  const GameSessionState({
    required this.sessionId,
    required this.scene,
    required this.npcs,
    required this.gameTime,
    required this.overallFavorability,
    this.playerFocus = '',
    this.opening = const [],
    this.history = const [],
    this.llmOnline = false,
    this.inventory = const [],
    this.visitedScenes = const [],
    this.storyArcTitles = const [],
  });

  List<GameNarrativeLine> get initialLines => [
        ...history,
        ...opening,
      ];

  factory GameSessionState.fromMap(Map<String, dynamic> map) {
    return GameSessionState(
      sessionId: _asInt(map['session_id'] ?? map['sessionId']),
      scene: _parseScene(map['scene']),
      npcs: _parseNpcs(map['npcs']),
      gameTime:
          map['game_time']?.toString() ?? map['gameTime']?.toString() ?? '',
      overallFavorability: _asInt(
          map['overall_favorability'] ?? map['overallFavorability'],
          fallback: 50),
      playerFocus: map['player_focus']?.toString() ??
          map['playerFocus']?.toString() ??
          '',
      opening: _parseLines(map['opening']),
      history: _parseLines(map['history']),
      llmOnline: map['llm_online'] == true ||
          map['llmOnline'] == true ||
          map['llm_online']?.toString() == 'true',
      inventory: _parseItems(map['inventory']),
      visitedScenes: _parseStringList(
        map['visited_scenes'] ?? map['visitedScenes'],
        flagsJson:
            map['flags_json']?.toString() ?? map['flagsJson']?.toString(),
      ),
      storyArcTitles: _parseStringList(
        map['story_arc_titles'] ?? map['storyArcTitles'],
      ),
    );
  }

  GameSessionState copyWith({
    GameScene? scene,
    String? gameTime,
    int? overallFavorability,
    String? playerFocus,
    List<GameNpc>? npcs,
    List<GameItem>? inventory,
    List<String>? visitedScenes,
    List<String>? storyArcTitles,
  }) {
    return GameSessionState(
      sessionId: sessionId,
      scene: scene ?? this.scene,
      npcs: npcs ?? this.npcs,
      gameTime: gameTime ?? this.gameTime,
      overallFavorability: overallFavorability ?? this.overallFavorability,
      playerFocus: playerFocus ?? this.playerFocus,
      opening: opening,
      history: history,
      llmOnline: llmOnline,
      inventory: inventory ?? this.inventory,
      visitedScenes: visitedScenes ?? this.visitedScenes,
      storyArcTitles: storyArcTitles ?? this.storyArcTitles,
    );
  }
}

class GameActResult {
  final List<GameNarrativeLine> narrative;
  final String location;
  final String gameTime;
  final int overallFavorability;
  final String playerFocus;
  final String narrativeSource;
  final bool llmOnline;
  final List<String> suggestedActions;
  final List<GameItem> inventory;
  final List<GameNpc> npcs;

  const GameActResult({
    required this.narrative,
    required this.location,
    required this.gameTime,
    required this.overallFavorability,
    this.playerFocus = '',
    this.narrativeSource = '',
    this.llmOnline = false,
    this.suggestedActions = const [],
    this.inventory = const [],
    this.npcs = const [],
  });

  factory GameActResult.fromMap(Map<String, dynamic> map) {
    final rawActions = map['suggested_actions'] ?? map['suggestedActions'];
    final actions = rawActions is List
        ? rawActions
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    return GameActResult(
      narrative: _parseLines(map['narrative']),
      location: map['location']?.toString() ?? '',
      gameTime:
          map['game_time']?.toString() ?? map['gameTime']?.toString() ?? '',
      overallFavorability: _asInt(
          map['overall_favorability'] ?? map['overallFavorability'],
          fallback: 50),
      playerFocus: map['player_focus']?.toString() ??
          map['playerFocus']?.toString() ??
          '',
      narrativeSource: map['narrative_source']?.toString() ??
          map['narrativeSource']?.toString() ??
          '',
      llmOnline: map['llm_online'] == true ||
          map['llmOnline'] == true ||
          map['llm_online']?.toString() == 'true',
      suggestedActions: actions,
      inventory: _parseItems(map['inventory']),
      npcs: _parseNpcs(map['npcs']),
    );
  }
}

List<String> _parseStringList(dynamic raw, {String? flagsJson}) {
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (flagsJson != null && flagsJson.isNotEmpty) {
    return parseVisitedScenesFromFlags(flagsJson);
  }
  return const [];
}

List<String> parseVisitedScenesFromFlags(String flagsJson) {
  try {
    final decoded = jsonDecode(flagsJson);
    if (decoded is! Map) return const [];
    final raw = decoded['visited_scenes'] ?? decoded['visitedScenes'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
  } catch (_) {}
  return const [];
}

List<String> parseStoryArcTitlesFromFlags(String flagsJson) {
  try {
    final decoded = jsonDecode(flagsJson);
    if (decoded is! Map) return const [];
    final raw = decoded['story_arcs'] ?? decoded['storyArcs'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e['title']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  } catch (_) {}
  return const [];
}

List<GameNarrativeLine> _parseLines(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => GameNarrativeLine.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

GameScene _parseScene(dynamic raw) {
  if (raw is Map) {
    return GameScene.fromMap(Map<String, dynamic>.from(raw));
  }
  return const GameScene(id: 0, name: '', description: '', exits: []);
}

List<GameNpc> _parseNpcs(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => GameNpc.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

List<GameItem> _parseItems(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => GameItem.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

int _asInt(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? fallback;
  return fallback;
}
