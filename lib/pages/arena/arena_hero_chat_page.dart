import 'package:flutter/material.dart';

import '../../game/arena/arena_view_model.dart';
import '../../services/api_client.dart' show ApiException;
import '../../services/arena_service.dart';
import '../../theme/moe_tokens.dart';

/// K3 小家闲聊：与旗舰英雄（M1 小星）对话。
/// 会话内消息为当次会话本地状态；上下文连续性由后端 hero 作用域记录保证。
class ArenaHeroChatPage extends StatefulWidget {
  const ArenaHeroChatPage({super.key, required this.hero, required this.bond});

  final ArenaHero hero;
  final int bond;

  @override
  State<ArenaHeroChatPage> createState() => _ArenaHeroChatPageState();
}

class _HeroChatMessage {
  const _HeroChatMessage(
      {required this.text, required this.isUser, this.isError = false});

  final String text;
  final bool isUser;
  final bool isError;
}

class _ArenaHeroChatPageState extends State<ArenaHeroChatPage> {
  final ArenaService _service = ArenaService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_HeroChatMessage> _messages = <_HeroChatMessage>[];
  bool _sending = false;

  bool get _unlocked => widget.bond >= ArenaViewModel.heroChatBondRequired;

  @override
  void initState() {
    super.initState();
    if (_unlocked) {
      _messages.add(_HeroChatMessage(
        text: '我是${widget.hero.name}，活世界的向导。想聊聊营地今天发生的事吗？',
        isUser: false,
      ));
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending || !_unlocked) return;
    setState(() {
      _sending = true;
      _messages.add(_HeroChatMessage(text: text, isUser: true));
    });
    _inputCtrl.clear();
    _scrollToBottom();
    try {
      final reply = await _service.heroChat(widget.hero.id, text);
      if (!mounted) return;
      setState(() {
        _messages.add(_HeroChatMessage(text: reply, isUser: false));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
            _HeroChatMessage(text: e.message, isUser: false, isError: true));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const _HeroChatMessage(
          text: '网络好像不太稳定，稍后再试试吧。',
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: MoeTokens.cardBackground,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Text(widget.hero.imageAsset == null ? '⭐' : '',
                style: const TextStyle(fontSize: MoeTokens.textXl)),
            if (widget.hero.imageAsset != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: Image.asset(
                  widget.hero.imageAsset!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: MoeTokens.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hero.name,
                  style: const TextStyle(
                    color: MoeTokens.titleText,
                    fontSize: MoeTokens.textBase,
                    fontWeight: MoeTokens.fontWeightTitle,
                  ),
                ),
                Text(
                  _unlocked ? '羁绊 ${widget.bond} · 闲聊中' : '羁绊 ${widget.bond}',
                  style: const TextStyle(
                    color: MoeTokens.inkMuted,
                    fontSize: MoeTokens.textXs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _unlocked ? _buildChat() : _buildLocked(),
      ),
    );
  }

  Widget _buildLocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MoeTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: MoeTokens.spaceMd),
            const Text(
              '闲聊未解锁',
              style: TextStyle(
                color: MoeTokens.titleText,
                fontSize: MoeTokens.textLg,
                fontWeight: MoeTokens.fontWeightTitle,
              ),
            ),
            const SizedBox(height: MoeTokens.spaceSm),
            Text(
              '羁绊达到 ${ArenaViewModel.heroChatBondRequired} 级后，'
              '${widget.hero.name}才有空坐下来和你聊天。回到小家送礼培养吧。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MoeTokens.inkMuted,
                fontSize: MoeTokens.textSm,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(MoeTokens.spaceMd),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _messages.length) {
                return _bubble(
                  const _HeroChatMessage(text: '…', isUser: false),
                );
              }
              return _bubble(_messages[index]);
            },
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _bubble(_HeroChatMessage message) {
    final isUser = message.isUser;
    final bg = message.isError
        ? MoeTokens.softChipBg
        : isUser
            ? MoeTokens.primary
            : MoeTokens.cardBackground;
    final fg = message.isError
        ? MoeTokens.warning
        : isUser
            ? Colors.white
            : MoeTokens.bodyText;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: MoeTokens.spaceSm),
        padding: const EdgeInsets.symmetric(
          horizontal: MoeTokens.spaceMd,
          vertical: MoeTokens.spaceSm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
          border: message.isError
              ? Border.all(color: MoeTokens.warning.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(color: fg, fontSize: MoeTokens.textSm, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MoeTokens.spaceMd,
        MoeTokens.spaceSm,
        MoeTokens.spaceMd,
        MoeTokens.spaceSm,
      ),
      decoration: const BoxDecoration(
        color: MoeTokens.cardBackground,
        border: Border(top: BorderSide(color: MoeTokens.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: !_sending,
              maxLength: 200,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: '和${widget.hero.name}说点什么…',
                hintStyle: const TextStyle(
                  color: MoeTokens.hintText,
                  fontSize: MoeTokens.textSm,
                ),
                counterText: '',
                filled: true,
                fillColor: MoeTokens.softChipBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MoeTokens.spaceMd,
                  vertical: MoeTokens.spaceSm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: MoeTokens.primary),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
