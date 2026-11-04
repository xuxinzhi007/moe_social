import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/feature_flags.dart';
import '../../models/reply_assist_models.dart';
import '../../services/reply_assist_overlay_bridge.dart';
import '../../services/reply_assist_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';
import 'reply_assist_permission.dart';

/// Android 读屏 + 全平台粘贴/截图输入；只复制、不代发。
class ReplyAssistPage extends StatefulWidget {
  const ReplyAssistPage({super.key});

  @override
  State<ReplyAssistPage> createState() => _ReplyAssistPageState();
}

class _ReplyAssistPageState extends State<ReplyAssistPage>
    with WidgetsBindingObserver {
  static const _introPref = 'reply_assist_pet_intro_seen';

  final ReplyAssistService _service = ReplyAssistService();
  final TextEditingController _pasteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  ReplyAssistSuggestResult? _result;
  Object? _error;
  bool _loading = false;
  File? _pickedImage;
  String? _uploadedImageUrl;
  bool _a11yEnabled = false;
  bool _overlayPermissionGranted = false;
  bool _overlayVisible = false;
  ReplyAssistPermGap? _focusGap;

  bool get _androidPetEnabled =>
      Platform.isAndroid && FeatureFlags.replyAssistPrototype;

  @override
  void initState() {
    super.initState();
    if (_androidPetEnabled) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_refreshAndroidStatus());
    }
  }

  @override
  void dispose() {
    if (_androidPetEnabled) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _pasteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _androidPetEnabled) {
      unawaited(_refreshAndroidStatus());
    }
  }

  Future<void> _refreshAndroidStatus() async {
    try {
      final enabled = await ReplyAssistOverlayBridge.isAccessibilityEnabled();
      final overlayPerm =
          await ReplyAssistOverlayBridge.isOverlayPermissionGranted();
      final overlay = await ReplyAssistOverlayBridge.isOverlayVisible();
      if (!mounted) return;
      setState(() {
        _a11yEnabled = enabled;
        _overlayPermissionGranted = overlayPerm;
        _overlayVisible = overlay;
        final gap = firstReplyAssistPermGap(
          a11yEnabled: enabled,
          overlayPermissionGranted: overlayPerm,
        );
        if (gap == null) _focusGap = null;
      });
    } catch (_) {
      // 非 Android 或未注册插件时忽略。
    }
  }

  Future<void> _openAccessibilitySettings() async {
    MoeToast.info(context, '无障碍只读可见聊天，不会代发或自动点击');
    try {
      await ReplyAssistOverlayBridge.openAccessibilitySettings();
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
  }

  Future<void> _openOverlaySettings() async {
    MoeToast.info(context, '悬浮窗用于贴纸桌宠，不挡微信正常操作');
    try {
      await ReplyAssistOverlayBridge.openOverlaySettings();
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
  }

  Future<void> _onA11yChip() async {
    if (_a11yEnabled) {
      MoeToast.info(context, '无障碍已开启');
      return;
    }
    await _openAccessibilitySettings();
  }

  Future<void> _onOverlayPermChip() async {
    if (_overlayPermissionGranted) {
      MoeToast.info(context, '悬浮窗已授权');
      return;
    }
    await _openOverlaySettings();
  }

  Future<void> _onPetChip() async {
    final gap = firstReplyAssistPermGap(
      a11yEnabled: _a11yEnabled,
      overlayPermissionGranted: _overlayPermissionGranted,
    );
    if (gap != null) {
      setState(() => _focusGap = gap);
      if (mounted) MoeToast.info(context, replyAssistPermGapHint(gap));
      return;
    }
    if (!_overlayVisible) {
      final proceed = await _confirmFirstPetIfNeeded();
      if (!proceed || !mounted) return;
    }
    try {
      final next = await ReplyAssistOverlayBridge.toggleOverlay();
      if (!mounted) return;
      setState(() => _overlayVisible = next);
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
  }

  Future<bool> _confirmFirstPetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_introPref) == true) return true;
    if (!mounted) return false;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('伙伴·回复参谋'),
          content: const Text(
            '会在微信旁显示贴纸小脸：点一下读取可见聊天，给出三条草稿。只复制、不代发。\n\n'
            '需要无障碍（只读）和悬浮窗。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('显示桌宠'),
            ),
          ],
        );
      },
    );
    if (go == true) {
      await prefs.setBool(_introPref, true);
    }
    return go == true;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _pickedImage = File(picked.path);
      _uploadedImageUrl = null;
      _result = null;
      _error = null;
    });
  }

  Future<void> _submit({required String source}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String? imageUrl = _uploadedImageUrl;
      if (_pickedImage != null && imageUrl == null) {
        imageUrl = await _service.uploadScreenshot(_pickedImage!);
        _uploadedImageUrl = imageUrl;
      }
      final result = await _service.suggest(
        source: source,
        pastedText: _pasteController.text.trim(),
        imageUrl: imageUrl,
        messages: const [],
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readFromOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await ReplyAssistOverlayBridge.channel
          .invokeMethod<Map>('readWeChatSnapshot');
      final map =
          raw == null ? <dynamic, dynamic>{} : Map<String, dynamic>.from(raw);
      final needsFallback = map['needs_screenshot_fallback'] == true;
      final messagesRaw = map['messages'];
      final messages = messagesRaw is List
          ? messagesRaw
              .whereType<Map>()
              .map(
                (m) => ReplyAssistChatMessage(
                  role: m['role']?.toString() ?? 'unknown',
                  text: m['text']?.toString() ?? '',
                ),
              )
              .where((m) => m.text.isNotEmpty)
              .toList()
          : <ReplyAssistChatMessage>[];

      if (needsFallback || messages.isEmpty) {
        if (mounted) {
          MoeToast.info(context, '读屏为空，请粘贴对话或上传截图');
        }
        return;
      }

      setState(() => _loading = true);
      final result = await _service.suggest(
        source: 'a11y',
        messages: messages,
        appPackage: 'com.tencent.mm',
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyOption(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) MoeToast.success(context, '已复制，请自行粘贴发送');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('伙伴·回复参谋'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _PrivacyBanner(
                  onReadFromBall: Platform.isAndroid ? _readFromOverlay : null),
              if (_androidPetEnabled) ...[
                const SizedBox(height: MoeTokens.spaceMd),
                _AndroidControls(
                  a11yEnabled: _a11yEnabled,
                  overlayPermissionGranted: _overlayPermissionGranted,
                  overlayVisible: _overlayVisible,
                  focusGap: _focusGap,
                  onA11y: _onA11yChip,
                  onOverlayPerm: _onOverlayPermChip,
                  onPet: _onPetChip,
                  onRefresh: _refreshAndroidStatus,
                ),
              ],
              const SizedBox(height: MoeTokens.spaceMd),
              TextField(
                controller: _pasteController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '粘贴可见对话',
                  hintText: '把聊天页里最近几轮复制到这里（iOS / 降级路径）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('相册截图'),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                ],
              ),
              if (_pickedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                  child:
                      Image.file(_pickedImage!, height: 160, fit: BoxFit.cover),
                ),
                const SizedBox(height: MoeTokens.spaceSm),
              ],
              const SizedBox(height: MoeTokens.spaceMd),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _submit(
                        source: _pickedImage != null ? 'image' : 'paste'),
                child: const Text('生成判断与三条回复'),
              ),
              const SizedBox(height: MoeTokens.spaceLg),
              if (_error != null)
                MoeErrorState.fromError(_error,
                    onRetry: () => _submit(source: 'paste')),
              if (_result != null)
                _ResultPanel(result: _result!, onCopy: _copyOption),
            ],
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({this.onReadFromBall});

  final VoidCallback? onReadFromBall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '安心表达 · 只给草稿',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            '点按才读屏；不会代发消息；不会后台连续偷读。请自行复制后发送。',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          if (onReadFromBall != null) ...[
            const SizedBox(height: 8),
            TextButton(
                onPressed: onReadFromBall, child: const Text('用最近一次读屏生成（面板）')),
          ],
        ],
      ),
    );
  }
}

