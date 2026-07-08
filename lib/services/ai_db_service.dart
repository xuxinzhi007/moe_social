import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/ai_agent.dart';
import '../models/ai_chat_session.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_lorebook.dart';
import '../models/ai_lorebook_entry.dart';
import '../models/ai_provider_profile.dart';

class AiDbService {
  static final AiDbService _instance = AiDbService._internal();
  static Database? _database;
  static bool _databaseFactoryInitialized = false;

  factory AiDbService() => _instance;

  AiDbService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    _ensureDatabaseFactoryInitialized();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_agents.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  void _ensureDatabaseFactoryInitialized() {
    if (_databaseFactoryInitialized) return;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      _databaseFactoryInitialized = true;
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        break;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        break;
    }
    _databaseFactoryInitialized = true;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE agents(
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        system_prompt TEXT,
        model_name TEXT,
        avatar_path TEXT,
        provider_profile_id TEXT,
        lorebook_id TEXT,
        persona TEXT DEFAULT '',
        scenario TEXT DEFAULT '',
        opening_message TEXT DEFAULT '',
        example_dialogues TEXT DEFAULT '',
        created_at INTEGER,
        created_by_user_id TEXT,
        updated_at INTEGER,
        is_public INTEGER DEFAULT 0,
        author_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE provider_profiles(
        id TEXT PRIMARY KEY,
        name TEXT,
        provider_type TEXT,
        base_url TEXT,
        default_model TEXT,
        manual_models_json TEXT,
        use_server_memory INTEGER DEFAULT 0,
        supports_system_messages INTEGER DEFAULT 1,
        supports_streaming INTEGER DEFAULT 1,
        supports_vision INTEGER DEFAULT 0,
        supports_tool_calls INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE lorebooks(
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT DEFAULT '',
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE lorebook_entries(
        id TEXT PRIMARY KEY,
        lorebook_id TEXT NOT NULL,
        title TEXT,
        content TEXT,
        keywords_json TEXT DEFAULT '[]',
        enabled INTEGER DEFAULT 1,
        always_enabled INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 50,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_lorebook_entries_lorebook ON lorebook_entries(lorebook_id, priority DESC, updated_at DESC)');

    await db.execute('''
      CREATE TABLE sessions(
        id TEXT PRIMARY KEY,
        agent_id TEXT,
        title TEXT,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        session_id TEXT,
        role TEXT,
        content TEXT,
        created_at INTEGER
      )
    ''');

    final now = DateTime.now();
    await db.insert(
        'agents',
        AiAgent(
          id: 'default_agent',
          name: 'Moe 助手',
          description: '您的全能 AI 助手',
          systemPrompt: '你是一位友好的 AI 助手，能够回答各种问题。',
          modelName: 'qwen2.5:0.5b-instruct',
          createdAt: now,
        ).toMap());
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS provider_profiles(
          id TEXT PRIMARY KEY,
          name TEXT,
          provider_type TEXT,
          base_url TEXT,
          default_model TEXT,
          manual_models_json TEXT,
          use_server_memory INTEGER DEFAULT 0,
          supports_system_messages INTEGER DEFAULT 1,
          supports_streaming INTEGER DEFAULT 1,
          supports_vision INTEGER DEFAULT 0,
          supports_tool_calls INTEGER DEFAULT 0,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'provider_profile_id',
        definition: 'TEXT',
      );
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'persona',
        definition: "TEXT DEFAULT ''",
      );
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'scenario',
        definition: "TEXT DEFAULT ''",
      );
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'opening_message',
        definition: "TEXT DEFAULT ''",
      );
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'example_dialogues',
        definition: "TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lorebooks(
          id TEXT PRIMARY KEY,
          name TEXT,
          description TEXT DEFAULT '',
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lorebook_entries(
          id TEXT PRIMARY KEY,
          lorebook_id TEXT NOT NULL,
          title TEXT,
          content TEXT,
          keywords_json TEXT DEFAULT '[]',
          enabled INTEGER DEFAULT 1,
          always_enabled INTEGER DEFAULT 0,
          priority INTEGER DEFAULT 50,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_lorebook_entries_lorebook ON lorebook_entries(lorebook_id, priority DESC, updated_at DESC)');
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'lorebook_id',
        definition: 'TEXT',
      );
    }
    if (oldVersion < 7) {
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'created_by_user_id',
        definition: 'TEXT',
      );
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'updated_at',
        definition: 'INTEGER',
      );
    }
    if (oldVersion < 8) {
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'is_public',
        definition: 'INTEGER DEFAULT 0',
      );
      await _ensureColumn(
        db,
        table: 'agents',
        column: 'author_name',
        definition: 'TEXT',
      );
    }
    if (oldVersion < 6) {
      await _ensureColumn(
        db,
        table: 'provider_profiles',
        column: 'supports_system_messages',
        definition: 'INTEGER DEFAULT 1',
      );
      await _ensureColumn(
        db,
        table: 'provider_profiles',
        column: 'supports_streaming',
        definition: 'INTEGER DEFAULT 1',
      );
      await _ensureColumn(
        db,
        table: 'provider_profiles',
        column: 'supports_vision',
        definition: 'INTEGER DEFAULT 0',
      );
      await _ensureColumn(
        db,
        table: 'provider_profiles',
        column: 'supports_tool_calls',
        definition: 'INTEGER DEFAULT 0',
      );
    }
  }

  Future<void> _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ─── Agent Operations ────────────────────────────────────────────────────

  Future<List<AiAgent>> getAgents() async {
    final db = await database;
    final maps = await db.query('agents', orderBy: 'created_at ASC');
    return maps.map(AiAgent.fromMap).toList();
  }

  Future<AiAgent?> getAgent(String id) async {
    final db = await database;
    final maps = await db.query('agents', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? AiAgent.fromMap(maps.first) : null;
  }

  Future<void> insertAgent(AiAgent agent) async {
    final db = await database;
    await db.insert('agents', agent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAgent(AiAgent agent) async {
    final db = await database;
    await db.update('agents', agent.toMap(),
        where: 'id = ?', whereArgs: [agent.id]);
  }

  Future<void> deleteAgent(String id) async {
    final db = await database;
    await db.delete('agents', where: 'id = ?', whereArgs: [id]);
    final sessions = await getSessions(id);
    for (final session in sessions) {
      await deleteSession(session.id);
    }
  }

  // ─── Provider Operations ────────────────────────────────────────────────

  Future<List<AiProviderProfile>> getProviderProfiles() async {
    final db = await database;
    final maps = await db.query(
      'provider_profiles',
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return maps.map(AiProviderProfile.fromMap).toList();
  }

  Future<void> insertProviderProfile(AiProviderProfile profile) async {
    final db = await database;
    await db.insert(
      'provider_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProviderProfile(AiProviderProfile profile) async {
    final db = await database;
    await db.update(
      'provider_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<void> deleteProviderProfile(String id) async {
    final db = await database;
    await db.delete('provider_profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Lorebook Operations ────────────────────────────────────────────────

  Future<List<AiLorebook>> getLorebooks() async {
    final db = await database;
    final maps = await db.query(
      'lorebooks',
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return maps.map(AiLorebook.fromMap).toList();
  }

  Future<AiLorebook?> getLorebook(String id) async {
    final db = await database;
    final maps = await db.query(
      'lorebooks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AiLorebook.fromMap(maps.first);
  }

  Future<void> insertLorebook(AiLorebook lorebook) async {
    final db = await database;
    await db.insert(
      'lorebooks',
      lorebook.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLorebook(AiLorebook lorebook) async {
    final db = await database;
    await db.update(
      'lorebooks',
      lorebook.toMap(),
      where: 'id = ?',
      whereArgs: [lorebook.id],
    );
  }

  Future<void> deleteLorebook(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'lorebook_entries',
        where: 'lorebook_id = ?',
        whereArgs: [id],
      );
      await txn.rawUpdate(
        'UPDATE agents SET lorebook_id = NULL WHERE lorebook_id = ?',
        [id],
      );
      await txn.delete('lorebooks', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<AiLorebookEntry>> getLorebookEntries(String lorebookId) async {
    final db = await database;
    final maps = await db.query(
      'lorebook_entries',
      where: 'lorebook_id = ?',
      whereArgs: [lorebookId],
      orderBy: 'priority DESC, updated_at DESC',
    );
    return maps.map(AiLorebookEntry.fromMap).toList();
  }

  Future<void> insertLorebookEntry(AiLorebookEntry entry) async {
    final db = await database;
    await db.insert(
      'lorebook_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLorebookEntry(AiLorebookEntry entry) async {
    final db = await database;
    await db.update(
      'lorebook_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> replaceLorebookEntries(
    String lorebookId,
    List<AiLorebookEntry> entries,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'lorebook_entries',
        where: 'lorebook_id = ?',
        whereArgs: [lorebookId],
      );
      for (final entry in entries) {
        await txn.insert(
          'lorebook_entries',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteLorebookEntry(String id) async {
    final db = await database;
    await db.delete('lorebook_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Session Operations ──────────────────────────────────────────────────

  Future<List<AiChatSession>> getSessions(String agentId) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'agent_id = ?',
      whereArgs: [agentId],
      orderBy: 'updated_at DESC',
    );
    return maps.map(AiChatSession.fromMap).toList();
  }

  Future<void> insertSession(AiChatSession session) async {
    final db = await database;
    await db.insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(AiChatSession session) async {
    final db = await database;
    await db.update('sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
  }

  // ─── Message Operations ──────────────────────────────────────────────────

  Future<List<AiChatMessage>> getMessages(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return maps.map(AiChatMessage.fromMap).toList();
  }

  Future<void> insertMessage(AiChatMessage message) async {
    final db = await database;
    await db.insert('messages', message.toMap());
    await db.rawUpdate(
      'UPDATE sessions SET updated_at = ? WHERE id = ?',
      [message.createdAt.millisecondsSinceEpoch, message.sessionId],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> clearMessages(String sessionId) async {
    final db = await database;
    await db
        .delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
