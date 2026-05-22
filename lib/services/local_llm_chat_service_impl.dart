import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';

import 'local_model_store.dart';
import 'moe_llm_memory_tools.dart';

/// 本机 / Web GGUF 聊天（llamadart：Web 走 WebGPU/CPU 桥接，原生走 FFI）。
class LocalLlmChatService {
  LocalLlmChatService._();

  static final LocalLlmChatService instance = LocalLlmChatService._();

  LlamaEngine? _engine;
  ChatSession? _session;
  String? _loadedModelId;

  Future<String> chat({
    required String modelId,
    required List<Map<String, String>> messages,
    required bool enableTools,
    String? userId,
    double? temperature,
  }) async {
    final pathOrSource =
        await LocalModelStore.instance.resolveModelPath(modelId);
    if (pathOrSource == null || pathOrSource.isEmpty) {
      throw Exception(
        '未找到已安装的本地模型「$modelId」。请先在「离线模型下载」中安装（Web 推荐 Qwen2.5-0.5B）。',
      );
    }

    await _ensureModelLoaded(modelId, pathOrSource);

    final session = _session;
    if (session == null) {
      throw Exception('本地模型加载失败');
    }

    final tools = MoeLlmMemoryTools.forProfile(
      enabled: enableTools,
      userId: userId,
    );

    try {
      _primeSession(session, messages, enableTools: enableTools);

      final userText = _lastUserText(messages) ?? '你好';
      final buffer = StringBuffer();
      final params = GenerationParams(
        temp: temperature ?? 0.7,
        maxTokens: 1024,
      );

      await for (final chunk in session.create(
        [LlamaTextContent(userText)],
        params: params,
        tools: tools.isEmpty ? null : tools,
      )) {
        if (chunk.choices.isEmpty) continue;
        final delta = chunk.choices.first.delta;
        final piece = delta.content;
        if (piece != null && piece.isNotEmpty) {
          buffer.write(piece);
        }
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) return text;
      throw Exception('本地模型返回了空回复；若启用了工具，请换用 Qwen2.5-1.5B 后重试');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [LocalGGUF] chat failed: $e');
      }
      rethrow;
    }
  }

  Future<void> _ensureModelLoaded(String modelId, String pathOrSource) async {
    if (_engine != null && _loadedModelId == modelId) {
      return;
    }
    await dispose();

    final engine = LlamaEngine(LlamaBackend());
    if (pathOrSource.startsWith('hf://')) {
      await engine.loadModelSource(
        ModelSource.parse(pathOrSource),
        options: ModelLoadOptions(
          cachePolicy: ModelCachePolicy.preferCached,
        ),
      );
    } else {
      await engine.loadModel(pathOrSource);
    }

    _engine = engine;
    _session = ChatSession(engine);
    _loadedModelId = modelId;
    if (kDebugMode) {
      debugPrint('✅ [LocalGGUF] ready: $pathOrSource');
    }
  }

  void _primeSession(
    ChatSession session,
    List<Map<String, String>> messages, {
    required bool enableTools,
  }) {
    session.reset();

    String? systemPrompt;
    final history = <({String role, String content})>[];
    String? pendingUser;

    for (final raw in messages) {
      final role = (raw['role'] ?? 'user').toLowerCase();
      final content = (raw['content'] ?? '').trim();
      if (content.isEmpty) continue;

      switch (role) {
        case 'system':
          systemPrompt = content;
        case 'user':
          if (pendingUser != null) {
            history.add((role: 'user', content: pendingUser));
          }
          pendingUser = content;
        case 'assistant':
          if (pendingUser != null) {
            history.add((role: 'user', content: pendingUser));
            pendingUser = null;
          }
          history.add((role: 'assistant', content: content));
        default:
          break;
      }
    }

    var sys = systemPrompt ?? '';
    if (enableTools) {
      final appendix = MoeLlmMemoryTools.toolSystemAppendix();
      sys = sys.isEmpty ? appendix : '$sys\n\n$appendix';
    }
    session.systemPrompt = sys.isEmpty ? null : sys;

    for (final item in history) {
      if (item.role == 'user') {
        session.addMessage(
          LlamaChatMessage.fromText(
            role: LlamaChatRole.user,
            text: item.content,
          ),
        );
      } else {
        session.addMessage(
          LlamaChatMessage.fromText(
            role: LlamaChatRole.assistant,
            text: item.content,
          ),
        );
      }
    }
  }

  String? _lastUserText(List<Map<String, String>> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final raw = messages[i];
      if ((raw['role'] ?? '').toLowerCase() != 'user') continue;
      final text = (raw['content'] ?? '').trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _session = null;
    _loadedModelId = null;
  }
}
