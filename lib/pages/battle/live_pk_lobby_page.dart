import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battle_lobby_provider.dart';
import '../../theme/moe_tokens.dart';

/// Development-only entry for creating a V1 PK room with two existing users.
class LivePkLobbyPage extends StatefulWidget {
  const LivePkLobbyPage({super.key});

  @override
  State<LivePkLobbyPage> createState() => _LivePkLobbyPageState();
}

class _LivePkLobbyPageState extends State<LivePkLobbyPage> {
  final _leftController = TextEditingController();
  final _rightController = TextEditingController();
  final _roomController = TextEditingController();
  late final BattleLobbyProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = BattleLobbyProvider();
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _roomController.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<BattleLobbyProvider>(
        builder: (context, provider, _) => Scaffold(
          appBar: AppBar(title: const Text('礼物 PK 联调')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(MoeTokens.spaceLg),
              children: [
                const Text(
                  '创建一个 120 秒的双人 PK 房间',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MoeTokens.spaceSm),
                const Text('创建者必须是其中一位参赛者；使用两个数据库中已有的用户 ID。'),
                const SizedBox(height: MoeTokens.space2xl),
                TextField(
                  controller: _leftController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '左方用户 ID'),
                ),
                const SizedBox(height: MoeTokens.spaceLg),
                TextField(
                  controller: _rightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '右方用户 ID'),
                ),
                const SizedBox(height: MoeTokens.space2xl),
                FilledButton.icon(
                  onPressed: provider.creating
                      ? null
                      : () => _create(context, provider),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(provider.creating ? '正在创建…' : '创建并开始 PK'),
                ),
                const SizedBox(height: MoeTokens.space3xl),
                const Divider(),
                const SizedBox(height: MoeTokens.spaceLg),
                const Text(
                  '进入已有房间',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MoeTokens.spaceMd),
                TextField(
                  controller: _roomController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PK 房间 ID'),
                ),
                const SizedBox(height: MoeTokens.spaceLg),
                OutlinedButton.icon(
                  onPressed: () => _enterRoom(context),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('进入房间'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create(
      BuildContext context, BattleLobbyProvider provider) async {
    try {
      final room = await provider.createRoom(
        leftUserId: _leftController.text,
        rightUserId: _rightController.text,
      );
      if (!context.mounted) {
        return;
      }
      Navigator.of(context)
          .pushReplacementNamed('/battle/room', arguments: {'roomId': room.id});
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _enterRoom(BuildContext context) {
    final roomId = _roomController.text.trim();
    if (int.tryParse(roomId) == null || int.parse(roomId) <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入有效的 PK 房间 ID')));
      return;
    }
    Navigator.of(context)
        .pushNamed('/battle/room', arguments: {'roomId': roomId});
  }
}
