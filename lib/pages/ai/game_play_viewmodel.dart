import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/game_state.dart';
import '../../services/game_service.dart';

/// 游戏主页面 ViewModel，管理所有游戏状态与 SSE 流式逻辑。
/// 由 [GamePlayPage] 通过 ChangeNotifierProvider 局部注册。
class GamePlayViewModel extends ChangeNotifier {
  // ===== 状态字段 =====
  bool _disposed = false;
  final List<GameNarrativeLine> _lines = [];
  late GameSessionState _state;
  bool _isSending = false;
  List<String> _suggestedActions = const [];
  List<String> _visitedScenes = const [];
  int? _streamingLineIndex;
  String _streamingText = '';
  bool _llmOnline = false;

  // ===== SSE 节流 =====
  Timer? _deltaTimer;
  String _pendingText = '';
  static const Duration _throttleDuration = Duration(milliseconds: 50);

  // ===== fillInput 事件 =====
  String? _fillInputText;

  // ===== 世界事件 Toast =====
  String? _pendingEventToast;

  // ===== 滚动请求（由页面设置） =====
  /// 页面在 initState 中赋值，ViewModel 在 flushDelta 时调用（jumpTo）。
  void Function()? scrollToBottom;

  // ===== Getters =====
  List<GameNarrativeLine> get lines => _lines;
  GameSessionState get state => _state;
  bool get isSending => _isSending;
  List<String> get suggestedActions => _suggestedActions;
  List<String> get visitedScenes => _visitedScenes;
  int? get streamingLineIndex => _streamingLineIndex;
  String get streamingText => _streamingText;
  bool get llmOnline => _llmOnline;

  /// 待展示的世界事件 Toast（消费后清空）。
  String? consumeEventToast() {
    final msg = _pendingEventToast;
    _pendingEventToast = null;
    return msg;
  }

  // ===== 初始化 =====

  /// 使用页面传入的初始状态初始化 ViewModel。
  void initialize(GameSessionState initialState) {
    if (_disposed) return;
    _state = initialState;
    _llmOnline = initialState.llmOnline;
    _visitedScenes = initialState.visitedScenes.isNotEmpty
        ? initialState.visitedScenes
        : (initialState.scene.name.isEmpty
            ? const []
            : [initialState.scene.name]);
    _lines.addAll(initialState.initialLines);
    notifyListeners();
  }

  // ===== Echo 行管理（供页面层调用） =====

  /// 在行动发送前添加 echo 行，显示用户的输入。
  void addEchoLine(String action) {
    if (_disposed) return;
    _lines.add(GameNarrativeLine(type: 'action_echo', content: action));
    notifyListeners();
  }

  /// 发送失败时移除最后一条 echo 行。
  void removeLastEchoIfEcho() {
    if (_disposed) return;
    if (_lines.isNotEmpty && _lines.last.type == 'action_echo') {
      _lines.removeLast();
      notifyListeners();
    }
  }

  // ===== 核心方法 =====

  /// 发送行动。页面负责 addEchoLine / clear controller，本方法负责
  /// 流式/非流式请求、applyActResult、错误回调。
  ///
  /// [action] 已 trim 的用户输入。
  /// [onError] 失败时回调，参数为错误消息字符串；页面可据此恢复输入框。
  Future<void> send(
    String action, {
    required void Function(String error) onError,
  }) async {
    if (action.isEmpty || _isSending) return;

    _isSending = true;
    _streamingLineIndex = null;
    _streamingText = '';
    if (!_disposed) notifyListeners();

    try {
      if (_llmOnline) {
        await _sendStream(action);
      } else {
        final result = await GameService().act(
          sessionId: _state.sessionId,
          action: action,
        );
        _applyActResult(result);
      }
      scrollToBottom?.call();
    } catch (e) {
      removeLastEchoIfEcho();
      onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _deltaTimer?.cancel();
      _deltaTimer = null;
      if (!_disposed) {
        if (_pendingText.isNotEmpty && _streamingLineIndex == null) {
          _flushDelta();
        }
        _pendingText = '';
        _isSending = false;
        _streamingLineIndex = null;
        _streamingText = '';
        notifyListeners();
      }
    }
  }

