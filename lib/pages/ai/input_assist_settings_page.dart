import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class InputAssistSettingsPage extends StatefulWidget {
  const InputAssistSettingsPage({super.key});

  @override
  State<InputAssistSettingsPage> createState() => _InputAssistSettingsPageState();
}

class _InputAssistSettingsPageState extends State<InputAssistSettingsPage> {
  static const _channel = MethodChannel('com.moe_social/autoglm');

  bool _enabled = false;
  bool _loading = true;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('getInputAssistEnabled') ?? false;
      final overlay =
          await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _overlayGranted = overlay;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setEnabled(bool v) async {
    setState(() => _enabled = v);
    try {
      await _channel.invokeMethod('setInputAssistEnabled', {'enabled': v});
    } catch (_) {}

    // 简化模式：不做输入框检测。开启时直接常驻悬浮球，关闭时移除。
    if (v) {
      await _showBubble();
    } else {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  Future<void> _requestOverlay() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  Future<void> _showBubble() async {
    try {
      final overlay =
          await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (!overlay) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先授权悬浮窗权限')),
        );
        return;
      }
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Moe AI",
        overlayContent: "点击生成回复",
        // 关键：不要抢焦点，否则 QQ 输入框点不了
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.right,
        height: 140,
        width: 140,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('悬浮球已开启（去 QQ/桌面右侧看看）')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开启失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('输入辅助悬浮球')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    title: const Text('启用输入辅助悬浮球'),
                    subtitle: const Text('在输入框旁弹出，基于剪贴板生成回复'),
                    value: _enabled,
                    onChanged: _setEnabled,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          _overlayGranted
                              ? Icons.check_circle_rounded
                              : Icons.warning_rounded,
                          color: _overlayGranted
                              ? Colors.green
                              : Colors.orangeAccent,
                        ),
                        title: const Text('悬浮窗权限'),
                        subtitle:
                            Text(_overlayGranted ? '已授权' : '未授权（必须）'),
                        trailing: TextButton(
                          onPressed: _requestOverlay,
                          child: const Text('去授权'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.bug_report_rounded),
                        title: const Text('立即显示悬浮球'),
                        subtitle: const Text('不做输入框检测，直接常驻显示'),
                        trailing: TextButton(
                          onPressed: _showBubble,
                          child: const Text('显示'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cancel_rounded),
                        title: const Text('关闭悬浮球'),
                        subtitle: const Text('紧急关闭，恢复 QQ 点击/返回'),
                        trailing: TextButton(
                          onPressed: () async {
                            await FlutterOverlayWindow.closeOverlay();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已关闭悬浮球')),
                            );
                          },
                          child: const Text('关闭'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('在 QQ/微信 怎么用？',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 8),
                        Text('1) 在本页打开「启用输入辅助悬浮球」'),
                        Text('2) 系统设置 → 应用 → Moe Social → 允许「显示在其他应用上层」'),
                        SizedBox(height: 8),
                        Text('使用流程：'),
                        Text('A) 在 QQ 聊天里先复制对方一句话（可选）'),
                        Text('B) 悬浮球常驻在屏幕右侧，点它展开面板'),
                        Text('D) 面板会读取剪贴板内容 → 点「生成回复」'),
                        Text('E) 点「复制并关闭」，回到 QQ 里长按输入框粘贴发送'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

