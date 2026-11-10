import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/feature_flags.dart';
import '../../models/ai_provider_profile.dart';
import '../../models/reply_assist_models.dart';
import '../../pages/ai/ai_provider_profiles_page.dart';
import '../../services/ai_cloud_config_service.dart';
import '../../services/ai_provider_service.dart';
import '../../services/chat_model_selection.dart';
import '../../services/llm_api_service.dart';
import '../../services/reply_assist_overlay_bridge.dart';
import '../../services/reply_assist_service.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/ai/chat_model_picker.dart';
import '../../widgets/moe_button.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_sheet.dart';
import 'reply_assist_permission.dart';

/// 仅本页使用，与桌宠悬浮层暖纸贴纸对齐，不改全局主题。
class _ReplyAssistLook {
  static const paper = Color(0xFFFBF6EE);
  static const card = Color(0xFFFFFCF8);
  static const ink = Color(0xFF5A4A4A);
  static const stroke = Color(0xFFE8E0D4);
  static const hint = Color(0xFF8A7E74);
}

/// Android 读屏 + 全平台粘贴/截图输入；只复制、不代发。
class ReplyAssistPage extends StatefulWidget {
  const ReplyAssistPage({super.key});

  @override
  State<ReplyAssistPage> createState() => _ReplyAssistPageState();
}

