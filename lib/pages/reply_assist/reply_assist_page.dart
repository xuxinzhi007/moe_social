import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/feature_flags.dart';
import '../../models/reply_assist_models.dart';
import '../../services/reply_assist_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';

/// Android 读屏 + 全平台粘贴/截图输入；只复制、不代发。
class ReplyAssistPage extends StatefulWidget {
  const ReplyAssistPage({super.key});

  @override
  State<ReplyAssistPage> createState() => _ReplyAssistPageState();
}

class _ReplyAssistPageState extends State<ReplyAssistPage> {
  static const _channel = MethodChannel('com.moe_social/reply_assist');

  final ReplyAssistService _service = ReplyAssistService();
  final TextEditingController _pasteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  ReplyAssistSuggestResult? _result;
  Object? _error;
  bool _loading = false;
  File? _pickedImage;
  String? _uploadedImageUrl;
  bool _a11yEnabled = false;
  bool _overlayVisible = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid && FeatureFlags.replyAssistPrototype) {
      unawaited(_refreshAndroidStatus());
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _refreshAndroidStatus() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      final overlay = await _channel.invokeMethod<bool>('isOverlayVisible');
      if (!mounted) return;
      setState(() {
        _a11yEnabled = enabled ?? false;
        _overlayVisible = overlay ?? false;
      });
    } catch (_) {
      // 非 Android 或未注册插件时忽略。
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
  }

  Future<void> _toggleOverlay() async {
    try {
      final next = await _channel.invokeMethod<bool>('toggleOverlay');
      if (!mounted) return;
      setState(() => _overlayVisible = next ?? false);
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
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
      final raw = await _channel.invokeMethod<Map>('readWeChatSnapshot');
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
        title: const Text('回复参谋'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _PrivacyBanner(
                  onReadFromBall: Platform.isAndroid ? _readFromOverlay : null),
              if (Platform.isAndroid && FeatureFlags.replyAssistPrototype) ...[
                const SizedBox(height: MoeTokens.spaceMd),
                _AndroidControls(
                  a11yEnabled: _a11yEnabled,
                  overlayVisible: _overlayVisible,
                  onOpenSettings: _openAccessibilitySettings,
                  onToggleOverlay: _toggleOverlay,
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
    required this.overlayVisible,
    required this.onOpenSettings,
    required this.onToggleOverlay,
    required this.onRefresh,
  });

  final bool a11yEnabled;
  final bool overlayVisible;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleOverlay;
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
          Text('Android 读屏（微信白名单 · 侧载内测）'),
          const SizedBox(height: 8),
          Text('无障碍：${a11yEnabled ? "已开启" : "未开启"}'),
          Text('贴纸桌宠：${overlayVisible ? "显示中" : "已收起"}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                  onPressed: onOpenSettings, child: const Text('开启无障碍')),
              OutlinedButton(
                  onPressed: onToggleOverlay,
                  child: Text(overlayVisible ? '收起桌宠' : '显示桌宠')),
              TextButton(onPressed: onRefresh, child: const Text('刷新状态')),
            ],
          ),
        ],
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
