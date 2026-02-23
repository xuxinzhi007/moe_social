import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/ai_agent.dart';
import '../models/ai_chat_session.dart';
import '../models/ai_chat_message.dart';

class AiDbService {
  static final AiDbService _instance = AiDbService._internal();
  static Database? _database;

  factory AiDbService() => _instance;

  AiDbService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Web support requires sqflite_common_ffi_web
      throw UnsupportedError('Web platform is not supported for local database yet.');
    }
    if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_agents.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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
        created_at INTEGER
      )
    ''');

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

    // Create default agent
    final now = DateTime.now();
    await db.insert('agents', AiAgent(
      id: 'default_agent',
      name: 'Moe 助手',
      description: '您的全能 AI 助手',
      systemPrompt: '你是一位友好的 AI 助手，能够回答各种问题。',
      modelName: 'qwen2.5:0.5b-instruct',
      createdAt: now,
    ).toMap());
  }

  // Agent Operations
  Future<List<AiAgent>> getAgents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('agents', orderBy: 'created_at ASC');
    return List.generate(maps.length, (i) => AiAgent.fromMap(maps[i]));
  }

  Future<AiAgent?> getAgent(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'agents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return AiAgent.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertAgent(AiAgent agent) async {
    final db = await database;
    await db.insert('agents', agent.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAgent(AiAgent agent) async {
    final db = await database;
    await db.update('agents', agent.toMap(), where: 'id = ?', whereArgs: [agent.id]);
  }

  Future<void> deleteAgent(String id) async {
    final db = await database;
    await db.delete('agents', where: 'id = ?', whereArgs: [id]);
    // Also delete sessions and messages
    final sessions = await getSessions(id);
    for (var session in sessions) {
      await deleteSession(session.id);
    }
  }

  // Session Operations
  Future<List<AiChatSession>> getSessions(String agentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'agent_id = ?',
      whereArgs: [agentId],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => AiChatSession.fromMap(maps[i]));
  }

  Future<void> insertSession(AiChatSession session) async {
    final db = await database;
    await db.insert('sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(AiChatSession session) async {
    final db = await database;
    await db.update('sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
  }

  // Message Operations
  Future<List<AiChatMessage>> getMessages(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => AiChatMessage.fromMap(maps[i]));
  }

  Future<void> insertMessage(AiChatMessage message) async {
    final db = await database;
    await db.insert('messages', message.toMap());
    
    // Update session updated_at
    await db.rawUpdate(
      'UPDATE sessions SET updated_at = ? WHERE id = ?',
      [message.createdAt.millisecondsSinceEpoch, message.sessionId],
    );
  }

  Future<void> clearMessages(String sessionId) async {
    final db = await database;
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