  /// SSE 流式行动。
  Future<void> _sendStream(String action) async {
    GameService().cancelStream(); // 防御性取消上一次流
    _pendingText = '';
    GameActResult? finalResult;
    await for (final event in GameService().actStream(
      sessionId: _state.sessionId,
      action: action,
    )) {
      if (_disposed) return;
      switch (event.type) {
        case 'delta':
          _pendingText += event.text;
          _deltaTimer ??= Timer(_throttleDuration, () {
            _deltaTimer = null;
            _flushDelta();
          });
        case 'done':
          final payload = event.payload;
          if (payload != null) {
            finalResult = GameActResult.fromMap(payload);
          }
        case 'error':
          throw Exception(event.payload?['message']?.toString() ?? '流式叙事失败');
      }
    }
    if (finalResult != null) {
      _applyActResult(finalResult);
    }
  }

  /// 应用行动结果到状态。
  void _applyActResult(GameActResult result) {
    if (_disposed) return;

    if (_streamingLineIndex != null) {
      final idx = _streamingLineIndex!;
      String? finalProse;
      for (final line in result.narrative) {
        if (line.isActionEcho) continue;
        if (line.isProse) {
          finalProse ??= line.displayContent;
        } else {
          _lines.add(line);
        }
      }
      if (finalProse != null && finalProse.isNotEmpty) {
        _lines[idx] = GameNarrativeLine(type: 'prose', content: finalProse);
      }
      _pendingText = '';
    } else {
      _lines.addAll(result.narrative.where((l) => !l.isActionEcho));
    }

    for (final line in result.narrative) {
      if (line.isEvent) {
        _pendingEventToast = line.displayContent;
        break;
      }
    }
    _llmOnline = result.llmOnline;
    if (result.suggestedActions.isNotEmpty) {
      _suggestedActions = result.suggestedActions;
    }
    final newLocation =
        result.location.isNotEmpty ? result.location : _state.scene.name;
    if (newLocation.isNotEmpty && !_visitedScenes.contains(newLocation)) {
      _visitedScenes = [..._visitedScenes, newLocation];
    }
    _state = _state.copyWith(
      scene: _state.scene.copyWithName(newLocation),
      gameTime: result.gameTime.isNotEmpty ? result.gameTime : _state.gameTime,
      overallFavorability: result.overallFavorability,
      playerFocus: result.playerFocus.isNotEmpty
          ? result.playerFocus
          : _state.playerFocus,
      npcs: result.npcs.isNotEmpty ? result.npcs : _state.npcs,
      inventory: result.inventory,
      visitedScenes: _visitedScenes,
    );
    notifyListeners();
  }

  /// 请求页面将输入框填充为 [text] 并聚焦。
  /// 页面通过 [consumeFillInput] 消费此事件。
  void fillInput(String text) {
    if (_disposed) return;
    _fillInputText = text;
    notifyListeners();
  }

  /// 消费 fillInput 事件，返回待填充文本（仅一次）。
  String? consumeFillInput() {
    final text = _fillInputText;
    _fillInputText = null;
    return text;
  }

  /// 节流 flush：将 pendingText 写入 lines 并通知 UI。
  void _flushDelta() {
    if (_disposed) return;
    if (_pendingText.isEmpty) return;
    if (_streamingLineIndex == null) {
      _lines.add(GameNarrativeLine(type: 'prose', content: _pendingText));
      _streamingLineIndex = _lines.length - 1;
    } else {
      _lines[_streamingLineIndex!] = GameNarrativeLine(
        type: 'prose',
        content: _pendingText,
      );
    }
    _streamingText = _pendingText;
    notifyListeners();
    // 流式期间通知页面 jumpTo 底部（避免 animateTo 队列堆积）。
    scrollToBottom?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    _deltaTimer?.cancel();
    GameService().cancelStream();
    super.dispose();
  }
}