class _AndroidControls extends StatelessWidget {
  const _AndroidControls({
    required this.a11yEnabled,
    required this.overlayPermissionGranted,
    required this.overlayVisible,
    required this.focusGap,
    required this.onA11y,
    required this.onOverlayPerm,
    required this.onPet,
    required this.onRefresh,
  });

  final bool a11yEnabled;
  final bool overlayPermissionGranted;
  final bool overlayVisible;
  final ReplyAssistPermGap? focusGap;
  final VoidCallback onA11y;
  final VoidCallback onOverlayPerm;
  final VoidCallback onPet;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('贴纸桌宠（微信白名单 · 侧载内测）'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PermChip(
                label: '无障碍',
                ok: a11yEnabled,
                missingHint: true,
                highlighted: focusGap == ReplyAssistPermGap.accessibility,
                onTap: onA11y,
              ),
              _PermChip(
                label: '悬浮窗',
                ok: overlayPermissionGranted,
                missingHint: true,
                highlighted: focusGap == ReplyAssistPermGap.overlay,
                onTap: onOverlayPerm,
              ),
              _PermChip(
                label: overlayVisible ? '桌宠 开' : '桌宠 关',
                ok: overlayVisible,
                missingHint: false,
                highlighted: false,
                onTap: onPet,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRefresh, child: const Text('刷新状态')),
          ),
        ],
      ),
    );
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip({
    required this.label,
    required this.ok,
    required this.missingHint,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool ok;
  final bool missingHint;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needsAttention = missingHint && !ok;
    final border = needsAttention || highlighted
        ? MoeTokens.primary
        : MoeTokens.surfaceBorder;
    return MoePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: needsAttention
              ? MoeTokens.primary.withValues(alpha: 0.08)
              : MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: needsAttention ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: ok ? MoeTokens.success : MoeTokens.primary,
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
            if (needsAttention)
              const Text(
                ' · 去开启',
                style: TextStyle(fontSize: 12, color: MoeTokens.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.onCopy});

  final ReplyAssistSuggestResult result;
  final Future<void> Function(String text) onCopy;

  @override
  Widget build(BuildContext context) {
    final judge = result.judge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('判断摘要', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _JudgeCard(judge: judge),
        const SizedBox(height: MoeTokens.spaceLg),
        Text('候选回复（点按复制）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final opt in result.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MoePressable(
              onTap: () => onCopy(opt.text),
              borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MoeTokens.surface1,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                  border: Border.all(color: MoeTokens.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(opt.text),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _JudgeCard extends StatelessWidget {
  const _JudgeCard({required this.judge});

  final ReplyAssistJudgeSummary judge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('意图：${judge.intent}'),
          Text('情绪：${judge.emotion}'),
          Text('节奏：${judge.urgency}'),
          Text('建议姿态：${judge.replyStance}'),
          Text('要不要回：${judge.shouldReply}'),
          if (judge.uncertaintyNote.isNotEmpty)
            Text('不确定：${judge.uncertaintyNote}'),
          if (judge.riskHint.isNotEmpty) Text('提示：${judge.riskHint}'),
        ],
      ),
    );
  }
}