class _ReplyAssistPageState extends State<ReplyAssistPage>
    with WidgetsBindingObserver {
  static const _introPref = 'reply_assist_pet_intro_seen';
  static const _adultIntimatePref = 'reply_assist_adult_intimate';

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
  bool _adultIntimate = false;
  bool _modelLoading = true;
  String _builtinChatModel = '';
  ChatModelSelectionDisplay? _modelDisplay;

  bool get _androidPetEnabled =>
      Platform.isAndroid && FeatureFlags.replyAssistPrototype;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAdultIntimate());
    unawaited(_loadChatModelSelection());
    WidgetsBinding.instance.addObserver(this);
    if (_androidPetEnabled) {
      unawaited(_refreshAndroidStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pasteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_loadChatModelSelection());
    if (_androidPetEnabled) {
      unawaited(_refreshAndroidStatus());
    }
  }

  Future<void> _loadAdultIntimate() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_adultIntimatePref) ?? false;
    if (enabled) {
      await ReplyAssistOverlayBridge.setAdultMode(true);
    }
    if (!mounted) return;
    setState(() => _adultIntimate = enabled);
  }

  Future<void> _loadChatModelSelection() async {
    String? builtin;
    String? serverDefault;
    AiProviderProfile? customProvider;
    try {
      final snapshot = await AiCloudConfigService().fetch();
      builtin = ChatModelSelection.builtinModelFromPreferences(
        snapshot?.preferences,
      );
    } catch (_) {}
    try {
      final selection = await AiProviderService().resolveActiveProvider();
      if (!selection.profile.isBuiltinBackend) {
        customProvider = selection.profile;
      }
    } catch (_) {}
    try {
      final config = await LlmApiService.getConfig();
      serverDefault = ChatModelSelection.serverDefaultFromConfig(config);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _modelLoading = false;
      _builtinChatModel = builtin ?? '';
      _modelDisplay = ChatModelSelection.resolve(
        activeProvider: customProvider,
        builtinChatModel: builtin,
        serverDefaultModel: serverDefault,
      );
    });
  }

  Future<void> _pickChatModel() async {
    final selected = await ChatModelPicker.pickAndSave(
      context: context,
      currentModel: _builtinChatModel,
    );
    if (selected == null || !mounted) return;
    final usingCustom = _modelDisplay?.usesCustomProvider == true;
    final source = usingCustom ? _modelDisplay!.title : selected;
    await _loadChatModelSelection();
    if (!mounted) return;
    if (usingCustom) {
      MoeToast.success(
        context,
        '已记下 $selected。当前仍走来源模型 $source，改回来源后才会用它。',
      );
    } else {
      MoeToast.success(context, '已切换到 $selected');
    }
  }

  Future<void> _openProviderSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AiProviderProfilesPage(),
      ),
    );
    if (mounted) unawaited(_loadChatModelSelection());
  }

  Future<void> _onAdultIntimateChanged(bool enabled) async {
    if (enabled) {
      final confirmed = await _confirmAdultIntimate();
      if (!confirmed || !mounted) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adultIntimatePref, enabled);
    await ReplyAssistOverlayBridge.setAdultMode(enabled);
    if (!mounted) return;
    setState(() => _adultIntimate = enabled);
  }

  Future<bool> _confirmAdultIntimate() async {
    if (!mounted) return false;
    final go = await MoeSheet.show<bool>(
      context,
      backgroundColor: _ReplyAssistLook.card,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '开启「成人向 / 亲密对话」',
                style: TextStyle(
                  fontSize: MoeTokens.textMd,
                  fontWeight: FontWeight.w700,
                  color: _ReplyAssistLook.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '打开后，草稿会按对话本身的语气来写，包括亲密和 18+ 内容，不会再降调、回避或改成疏导。\n\n'
                '用法还是只复制、不代发。请确认是你本人要打开。',
                style: TextStyle(
                  fontSize: MoeTokens.textBase,
                  height: 1.5,
                  color: _ReplyAssistLook.ink,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MoeSecondaryButton(
                      label: '取消',
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MoePrimaryButton(
                      label: '确认开启',
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return go == true;
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
    MoeToast.info(context, '悬浮窗用于贴纸桌宠，不挡当前聊天正常操作');
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
    final go = await MoeSheet.show<bool>(
      context,
      backgroundColor: _ReplyAssistLook.card,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '伙伴·回复参谋',
                style: TextStyle(
                  fontSize: MoeTokens.textMd,
                  fontWeight: FontWeight.w700,
                  color: _ReplyAssistLook.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '会在常见聊天软件旁显示贴纸小脸：点一下读取当前可见聊天，给出三条草稿。只复制、不代发。\n\n'
                '需要无障碍（只读）和悬浮窗。',
                style: TextStyle(
                  fontSize: MoeTokens.textBase,
                  height: 1.5,
                  color: _ReplyAssistLook.ink,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MoeSecondaryButton(
                      label: '取消',
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MoePrimaryButton(
                      label: '显示桌宠',
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        adultIntimate: _adultIntimate,
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
          .invokeMethod<Map>('readForegroundSnapshot');
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
        appPackage: map['app_package']?.toString() ?? '',
        adultIntimate: _adultIntimate,
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
      backgroundColor: _ReplyAssistLook.paper,
      appBar: AppBar(
        title: const Text('伙伴·回复参谋'),
        centerTitle: true,
        backgroundColor: _ReplyAssistLook.paper,
        foregroundColor: _ReplyAssistLook.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
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
              const Text(
                '粘贴可见对话',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _ReplyAssistLook.ink,
                ),
              ),
              const SizedBox(height: 8),
              MoeInputField(
                controller: _pasteController,
                hintText: '把聊天页里最近几轮复制到这里（iOS / 降级路径）',
                minLines: 4,
                maxLines: 8,
                fillColor: _ReplyAssistLook.card,
                primaryColor: MoeTokens.primary,
              ),
              const SizedBox(height: MoeTokens.spaceSm),
              Row(
                children: [
                  MoeSecondaryButton(
                    label: '相册截图',
                    icon: Icons.photo_outlined,
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(width: 8),
                  MoeSecondaryButton(
                    label: '拍照',
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => _pickImage(ImageSource.camera),
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
              _AdultIntimateSwitch(
                enabled: _adultIntimate,
                onChanged: _loading ? null : _onAdultIntimateChanged,
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              _ChatModelCard(
                loading: _modelLoading,
                display: _modelDisplay,
                onSwitchModel:
                    _loading ? null : () => unawaited(_pickChatModel()),
                onChangeProvider: !_modelLoading &&
                        _modelDisplay?.usesCustomProvider == true &&
                        !_loading
                    ? () => unawaited(_openProviderSettings())
                    : null,
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              MoePrimaryButton(
                label: '生成判断与三条回复',
                isLoading: _loading,
                onPressed: _loading
                    ? null
                    : () => _submit(
                        source: _pickedImage != null ? 'image' : 'paste'),
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
                color: Color(0x99FBF6EE),
                child: Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdultIntimateSwitch extends StatelessWidget {
  const _AdultIntimateSwitch({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _ReplyAssistLook.card,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: _ReplyAssistLook.stroke),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '成人向 / 亲密对话',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ReplyAssistLook.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '默认关闭，按稳妥来写。打开前会再确认一次；打开后按对方实际语气，包括 18+。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _ReplyAssistLook.hint,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: MoeTokens.primary,
          ),
        ],
      ),
    );
  }
}

class _ChatModelCard extends StatelessWidget {
  const _ChatModelCard({
    required this.loading,
    required this.display,
    required this.onSwitchModel,
    this.onChangeProvider,
  });

  final bool loading;
  final ChatModelSelectionDisplay? display;
  final VoidCallback? onSwitchModel;
  final VoidCallback? onChangeProvider;

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? '正在读取当前模型'
        : (display?.title ?? ChatModelSelection.unsetFallbackLabel);
    final subtitle = loading
        ? ChatModelSelection.sharedWithCompanionHint
        : (display?.subtitle ?? ChatModelSelection.sharedWithCompanionHint);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: _ReplyAssistLook.card,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: _ReplyAssistLook.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoePressable(
            onTap: onSwitchModel,
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '当前模型',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ReplyAssistLook.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: onSwitchModel == null
                      ? _ReplyAssistLook.hint
                      : MoeTokens.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          MoePressable(
            onTap: onSwitchModel,
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: MoeTokens.textMd,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _ReplyAssistLook.hint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onChangeProvider != null) ...[
            const SizedBox(height: 10),
            MoeSecondaryButton(
              label: '更换模型来源',
              icon: Icons.tune_rounded,
              onPressed: onChangeProvider,
            ),
          ],
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
        color: _ReplyAssistLook.card,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: _ReplyAssistLook.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '安心表达 · 只给草稿',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _ReplyAssistLook.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '点按才读屏；不会代发消息；不会后台连续偷读。请自行复制后发送。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _ReplyAssistLook.hint,
            ),
          ),
          if (onReadFromBall != null) ...[
            const SizedBox(height: 8),
            MoeSecondaryButton(
              label: '用最近一次读屏生成（面板）',
              onPressed: onReadFromBall,
            ),
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
        color: _ReplyAssistLook.card,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: _ReplyAssistLook.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '贴纸桌宠（常见聊天软件 · 侧载内测）',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _ReplyAssistLook.ink,
            ),
          ),
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
            child: MoeSecondaryButton(
              label: '刷新状态',
              onPressed: onRefresh,
            ),
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
                  color: _ReplyAssistLook.card,
                  borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
                  border: Border.all(color: _ReplyAssistLook.stroke),
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
        color: _ReplyAssistLook.card,
        borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
        border: Border.all(color: _ReplyAssistLook.stroke),
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
