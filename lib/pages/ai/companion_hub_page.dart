import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/feature_flags.dart';
import '../../models/post.dart';
import '../../pages/life/life_world_page.dart';
import '../../providers/companion_presence_provider.dart';
import '../../services/api_client.dart';
import '../../services/companion_character_card_import.dart';
import '../../services/companion_chat_launcher.dart';
import '../../services/companion_service.dart';
import '../../utils/post_navigation.dart';
import 'companion_hub_viewmodel.dart';
import 'ai_provider_profiles_page.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/companion_avatar.dart';
import '../../widgets/moe_error_state.dart';
import '../../widgets/moe_input_field.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import '../../utils/moe_error_copy.dart';
import '../../widgets/motion/moe_pressable.dart';
import '../../widgets/motion/moe_motion.dart';

/// AI 伙伴关系首页（产品叙事：长期陪伴；正式主路径入口）。
///
/// 决策 SSOT：`docs/dev/ai-companion-formal-decisions.md`（单活跃伙伴一期；酒馆退役向）。
class CompanionHubPage extends StatefulWidget {
  const CompanionHubPage({super.key});

  @override
  State<CompanionHubPage> createState() => _CompanionHubPageState();
}

class _CompanionHubPageState extends State<CompanionHubPage> {
  late final CompanionHubViewModel _hub;
  late final CompanionPresenceProvider _presence;
  bool _isChatLoading = false;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _hub = CompanionHubViewModel();
    _hub.addListener(_onHubChanged);
    _presence = CompanionPresenceProvider.instance;
    _presence.addListener(_onPresenceChanged);
    _presence.setViewingCompanion(true);
    unawaited(_hub.loadDashboard());
  }

  void _onHubChanged() {
    if (mounted) setState(() {});
  }

  void _onPresenceChanged() {
    _hub.applyLivePresence(
      greeting: _presence.greeting,
      moodThought: _presence.moodThought,
      activityLabel: _presence.activityLabel,
    );
  }

  @override
  void dispose() {
    _presence.removeListener(_onPresenceChanged);
    _hub.removeListener(_onHubChanged);
    _hub.dispose();
    super.dispose();
  }

  Future<void> _openChat({String? draft}) async {
    if (_isChatLoading) return;
    setState(() => _isChatLoading = true);
    try {
      await CompanionChatLauncher.openChat(context, draft: draft);
      if (mounted) {
        unawaited(_presence.markCompanionChatSeen());
        unawaited(_hub.loadDashboard());
      }
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  Future<void> _openDailyItem(CompanionDailyItem item) async {
    switch (item.kind) {
      case 'chat':
        await _openChat();
        return;
      case 'topic':
        final topic = item.fullBody?.trim().isNotEmpty == true
            ? item.fullBody!.trim()
            : item.body.trim();
        await _openChat(draft: '我们接着聊聊这件事：$topic');
        return;
      case 'world':
      case 'moment':
        await _openLifeWorld();
        return;
      case 'memory':
        await _openMemories(focusMemoryId: item.memoryId);
        return;
      case 'post':
        await _openDailyPost(item);
        return;
      default:
        return;
    }
  }

  Future<void> _openMemories({int? focusMemoryId}) async {
    await Navigator.of(context).pushNamed(
      '/ai-memories',
      arguments: <String, Object?>{
        if (focusMemoryId != null && focusMemoryId > 0)
          'focusMemoryId': focusMemoryId,
      },
    );
    if (mounted) unawaited(_hub.loadDashboard());
  }

  Future<void> _openDailyPost(CompanionDailyItem item) async {
    final id = item.postId?.trim() ?? '';
    if (id.isEmpty) {
      MoeToast.info(context, '这条动态暂时打不开');
      return;
    }
    final stub = Post(
      id: id,
      userId: '',
      userName: _hub.profile.name.trim().isNotEmpty
          ? _hub.profile.name.trim()
          : 'AI 伙伴',
      userAvatar: '',
      content: item.body,
      createdAt: item.at ?? DateTime.now(),
    );
    await openPostDetail(context, stub);
    if (mounted) unawaited(_hub.loadDashboard());
  }

  Future<void> _openLifeWorld() async {
    if (!FeatureFlags.showLifeEngine) {
      MoeToast.info(context, '数字生命暂未开放');
      return;
    }
    final focusId = _hub.profile.lifeEntityId;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LifeWorldPage(
          focusEntityId: focusId > 0 ? focusId : null,
        ),
      ),
    );
    if (mounted) unawaited(_hub.loadDashboard());
  }

  Future<void> _openPetHome() async {
    await Navigator.of(context).pushNamed('/pet/home');
  }

  Future<void> _openProviderSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AiProviderProfilesPage(),
      ),
    );
  }

  // Kept temporarily for a backward-compatible internal entry point.
  // ignore: unused_element
  Future<void> _openCompanionTools() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AiBrandTokens.pageBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '伙伴工具',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AiBrandTokens.titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.psychology_alt_rounded),
                    title: const Text('TA 记得的事'),
                    subtitle: const Text('查看和管理你们共同留下的记忆'),
                    onTap: () => Navigator.pop(sheetContext, 'memories'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: const Text('编辑伙伴资料'),
                    subtitle: const Text('调整名字、性格和陪伴方式'),
                    onTap: () => Navigator.pop(sheetContext, 'profile'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('模型服务配置'),
                    subtitle: const Text('选择模型和服务提供方'),
                    onTap: () => Navigator.pop(sheetContext, 'provider'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('刷新近况'),
                    subtitle: const Text('重新加载伙伴状态和今日摘要'),
                    onTap: () => Navigator.pop(sheetContext, 'refresh'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('主动陪伴设置'),
                    subtitle: const Text('控制主动消息、免打扰时间和时区'),
                    onTap: () => Navigator.pop(sheetContext, 'proactive'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'memories':
        unawaited(_openMemories());
      case 'profile':
        if (!_isSavingProfile) unawaited(_editProfile());
      case 'provider':
        unawaited(_openProviderSettings());
      case 'refresh':
        if (!_hub.isLoading) unawaited(_hub.loadDashboard());
      case 'proactive':
        unawaited(Navigator.of(context).pushNamed('/companion-settings'));
    }
  }

  Future<void> _editProfile() async {
    final saved = await _showProfileEditor();
    if (saved == null) return;
    if (!mounted) return;

    setState(() => _isSavingProfile = true);
    try {
      await _hub.applyUpdatedProfile(saved);
      if (!mounted) return;
      MoeToast.success(context, '伙伴资料已更新');
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<CompanionProfileData?> _showProfileEditor() async {
    final current = _hub.profile;
    final nameController = TextEditingController(text: current.name);
    final emojiController = TextEditingController(text: current.emoji);
    final personaController = TextEditingController(text: current.persona);
    final agentIdController = TextEditingController(text: current.agentId);
    final traitsController = TextEditingController(
      text: current.personalityTraits.join('，'),
    );
    final systemPromptController = TextEditingController(
      text: current.systemPromptOverride,
    );
    var greetingStyle =
        current.greetingStyle.isNotEmpty ? current.greetingStyle : 'warm';
    var avatarUrl = current.avatarUrl;
    var uploadingAvatar = false;

    try {
      return await showModalBottomSheet<CompanionProfileData>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> pickAvatar() async {
                if (uploadingAvatar) return;
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 88,
                );
                if (picked == null) return;
                setSheetState(() => uploadingAvatar = true);
                try {
                  final url = await ApiClient.uploadImage(File(picked.path));
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    avatarUrl = url;
                    uploadingAvatar = false;
                  });
                } catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(() => uploadingAvatar = false);
                    MoeToast.error(
                      sheetContext,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              }

              Future<void> applyCardDraft(
                CompanionCardImportDraft draft,
              ) async {
                nameController.text = draft.name;
                if (draft.persona.isNotEmpty) {
                  personaController.text = draft.persona;
                }
                if (draft.personalityTraits.isNotEmpty) {
                  traitsController.text = draft.personalityTraits.join('，');
                }
                if (draft.systemPromptOverride.isNotEmpty) {
                  systemPromptController.text = draft.systemPromptOverride;
                }
                setSheetState(() {});

                final png = draft.avatarPngBytes;
                if (png != null && png.isNotEmpty) {
                  setSheetState(() => uploadingAvatar = true);
                  try {
                    final url = await ApiClient.uploadImageBytes(
                      png,
                      filename: 'character_card.png',
                    );
                    if (!sheetContext.mounted) return;
                    setSheetState(() {
                      avatarUrl = url;
                      uploadingAvatar = false;
                    });
                  } catch (e) {
                    if (sheetContext.mounted) {
                      setSheetState(() => uploadingAvatar = false);
                      MoeToast.error(
                        sheetContext,
                        '人设已填入，但头像上传失败：'
                        '${e.toString().replaceFirst('Exception: ', '')}',
                      );
                    }
                    return;
                  }
                }

                if (!sheetContext.mounted) return;
                MoeToast.success(
                  sheetContext,
                  '已从${draft.sourceLabel}填入，确认后点保存',
                );
              }

              Future<void> importFromFile() async {
                try {
                  final draft =
                      await CompanionCharacterCardImport.fromFilePicker();
                  if (!sheetContext.mounted) return;
                  await applyCardDraft(draft);
                } on CompanionCardImportCancelled {
                  return;
                } catch (e) {
                  if (sheetContext.mounted) {
                    MoeToast.error(
                      sheetContext,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              }

              Future<void> importFromPaste() async {
                final pasteController = TextEditingController();
                final raw = await showDialog<String>(
                  context: sheetContext,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('粘贴角色卡 JSON'),
                      content: MoeInputField(
                        controller: pasteController,
                        hintText: '粘贴 SillyTavern / Moe 角色卡 JSON',
                        maxLines: 10,
                        textInputAction: TextInputAction.newline,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            pasteController.text,
                          ),
                          child: const Text('解析'),
                        ),
                      ],
                    );
                  },
                );
                pasteController.dispose();
                if (raw == null || !sheetContext.mounted) return;
                try {
                  final draft =
                      CompanionCharacterCardImport.fromJsonString(raw);
                  await applyCardDraft(draft);
                } catch (e) {
                  if (sheetContext.mounted) {
                    MoeToast.error(
                      sheetContext,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              }

              Future<void> showImportPicker() async {
                final action = await showModalBottomSheet<String>(
                  context: sheetContext,
                  backgroundColor: AiBrandTokens.pageBackground,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '从角色卡导入',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AiBrandTokens.titleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '仅写入名字 / 人设 / 性格 / 提示词；不导入世界书，不创建酒馆角色。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              leading: const Icon(Icons.folder_open_rounded),
                              title: const Text('选择 JSON / PNG 文件'),
                              onTap: () => Navigator.pop(ctx, 'file'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.content_paste_rounded),
                              title: const Text('粘贴 JSON'),
                              onTap: () => Navigator.pop(ctx, 'paste'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                if (!sheetContext.mounted || action == null) return;
                if (action == 'file') {
                  await importFromFile();
                } else if (action == 'paste') {
                  await importFromPaste();
                }
              }

              return SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AiBrandTokens.pageBackground,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '自定义我的 TA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AiBrandTokens.titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '名字、头像、人设属于关系层；世界居民绑定不会覆盖这里。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: uploadingAvatar ? null : showImportPicker,
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('从角色卡导入'),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Column(
                            children: [
                              CompanionAvatar(
                                emoji: emojiController.text,
                                avatarUrl: avatarUrl,
                                size: 88,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed:
                                        uploadingAvatar ? null : pickAvatar,
                                    icon: uploadingAvatar
                                        ? const MoeSmallLoading(size: 14)
                                        : const Icon(Icons.photo_rounded),
                                    label: Text(
                                      uploadingAvatar ? '上传中…' : '上传头像',
                                    ),
                                  ),
                                  if (avatarUrl.trim().isNotEmpty)
                                    TextButton(
                                      onPressed: uploadingAvatar
                                          ? null
                                          : () => setSheetState(
                                                () => avatarUrl = '',
                                              ),
                                      child: const Text('清除头像'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: nameController,
                          label: '名称',
                          hint: '例如：阿悠',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: emojiController,
                          label: '表情（无头像时显示）',
                          hint: '例如：🐾',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: personaController,
                          label: '人设',
                          hint: '一句话描述 AI 的角色和气质',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: agentIdController,
                          label: 'Agent ID',
                          hint: '对接 OpenClaw / 后端 AI 的账号标识',
                          maxLength: 64,
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: traitsController,
                          label: '性格标签',
                          hint: '用逗号分隔，例如：温暖, 好奇, 幽默',
                        ),
                        const SizedBox(height: 12),
                        _ProfileField(
                          controller: systemPromptController,
                          label: '系统提示词覆盖',
                          hint: '可选，留空则使用默认设置',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: greetingStyle,
                          decoration: _profileFieldDecoration('问候风格'),
                          items: const [
                            DropdownMenuItem(value: 'warm', child: Text('温暖')),
                            DropdownMenuItem(
                                value: 'playful', child: Text('俏皮')),
                            DropdownMenuItem(value: 'calm', child: Text('沉静')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => greetingStyle = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: uploadingAvatar
                              ? null
                              : () {
                                  final traits = traitsController.text
                                      .split(RegExp(r'[，,;\n]'))
                                      .map((item) => item.trim())
                                      .where((item) => item.isNotEmpty)
                                      .toList(growable: false);
                                  Navigator.pop(
                                    sheetContext,
                                    current.copyWith(
                                      name: nameController.text.trim(),
                                      emoji: emojiController.text.trim().isEmpty
                                          ? '🐾'
                                          : emojiController.text.trim(),
                                      avatarUrl: avatarUrl.trim(),
                                      persona: personaController.text.trim(),
                                      agentId: agentIdController.text.trim(),
                                      personalityTraits: traits,
                                      greetingStyle: greetingStyle,
                                      systemPromptOverride:
                                          systemPromptController.text.trim(),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('保存'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AiBrandTokens.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      // BottomSheet returns before its exit animation has fully detached TextField dependents.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      nameController.dispose();
      emojiController.dispose();
      personaController.dispose();
      agentIdController.dispose();
      traitsController.dispose();
      systemPromptController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiBrandTokens.pageBackground,
      appBar: AppBar(
        title: const Text('AI伙伴'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AiBrandTokens.titleColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_hub.loadError != null)
            MoeErrorState.fromError(
              _hub.loadError,
              scene: MoeErrorScene.generic,
              onRetry: _hub.loadDashboard,
            )
          else if (_hub.isLoading)
            const Center(child: MoeLoading())
          else
            RefreshIndicator(
              onRefresh: _hub.loadDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Builder(
                    builder: (context) {
                      final hasAttention = context
                          .watch<CompanionPresenceProvider>()
                          .hasAttention;
                      final pulse = CompanionHubViewModel.buildPulseData(
                        profile: _hub.profile,
                        state: _hub.state,
                        dailyItems: _hub.dailyItems,
                        hasAttention: hasAttention,
                      );

                      return _HeroCard(
                        profile: _hub.profile,
                        state: _hub.state,
                        pulse: pulse,
                        hasAttention: hasAttention,
                        onChat: _openChat,
                        onCustomize: _isSavingProfile ? null : _editProfile,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _CompanionQuickActions(
                    onChat: _openChat,
                    onMemories: () => _openMemories(),
                    onLife: FeatureFlags.showLifeEngine ? _openLifeWorld : null,
                  ),
                  if (FeatureFlags.showLifeEngine) ...[
                    const SizedBox(height: 14),
                    _WorldStrip(
                      summaryLine: _hub.worldSummaryLine.isNotEmpty
                          ? _hub.worldSummaryLine
                          : '打开 2D 小世界，看看居民在做什么',
                      bound: _hub.worldBound,
                      bindMissing: _hub.worldBindMissing,
                      onOpen: _openLifeWorld,
                    ),
                    if (_hub.worldBindMissing) ...[
                      const SizedBox(height: 10),
                      _BindMissingBanner(onOpenWorld: _openLifeWorld),
                    ],
                  ],
                  if (FeatureFlags.petLifeSim) ...[
                    const SizedBox(height: 14),
                    _PetHomeStrip(onOpen: _openPetHome),
                  ],
                  if (_hub.dailySummary != null) ...[
                    const SizedBox(height: 16),
                    _DailySummaryCard(summary: _hub.dailySummary!),
                  ],
                  const SizedBox(height: 16),
                  _DailyFeedCard(
                    items: _hub.dailyItems,
                    onOpenItem: _openDailyItem,
                  ),
                ],
              ),
            ),
          if (_isChatLoading || _isSavingProfile)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22FFFFFF),
                child: Center(child: MoeLoading()),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.state,
    required this.pulse,
    required this.hasAttention,
    required this.onChat,
    this.onCustomize,
  });

  final CompanionProfileData profile;
  final CompanionStateData state;
  final CompanionPulseData pulse;
  final bool hasAttention;
  final VoidCallback onChat;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final name = profile.name.trim().isNotEmpty ? profile.name.trim() : 'AI 伙伴';
    final hasPersona = profile.persona.trim().isNotEmpty;
    final persona = hasPersona ? profile.persona.trim() : '会长期陪着你、慢慢懂你的虚拟伙伴。';

    final isAttention = pulse.kind == 'attention';
    final reduceMotion = moeReduceMotion(context);
    return AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFE7FF), Color(0xFFFBE8F0), Color(0xFFF8F3E7)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAttention
              ? const Color(0xFFFFB2C1)
              : Colors.white.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color:
                isAttention ? const Color(0x33E97891) : const Color(0x1A8A2387),
            blurRadius: isAttention ? 30 : 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanionAvatar(
                emoji: profile.emoji,
                avatarUrl: profile.avatarUrl,
                size: 58,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AiBrandTokens.titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      persona,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Color(0xFF5D4E6E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(99),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF51B982),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '在这里',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AiBrandTokens.companionInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!hasPersona && onCustomize != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onCustomize,
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('完善人设或从角色卡导入'),
              style: TextButton.styleFrom(
                foregroundColor: AiBrandTokens.primary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _CompanionSummaryBlock(
            pulse: pulse,
            profile: profile,
            state: state,
          ),
          const SizedBox(height: 10),
          MoePressable(
            onTap: onChat,
            borderRadius: BorderRadius.circular(15),
            child: Semantics(
              button: true,
              label: '开始聊天',
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: AiBrandTokens.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      hasAttention ? '回复 TA' : '开始聊天',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CompanionMessageCard extends StatelessWidget {
  const _CompanionMessageCard({
    required this.name,
    required this.message,
    required this.reason,
  });

  final String name;
  final String message;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final companionName = name.trim().isEmpty ? 'TA' : name.trim();
    final content = message.trim().isEmpty
        ? '$companionName 留下了一句话，正在等你回来。'
        : message.trim();
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$companionName 想和你说：$content',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFC8D4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: Color(0xFFE97891),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$companionName 想和你说',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AiBrandTokens.titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF5D4E6E),
                    ),
                  ),
                  if (reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      reason.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB86A7C),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionSummaryBlock extends StatelessWidget {
  const _CompanionSummaryBlock({
    required this.pulse,
    required this.profile,
    required this.state,
  });

  final CompanionPulseData pulse;
  final CompanionProfileData profile;
  final CompanionStateData state;

  @override
  Widget build(BuildContext context) {
    final isAttention = pulse.kind == 'attention';
    final accent =
        isAttention ? const Color(0xFFE97891) : AiBrandTokens.primary;
    final stage = profile.relationshipStageLabel;
    final progress = profile.relationshipProgress;
    final progressLabel = profile.relationshipProgressLabel;
    IconData icon = Icons.auto_awesome_rounded;
    if (pulse.kind == 'attention') {
      icon = Icons.favorite_rounded;
    } else if (pulse.kind == 'memory') {
      icon = Icons.psychology_alt_rounded;
    } else if (pulse.kind == 'world' || pulse.kind == 'moment') {
      icon = Icons.public_rounded;
    } else if (pulse.kind == 'post') {
      icon = Icons.article_rounded;
    } else if (pulse.kind == 'chat') {
      icon = Icons.chat_bubble_rounded;
    }

    final reduceMotion = moeReduceMotion(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pulse.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AiBrandTokens.titleColor,
                        ),
                      ),
                    ),
                    Text(
                      stage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  child: Align(
                    key: ValueKey(pulse.body),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      pulse.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: const Color(0xFFF2E9F4),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE97891),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  state.activityLabel.trim().isNotEmpty
                      ? '$progressLabel · ${state.activityLabel.trim()}'
                      : '$progressLabel · 关系在持续生长中',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionQuickActions extends StatelessWidget {
  const _CompanionQuickActions({
    required this.onChat,
    required this.onMemories,
    this.onLife,
  });

  final VoidCallback onChat;
  final VoidCallback onMemories;
  final VoidCallback? onLife;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: '继续聊天',
            tint: AiBrandTokens.primary,
            onTap: onChat,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.psychology_alt_rounded,
            label: '记忆',
            tint: const Color(0xFF8A62B8),
            onTap: onMemories,
          ),
        ),
        if (onLife != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAction(
              icon: Icons.public_rounded,
              label: 'Life 世界',
              tint: const Color(0xFF4C9A82),
              onTap: onLife!,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: tint.withValues(alpha: 0.16)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldStrip extends StatelessWidget {
  const _WorldStrip({
    required this.summaryLine,
    required this.onOpen,
    this.bound = false,
    this.bindMissing = false,
  });

  final String summaryLine;
  final VoidCallback onOpen;
  final bool bound;
  final bool bindMissing;

  @override
  Widget build(BuildContext context) {
    final title = !bound
        ? 'TA 的世界 · 未绑定'
        : (bindMissing ? 'TA 的世界 · 绑定异常' : 'TA 的世界 · 已绑定');
    final accent = !bound
        ? const Color(0xFFE2A54A)
        : (bindMissing ? const Color(0xFFE97891) : AiBrandTokens.primary);
    final border = !bound
        ? const Color(0xFFFFD89C)
        : (bindMissing ? const Color(0xFFF5C0CB) : const Color(0xFFE8E0F2));
    final icon = !bound
        ? Icons.link_off_rounded
        : (bindMissing ? Icons.warning_amber_rounded : Icons.public_rounded);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summaryLine.isNotEmpty
                          ? summaryLine
                          : (bound ? '点进世界看看 TA' : '进世界选一位居民设为伙伴'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AiBrandTokens.titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0A4C0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetHomeStrip extends StatelessWidget {
  const _PetHomeStrip({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD6E0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.home_rounded, color: Color(0xFFE97891), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TA 的小家',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE97891),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '喂食、装扮、上学打工与轻冒险',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AiBrandTokens.titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFB0A4C0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BindMissingBanner extends StatelessWidget {
  const _BindMissingBanner({required this.onOpenWorld});

  final VoidCallback onOpenWorld;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF1F4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpenWorld,
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: Color(0xFFE97891)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '绑定没有丢，但居民暂时不在舞台上。点这里进世界改绑或看看近况。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF6B4A52),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyFeedCard extends StatelessWidget {
  const _DailyFeedCard({
    required this.items,
    required this.onOpenItem,
  });

  final List<CompanionDailyItem> items;
  final Future<void> Function(CompanionDailyItem item) onOpenItem;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'TA 的日常',
      icon: Icons.auto_stories_rounded,
      emptyText: '还没有日常动态，聊聊或去世界看看吧',
      child: items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: items
                  .map(
                    (item) => _DailyTile(
                      item: item,
                      onTap: () => unawaited(onOpenItem(item)),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.summary});

  final CompanionDailySummaryData summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AiBrandTokens.companionSurface, Color(0xFFFFF2F5)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AiBrandTokens.companionBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F8A2387),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3D8),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 19,
              color: Color(0xFFE97891),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AiBrandTokens.titleColor,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AiBrandTokens.companionGlow,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    summary.sceneLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFE97891),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  summary.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF6B5962),
                  ),
                ),
                if (summary.continuationHint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '可以继续：${summary.continuationHint}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFFE97891),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({
    required this.item,
    this.onTap,
  });

  final CompanionDailyItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _dailyKindMeta(item.kind);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: meta.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(meta.icon, size: 18, color: AiBrandTokens.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.grey.shade400),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null
          ? row
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: row,
                ),
              ),
            ),
    );
  }
}

({IconData icon, Color bg}) _dailyKindMeta(String kind) {
  switch (kind) {
    case 'world':
    case 'moment':
      return (icon: Icons.pets_rounded, bg: const Color(0xFFFFF1D6));
    case 'chat':
      return (
        icon: Icons.chat_bubble_outline_rounded,
        bg: const Color(0xFFE8F4FF)
      );
    case 'topic':
      return (icon: Icons.forum_outlined, bg: const Color(0xFFE8F4FF));
    case 'memory':
      return (icon: Icons.psychology_alt_rounded, bg: const Color(0xFFF3E8FF));
    case 'relationship':
      return (icon: Icons.favorite_rounded, bg: const Color(0xFFFFE8EE));
    case 'post':
    default:
      return (icon: Icons.article_outlined, bg: const Color(0xFFEFE7FF));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasContent = child is Column && (child as Column).children.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AiBrandTokens.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AiBrandTokens.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasContent)
            child
          else
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: _profileFieldDecoration(label).copyWith(hintText: hint),
    );
  }
}

InputDecoration _profileFieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AiBrandTokens.primary),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}
