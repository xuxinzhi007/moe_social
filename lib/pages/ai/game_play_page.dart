import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../services/game_service.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/ai_typing_indicator.dart';
import '../../widgets/game/game_narrative_block.dart';
import '../../widgets/moe_toast.dart';
import 'agent_list_page.dart';

class GamePlayPage extends StatefulWidget {
  final GameSessionState initialState;

  const GamePlayPage({super.key, required this.initialState});

  @override
  State<GamePlayPage> createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<GamePlayPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<GameNarrativeLine> _lines = [];
  late GameSessionState _state;
  bool _isSending = false;
  late bool _llmOnline;
  List<String> _suggestedActions = const [];
  List<String> _visitedScenes = const [];
  int? _streamingLineIndex;
  String _streamingText = '';

  static const _fallbackActions = [
    ('👀 观察', '看看周围有什么'),
    ('🗺️ 探索', '我想往一个方向走走看'),
    ('💬 交谈', '和附近的人说话'),
  ];

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _llmOnline = widget.initialState.llmOnline;
    _visitedScenes = widget.initialState.visitedScenes.isNotEmpty
        ? widget.initialState.visitedScenes
        : (widget.initialState.scene.name.isEmpty
            ? const []
            : [widget.initialState.scene.name]);
    _lines.addAll(_state.initialLines);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    final action = text.trim();
    if (action.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _streamingLineIndex = null;
      _streamingText = '';
    });
    _controller.clear();

    _lines.add(GameNarrativeLine(type: 'action_echo', content: action));

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
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _streamingLineIndex = null;
          _streamingText = '';
        });
      }
    }
  }

  Future<void> _sendStream(String action) async {
    GameActResult? finalResult;
    await for (final event in GameService().actStream(
      sessionId: _state.sessionId,
      action: action,
    )) {
      if (!mounted) return;
      switch (event.type) {
        case 'delta':
          setState(() {
            _streamingText += event.text;
            if (_streamingLineIndex == null) {
              _lines.add(
                  GameNarrativeLine(type: 'prose', content: _streamingText));
              _streamingLineIndex = _lines.length - 1;
            } else {
              _lines[_streamingLineIndex!] = GameNarrativeLine(
                type: 'prose',
                content: _streamingText,
              );
            }
          });
          _scrollToBottom();
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

  void _applyActResult(GameActResult result) {
    if (!mounted) return;
    setState(() {
      if (_streamingLineIndex == null) {
        _lines.addAll(result.narrative.where((l) => !l.isActionEcho));
      } else {
        for (final line in result.narrative) {
          if (line.isActionEcho) continue;
          if (line.isProse) {
            _lines[_streamingLineIndex!] = line;
          } else {
            _lines.add(line);
          }
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
        gameTime:
            result.gameTime.isNotEmpty ? result.gameTime : _state.gameTime,
        overallFavorability: result.overallFavorability,
        playerFocus: result.playerFocus.isNotEmpty
            ? result.playerFocus
            : _state.playerFocus,
        npcs: result.npcs.isNotEmpty ? result.npcs : _state.npcs,
        inventory: result.inventory,
        visitedScenes: _visitedScenes,
      );
    });
  }

  void _fillInput(String text) {
    _controller.text = text;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: Row(
          children: [
            _AiStatusDot(online: _llmOnline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _state.scene.name.isEmpty ? '文字世界' : _state.scene.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _llmOnline ? 'AI 在线' : 'AI 离线',
                    style: TextStyle(
                      fontSize: 11,
                      color: _llmOnline
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE53935),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AiBrandTokens.primary,
        actions: [
          IconButton(
            tooltip: '世界地图',
            icon: Badge(
              isLabelVisible: _visitedScenes.length > 1,
              label: Text('${_visitedScenes.length}'),
              child: const Icon(Icons.map_outlined),
            ),
            onPressed: _showWorldMap,
          ),
          IconButton(
            tooltip: '背包',
            icon: Badge(
              isLabelVisible: _state.inventory.isNotEmpty,
              label: Text('${_state.inventory.length}'),
              child: const Icon(Icons.backpack_outlined),
            ),
            onPressed: _showInventory,
          ),
          IconButton(
            tooltip: 'AI 配置',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgentListPage()),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AiChatBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _GameHud(
                location: _state.scene.name,
                sceneDescription: _state.scene.description,
                focus: _state.playerFocus,
                gameTime: _state.gameTime,
                favorability: _state.overallFavorability,
                npcCount: _state.npcs.length,
                itemCount: _state.inventory.length,
                llmOnline: _llmOnline,
                visitedCount: _visitedScenes.length,
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF7F7FD5).withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AiBrandTokens.primary.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: AiBrandTokens.heroGradient,
                            ),
                          ),
                        ),
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                          itemCount: _lines.length +
                              (_isSending && _streamingLineIndex == null
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (_isSending &&
                                _streamingLineIndex == null &&
                                index == _lines.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: AiTypingIndicator(),
                              );
                            }
                            final line = _lines[index];
                            return GameNarrativeBlock(
                              line: line,
                              onHintTap: line.isHint
                                  ? () => _fillInput(line.displayContent)
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _QuickActions(
                actions: _buildQuickActions(),
                onTap: _send,
              ),
              _GameInputBar(
                controller: _controller,
                focusNode: _focusNode,
                isSending: _isSending,
                onSend: () => _send(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, String)> _buildQuickActions() {
    if (_suggestedActions.isNotEmpty) {
      return _suggestedActions
          .take(5)
          .map((text) => ('💡', text))
          .toList(growable: false);
    }
    return _fallbackActions;
  }

  void _showWorldMap() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('已探索区域', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '当前：${_state.scene.name}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_visitedScenes.isEmpty)
                  Text('尚未记录探索轨迹',
                      style: TextStyle(color: Colors.grey.shade600))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in _visitedScenes)
                        ActionChip(
                          avatar: Icon(
                            name == _state.scene.name
                                ? Icons.location_on
                                : Icons.place_outlined,
                            size: 18,
                          ),
                          label: Text(name),
                          onPressed: name == _state.scene.name
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _fillInput('前往$name');
                                },
                        ),
                    ],
                  ),
                if (_state.scene.exits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('已知出口', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final exit in _state.scene.exits)
                        ActionChip(
                          label: Text(exit),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _fillInput('前往$exit');
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInventory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('背包', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_state.inventory.isEmpty)
                  Text(
                    '空空如也。试试「捡起」或「拿取」场景中的物品。',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  ..._state.inventory.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.name),
                      subtitle: item.description.isEmpty
                          ? null
                          : Text(item.description),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AiStatusDot extends StatelessWidget {
  final bool online;

  const _AiStatusDot({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    return Tooltip(
      message: online ? 'AI 模型在线，叙事由模型生成' : 'AI 模型离线，使用模板回复',
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameHud extends StatelessWidget {
  final String location;
  final String sceneDescription;
  final String focus;
  final String gameTime;
  final int favorability;
  final int npcCount;
  final int itemCount;
  final bool llmOnline;
  final int visitedCount;

  const _GameHud({
    required this.location,
    required this.sceneDescription,
    required this.focus,
    required this.gameTime,
    required this.favorability,
    required this.npcCount,
    required this.itemCount,
    required this.llmOnline,
    required this.visitedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AiBrandTokens.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AiBrandTokens.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _hudChip(Icons.map_outlined, location),
                    if (focus.isNotEmpty)
                      _hudChip(Icons.center_focus_strong, focus),
                    _hudChip(Icons.schedule, gameTime),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AiStatusDot(online: llmOnline),
                      const SizedBox(width: 6),
                      Text(
                        llmOnline ? '在线' : '离线',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$favorability',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'NPC ×$npcCount · 🎒 ×$itemCount · 🗺️ ×$visitedCount',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (sceneDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sceneDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hudChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final List<(String, String)> actions;
  final ValueChanged<String> onTap;

  const _QuickActions({required this.actions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (label, value) in actions) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 1,
                shadowColor: AiBrandTokens.primary.withValues(alpha: 0.15),
                child: InkWell(
                  onTap: () => onTap(value),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      label == value ? label : '$label $value',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5C5C8A),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const _GameInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isSending,
                style: const TextStyle(
                  color: Color(0xFF3D3D50),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: '描述你的行动…',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: isSending ? null : AiBrandTokens.heroGradient,
                color: isSending ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: isSending ? null : onSend,
                icon: const Icon(Icons.send_rounded, size: 20),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
