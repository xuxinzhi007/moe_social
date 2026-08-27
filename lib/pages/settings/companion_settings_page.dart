import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/companion_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';

class CompanionSettingsPage extends StatefulWidget {
  const CompanionSettingsPage({super.key});

  @override
  State<CompanionSettingsPage> createState() => _CompanionSettingsPageState();
}

class _CompanionSettingsPageState extends State<CompanionSettingsPage> {
  final CompanionService _service = CompanionService();
  CompanionProactiveSettingsData? _settings;
  Object? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final settings = await _service.getProactiveSettings();
      if (!mounted) return;
      setState(() => _settings = settings);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final settings = _settings;
    if (settings == null) return;
    final initial = _minuteToTime(isStart ? settings.quietStart : settings.quietEnd);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    setState(() {
      _settings = CompanionProactiveSettingsData(
        enabled: settings.enabled,
        dailyLimit: settings.dailyLimit,
        quietStart: isStart ? minute : settings.quietStart,
        quietEnd: isStart ? settings.quietEnd : minute,
        timezoneOffset: DateTime.now().timeZoneOffset.inMinutes,
      );
    });
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final saved = await _service.updateProactiveSettings(settings);
      if (!mounted) return;
      setState(() => _settings = saved);
      MoeToast.success(context, '主动陪伴设置已保存');
    } catch (error) {
      if (mounted) {
        MoeToast.error(context, error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TimeOfDay _minuteToTime(int minute) {
    final normalized = minute.clamp(0, 1439);
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AI 伙伴设置'),
        centerTitle: true,
        backgroundColor: MoeTokens.surface1,
        foregroundColor: MoeTokens.titleText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _error != null
          ? MoeErrorState.fromError(_error, onRetry: _load)
          : settings == null
              ? const Center(child: MoeLoading())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      _buildIntro(),
                      const SizedBox(height: 16),
                      _buildSettingsCard(settings),
                      const SizedBox(height: 16),
                      _buildPrivacyNote(),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const MoeSmallLoading(
                                size: 18,
                                color: Colors.white,
                              )
                            : const Text('保存设置'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: MoeTokens.heroGradient,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          SizedBox(height: 12),
          Text(
            '让 TA 在合适的时候出现',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '你可以随时关闭主动联系，也可以安排一段不被打扰的时间。',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(CompanionProactiveSettingsData settings) {
    return Card(
      margin: EdgeInsets.zero,
      color: MoeTokens.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        side: const BorderSide(color: MoeTokens.surfaceBorder),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('允许主动联系'),
            subtitle: const Text('伙伴会根据关系和近况发送少量回访消息'),
            value: settings.enabled,
            activeThumbColor: MoeTokens.primary,
            onChanged: (value) => setState(() {
              _settings = CompanionProactiveSettingsData(
                enabled: value,
                dailyLimit: settings.dailyLimit,
                quietStart: settings.quietStart,
                quietEnd: settings.quietEnd,
                timezoneOffset: DateTime.now().timeZoneOffset.inMinutes,
              );
            }),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('免打扰开始'),
            subtitle: const Text('从这个时间起不发送主动消息'),
            trailing: Text(_minuteToTime(settings.quietStart).format(context)),
            onTap: () => _pickTime(isStart: true),
          ),
          ListTile(
            title: const Text('免打扰结束'),
            subtitle: const Text('到这个时间后恢复主动消息'),
            trailing: Text(_minuteToTime(settings.quietEnd).format(context)),
            onTap: () => _pickTime(isStart: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return const Text(
      '当前使用设备时区保存免打扰规则。主动消息会受到每日频控和最近发送记录限制。',
      style: TextStyle(color: MoeTokens.hintText, fontSize: 12, height: 1.45),
    );
  }
}
