import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_network_provider.dart';
import '../../services/game_network_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/layout/adaptive_page_scaffold.dart';

/// Android 异地联机网络实验页。
class GameNetworkLabPage extends StatefulWidget {
  const GameNetworkLabPage({super.key});

  @override
  State<GameNetworkLabPage> createState() => _GameNetworkLabPageState();
}

class _GameNetworkLabPageState extends State<GameNetworkLabPage>
    with WidgetsBindingObserver {
  late final TextEditingController _roomController;
  late final GameNetworkProvider _provider;
  String _role = 'host';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomController = TextEditingController(text: _newRoomId());
    _provider = GameNetworkProvider();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomController.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameNetworkProvider>.value(
      value: _provider,
      child: Consumer<GameNetworkProvider>(
        builder: (context, provider, _) {
          return AdaptivePageScaffold(
            title: '异地联机实验',
            body: ListView(
              padding: const EdgeInsets.only(bottom: MoeTokens.space2xl),
              children: [
                _buildStatusPanel(provider),
                const SizedBox(height: MoeTokens.spaceLg),
                _buildRoomField(provider),
                const SizedBox(height: MoeTokens.spaceLg),
                _buildRoleSelector(provider),
                const SizedBox(height: MoeTokens.spaceLg),
                _buildAddressPanel(provider),
                const SizedBox(height: MoeTokens.space2xl),
                _buildActionButton(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusPanel(GameNetworkProvider provider) {
    final color = _statusColor(provider.state);
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(provider.state),
                  style: const TextStyle(
                    color: MoeTokens.titleText,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                    fontSize: MoeTokens.textMd,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  provider.message,
                  style: const TextStyle(
                    color: MoeTokens.inkMuted,
                    fontSize: MoeTokens.textSm,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${provider.peerCount}/2',
            style: TextStyle(
              color: color,
              fontWeight: MoeTokens.fontWeightTitle,
              fontSize: MoeTokens.textLg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomField(GameNetworkProvider provider) {
    return TextField(
      controller: _roomController,
      enabled: !provider.isLocked,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: '房间号',
        hintText: '两台设备填写同一个房间号',
        prefixIcon: const Icon(Icons.meeting_room_outlined),
        suffixIcon: IconButton(
          tooltip: '复制房间号',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: _roomController.text.trim()),
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('房间号已复制')),
            );
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(GameNetworkProvider provider) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'host',
          icon: Icon(Icons.home_work_outlined),
          label: Text('我是主机'),
        ),
        ButtonSegment<String>(
          value: 'guest',
          icon: Icon(Icons.login_rounded),
          label: Text('我是加入者'),
        ),
      ],
      selected: {_role},
      onSelectionChanged: provider.isLocked
          ? null
          : (selection) {
              if (selection.isEmpty) return;
              setState(() => _role = selection.first);
            },
    );
  }

  Widget _buildAddressPanel(GameNetworkProvider provider) {
    final localIp = _role == 'host'
        ? GameNetworkService.hostVirtualIp
        : GameNetworkService.guestVirtualIp;
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceLg),
      decoration: BoxDecoration(
        color: MoeTokens.softChipBg,
        borderRadius: BorderRadius.circular(MoeTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _role == 'host' ? '本机联机地址' : '主机联机地址',
            style: const TextStyle(
              color: MoeTokens.titleText,
              fontWeight: MoeTokens.fontWeightSubtitle,
              fontSize: MoeTokens.textMd,
            ),
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  GameNetworkService.hostVirtualIp,
                  style: const TextStyle(
                    color: MoeTokens.primary,
                    fontWeight: MoeTokens.fontWeightTitle,
                    fontSize: MoeTokens.text2xl,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制主机地址',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(
                      text: GameNetworkService.hostVirtualIp,
                    ),
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('主机地址已复制')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          Text(
            '本端虚拟地址：$localIp · 游戏端口：24642/UDP',
            style: const TextStyle(
              color: MoeTokens.inkMuted,
              fontSize: MoeTokens.textSm,
            ),
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          Text(
            '发送 ${provider.sentPackets} · 接收 ${provider.receivedPackets}',
            style: const TextStyle(
              color: MoeTokens.inkMuted,
              fontSize: MoeTokens.textSm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(GameNetworkProvider provider) {
    final isRunning = provider.isRunning;
    final isBusy = provider.isBusy;
    return FilledButton.icon(
      onPressed: isBusy
          ? null
          : () async {
              if (isRunning) {
                await provider.stop();
                return;
              }
              await provider.start(
                roomId: _roomController.text,
                role: _role,
              );
            },
      icon: Icon(
        isRunning ? Icons.stop_circle_outlined : Icons.play_arrow_rounded,
      ),
      label: Text(
        isRunning
            ? '停止实验'
            : provider.state == GameNetworkState.waitingVpnPermission
                ? '再次启动'
                : '启动连接',
      ),
    );
  }

  static String _newRoomId() {
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'farm-${suffix.substring(suffix.length > 6 ? suffix.length - 6 : 0)}';
  }

  static String _statusLabel(GameNetworkState state) {
    switch (state) {
      case GameNetworkState.idle:
        return '未启动';
      case GameNetworkState.connecting:
        return '连接中';
      case GameNetworkState.waitingVpnPermission:
        return '等待系统授权';
      case GameNetworkState.running:
        return '运行中';
      case GameNetworkState.stopped:
        return '已停止';
      case GameNetworkState.error:
        return '连接异常';
    }
  }

  static Color _statusColor(GameNetworkState state) {
    switch (state) {
      case GameNetworkState.running:
        return MoeTokens.success;
      case GameNetworkState.connecting:
      case GameNetworkState.waitingVpnPermission:
        return MoeTokens.warning;
      case GameNetworkState.error:
        return MoeTokens.danger;
      case GameNetworkState.idle:
      case GameNetworkState.stopped:
        return MoeTokens.inkMuted;
    }
  }
}
