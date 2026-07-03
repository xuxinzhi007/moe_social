import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_state.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_chat_background.dart';
import '../../widgets/ai/ai_typing_indicator.dart';
import '../../widgets/game/game_hud.dart';
import '../../widgets/game/game_input_bar.dart';
import '../../widgets/game/game_narrative_block.dart';
import '../../widgets/game/game_quick_actions.dart';
import '../../widgets/moe_toast.dart';
import 'agent_list_page.dart';
import 'game_play_viewmodel.dart';

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
  late final GamePlayViewModel _vm = GamePlayViewModel();
  bool _fillInputHandled = true;
  int _initialLineCount = 0;

  static const _fallbackActions = [
    ('👀 观察', '看看周围有什么'),
    ('🗺️ 探索', '我想往一个方向走走看'),
    ('💬 交谈', '和附近的人说话'),
  ];

  @override
  void initState() {
    super.initState();
    _vm.scrollToBottom = _jumpToBottom;
    _vm.addListener(_onViewModelChanged);
    _vm.initialize(widget.initialState);
    _initialLineCount = _vm.lines.length;
    _scrollToBottom();
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    final text = _vm.consumeFillInput();
    if (text != null) {
      _controller.text = text;
      _focusNode.requestFocus();
      _fillInputHandled = true;
    } else if (_fillInputHandled) {
      _fillInputHandled = false;
    }
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

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _send(String text) {
    final action = text.trim();
    if (action.isEmpty || _vm.isSending) return;
    _controller.clear();
    _vm.addEchoLine(action);
    _vm.send(
      action,
      onError: (error) {
        _controller.text = action;
        if (mounted) {
          MoeToast.error(context, error);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GamePlayViewModel>.value(
      value: _vm,
      child: Consumer<GamePlayViewModel>(
        builder: (context, vm, _) => _buildScaffold(vm),
      ),
    );
  }

  Widget _buildScaffold(GamePlayViewModel vm) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: Row(
          children: [
            AiStatusDot(online: vm.llmOnline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.state.scene.name.isEmpty
                        ? '文字世界'
                        : vm.state.scene.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    vm.llmOnline ? 'AI 在线' : 'AI 离线',
                    style: TextStyle(
                      fontSize: 11,
                      color: vm.llmOnline
                          ? MoeTokens.success
                          : MoeTokens.danger,
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
              isLabelVisible: vm.visitedScenes.length > 1,
              label: Text('${vm.visitedScenes.length}'),
              child: const Icon(Icons.map_outlined),
            ),
            onPressed: _showWorldMap,
          ),
          IconButton(
            tooltip: '背包',
            icon: Badge(
              isLabelVisible: vm.state.inventory.isNotEmpty,
              label: Text('${vm.state.inventory.length}'),
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
              GameHud(
                location: vm.state.scene.name,
                sceneDescription: vm.state.scene.description,
                focus: vm.state.playerFocus,
                gameTime: vm.state.gameTime,
                favorability: vm.state.overallFavorability,
                npcCount: vm.state.npcs.length,
                itemCount: vm.state.inventory.length,
                llmOnline: vm.llmOnline,
                visitedCount: vm.visitedScenes.length,
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(MoeTokens.spaceMd, MoeTokens.spaceSm, MoeTokens.spaceMd, MoeTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: MoeTokens.gamePageBackground,
                    borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
                    border: Border.all(
                      color:
                          MoeTokens.primary.withValues(alpha: 0.15),
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
                    borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
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
                          padding:
                              const EdgeInsets.fromLTRB(18, 16, 18, 20),
                          itemCount: vm.lines.length +
                              (vm.isSending && vm.streamingLineIndex == null
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (vm.isSending &&
                                vm.streamingLineIndex == null &&
                                index == vm.lines.length) {
                              return const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 16),
                                child: AiTypingIndicator(),
                              );
                            }
                            final line = vm.lines[index];
                            final bool shouldAnimate = index >= _initialLineCount &&
                                index != vm.streamingLineIndex;
                            return GameNarrativeBlock(
                              line: line,
                              animate: shouldAnimate,
                              onHintTap: line.isHint
                                  ? () => vm.fillInput(line.displayContent)
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GameQuickActions(
                actions: _buildQuickActions(vm),
                onTap: _send,
              ),
              GameInputBar(
                controller: _controller,
                focusNode: _focusNode,
                isSending: vm.isSending,
                onSend: () => _send(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, String)> _buildQuickActions(GamePlayViewModel vm) {
    if (vm.suggestedActions.isNotEmpty) {
      return vm.suggestedActions
          .take(5)
          .map((text) => ('💡', text))
          .toList(growable: false);
    }
    return _fallbackActions;
  }

  void _showWorldMap() {
    final vm = _vm;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: MoeTokens.gamePageBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(MoeTokens.radius2xl)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('已探索区域',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '当前：${vm.state.scene.name}',
                  style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (vm.visitedScenes.isEmpty)
                  Text('尚未记录探索轨迹',
                      style: TextStyle(color: Colors.grey.shade600))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in vm.visitedScenes)
                        ActionChip(
                          avatar: Icon(
                            name == vm.state.scene.name
                                ? Icons.location_on
                                : Icons.place_outlined,
                            size: 18,
                          ),
                          label: Text(name),
                          onPressed: name == vm.state.scene.name
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  vm.fillInput('前往$name');
                                },
                        ),
                    ],
                  ),
                if (vm.state.scene.exits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('已知出口',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final exit in vm.state.scene.exits)
                        ActionChip(
                          label: Text(exit),
                          onPressed: () {
                            Navigator.pop(ctx);
                            vm.fillInput('前往$exit');
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
    final vm = _vm;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: MoeTokens.gamePageBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(MoeTokens.radius2xl)),
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
                if (vm.state.inventory.isEmpty)
                  Text(
                    '空空如也。试试「捡起」或「拿取」场景中的物品。',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  ...vm.state.inventory.map(
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
