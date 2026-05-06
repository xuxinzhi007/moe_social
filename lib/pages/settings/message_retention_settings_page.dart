import 'package:flutter/material.dart';
import '../../auth_service.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/moe_toast.dart';

/// 与后端 `PUT /api/user/:id` 的 `message_retention`（`auto` | `7` | `30`）及
/// `message_retention_choice` 对齐。
class MessageRetentionSettingsPage extends StatefulWidget {
  const MessageRetentionSettingsPage({super.key});

  @override
  State<MessageRetentionSettingsPage> createState() =>
      _MessageRetentionSettingsPageState();
}

class _MessageRetentionSettingsPageState
    extends State<MessageRetentionSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  User? _user;
  String _value = 'auto'; // auto | 7 | 30

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final id = await AuthService.getUserId();
      if (id.isEmpty) {
        if (mounted) {
          MoeToast.error(context, '请先登录');
        }
        return;
      }
      final u = await ApiService.getUserInfo(id);
      if (!mounted) return;
      setState(() {
        _user = u;
        _value = _retentionApiValueFromChoice(u.messageRetentionChoice);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        MoeToast.error(context, e.toString());
      }
    }
  }

  static String _retentionApiValueFromChoice(int choice) {
    if (choice == 7) return '7';
    if (choice == 30) return '30';
    return 'auto';
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await ApiService.updateUserInfo(
        u.id,
        messageRetention: _value,
      );
      if (!mounted) return;
      setState(() {
        _user = updated;
        _value = _retentionApiValueFromChoice(updated.messageRetentionChoice);
        _saving = false;
      });
      MoeToast.success(context, '已保存');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        MoeToast.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('私信记录保留'),
        backgroundColor: Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '设置你发送的私信在服务端按「发送方规则」计算保留天数时的个人偏好；'
                  '具体过期仍以服务端与会员状态为准。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('自动'),
                        subtitle: const Text('跟随会员与系统默认策略'),
                        value: 'auto',
                        groupValue: _value,
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => _value = v);
                              },
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('至少保留 7 天'),
                        value: '7',
                        groupValue: _value,
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => _value = v);
                              },
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('至少保留 30 天'),
                        value: '30',
                        groupValue: _value,
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() => _value = v);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_user != null)
                  Text(
                    '当前服务端选择值：${_user!.messageRetentionChoice} '
                    '（${_choiceLabel(_user!.messageRetentionChoice)}）',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
    );
  }

  static String _choiceLabel(int c) {
    if (c == 7) return '7 天';
    if (c == 30) return '30 天';
    return '自动';
  }
}
