// Hallmark · layout: focused form panel · tone: airy-moe / warm guidance · scroll: bounded dialog scroll
// Self-critique: Philosophy 4 · Hierarchy 5 · Execution 4 · Specificity 4 · Restraint 4 · Variety 4

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_links.dart';
import '../../../providers/device_info_provider.dart';
import '../../../services/user_service.dart';
import '../../../services/update_service.dart';
import '../../../theme/moe_tokens.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/moe_glass_surface.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/motion/moe_pressable.dart';

class AboutModule extends StatelessWidget {
  const AboutModule({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceInfo = Provider.of<DeviceInfoProvider>(context);

    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: Icons.info_rounded,
          title: '软件版本',
          subtitle: '点击检查更新',
          color: MoeTokens.pastelTeal,
          onTap: () {
            UpdateService.checkUpdate(context, showNoUpdateToast: true);
          },
          trailing: Text(
            deviceInfo.versionDisplayLabel,
            style: const TextStyle(
              color: MoeTokens.inkMuted,
              fontSize: MoeTokens.textSm,
            ),
          ),
        ),
        MoeMenuItem(
          icon: Icons.language_rounded,
          title: '访问官网',
          subtitle: '了解 Moe Social 产品介绍与最新信息',
          color: MoeTokens.primary,
          onTap: () => unawaited(_openOfficialWebsite(context)),
        ),
        MoeMenuItem(
          icon: Icons.feedback_outlined,
          title: '意见反馈',
          subtitle: '问题描述与联系方式',
          color: MoeTokens.pastelPink,
          onTap: () => _showFeedbackDialog(context),
        ),
        MoeMenuItem(
          icon: Icons.description_rounded,
          title: '用户协议',
          subtitle: '使用条款摘要',
          color: MoeTokens.secondary,
          onTap: () => _showUserAgreementDialog(context),
        ),
      ],
    );
  }

  Future<void> _openOfficialWebsite(BuildContext context) async {
    final uri = Uri.tryParse(AppLinks.officialWebsite);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      MoeToast.error(context, '官网地址无效');
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        MoeToast.error(context, '无法打开官网，请稍后重试');
      }
    } catch (_) {
      if (context.mounted) {
        MoeToast.error(context, '无法打开官网，请稍后重试');
      }
    }
  }

  static const String _feedbackEmail = 'xuxinzhi19@gmail.com';

  static const String _userAgreementSummary =
      '欢迎使用 Moe Social。使用本应用即表示您知悉并同意下列要点：\n\n'
      '1. 账号与内容：请妥善保管账号信息；您发布的内容需合法合规，不得侵害他人权益。\n'
      '2. 隐私：我们会在必要范围内处理设备与网络信息以提供服务，详见「隐私设置」相关说明。\n'
      '3. 服务变更：功能可能随版本迭代调整；重要变更将通过应用内提示或公告告知。\n'
      '4. 责任限制：在适用法律允许范围内，对不可抗力或第三方原因导致的服务中断，我们将尽力协助但不承担超出法律要求的责任。\n\n'
      '若您不同意上述内容，请停止使用本应用。';

  void _showFeedbackDialog(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      barrierColor: MoeTokens.inkDark.withValues(alpha: 0.48),
      builder: (_) => _FeedbackDialog(hostContext: context),
    ));
  }

  void _showUserAgreementDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('用户协议（摘要）'),
        content: SingleChildScrollView(
          child: Text(
            _userAgreementSummary,
            style: const TextStyle(
              color: MoeTokens.bodyText,
              height: 1.45,
              fontSize: MoeTokens.textBase,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已了解'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.hostContext});

  final BuildContext hostContext;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  static const String _defaultCategory = '其他';
  static const int _maxDescriptionLength = 2000;
  static const double _dialogMaxWidth = 560;
  static const double _dialogMinHeight = MoeTokens.space4xl * 2;
  static const double _dialogHeightInset = MoeTokens.space2xl;
  static const double _dialogIconSize = MoeTokens.space3xl + MoeTokens.spaceLg;
  static const double _sectionIconSize = MoeTokens.spaceXl + MoeTokens.spaceSm;
  static const double _categoryTileHeight =
      MoeTokens.space4xl + MoeTokens.spaceLg;
  static const double _compactGridBreakpoint = 300;

  static const List<_FeedbackCategoryOption> _categories = [
    _FeedbackCategoryOption(
      label: '闪退崩溃',
      icon: Icons.flash_on_rounded,
      color: MoeTokens.danger,
    ),
    _FeedbackCategoryOption(
      label: '登录问题',
      icon: Icons.login_rounded,
      color: MoeTokens.secondary,
    ),
    _FeedbackCategoryOption(
      label: '功能异常',
      icon: Icons.build_circle_rounded,
      color: MoeTokens.warning,
    ),
    _FeedbackCategoryOption(
      label: '功能建议',
      icon: Icons.lightbulb_rounded,
      color: MoeTokens.primary,
    ),
    _FeedbackCategoryOption(
      label: '其他',
      icon: Icons.chat_bubble_rounded,
      color: MoeTokens.pastelPink,
    ),
  ];

  final TextEditingController _contentController = TextEditingController();
  final FocusNode _descriptionFocusNode = FocusNode();
  String _selectedCategory = _defaultCategory;
  int _characterCount = 0;
  bool _isSubmitting = false;
  bool _showContentError = false;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController
      ..removeListener(_onContentChanged)
      ..dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!mounted) return;
    setState(() {
      _characterCount = _contentController.text.length;
      _showContentError = false;
    });
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _showContentError = true);
      _descriptionFocusNode.requestFocus();
      if (widget.hostContext.mounted) {
        MoeToast.warning(widget.hostContext, '请先写下你想告诉我们的内容');
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await UserService.submitFeedback(
        email: AboutModule._feedbackEmail,
        category: _selectedCategory,
        content: content,
        source: 'app_feedback',
      );
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();
      if (widget.hostContext.mounted) {
        MoeToast.success(widget.hostContext, '反馈已提交');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      MoeToast.error(context, '提交失败，请检查网络后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        _dialogHeightInset;
    final maxHeight = availableHeight
        .clamp(_dialogMinHeight, mediaQuery.size.height)
        .toDouble();
    final radius = BorderRadius.circular(MoeTokens.radius2xl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: MoeTokens.spaceLg,
        vertical: MoeTokens.spaceLg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _dialogMaxWidth,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: MoeTokens.shadowElevated(),
          ),
          child: MoeGlassSurface(
            sigma: MoeTokens.blurHeavy,
            tint: MoeTokens.surface3.withValues(alpha: 0.94),
            borderRadius: radius,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                MoeTokens.spaceXl,
                MoeTokens.spaceXl,
                MoeTokens.spaceXl,
                MoeTokens.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: MoeTokens.spaceLg),
                  _buildGuidanceBanner(),
                  const SizedBox(height: MoeTokens.space2xl),
                  _buildSectionLabel(
                    icon: Icons.category_rounded,
                    title: '反馈类型',
                    hint: '选一个最接近的选项',
                  ),
                  const SizedBox(height: MoeTokens.spaceMd),
                  _buildCategoryGrid(),
                  const SizedBox(height: MoeTokens.space2xl),
                  _buildSectionLabel(
                    icon: Icons.edit_note_rounded,
                    title: '问题描述',
                    hint: '越具体，越容易帮你定位',
                  ),
                  const SizedBox(height: MoeTokens.spaceMd),
                  _buildDescriptionField(),
                  const SizedBox(height: MoeTokens.spaceXs),
                  _buildFieldMeta(),
                  const SizedBox(height: MoeTokens.spaceXl),
                  const Divider(
                    height: 1,
                    color: MoeTokens.surfaceBorder,
                  ),
                  const SizedBox(height: MoeTokens.spaceLg),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _dialogIconSize,
          height: _dialogIconSize,
          decoration: BoxDecoration(
            gradient: MoeTokens.gradientKawaii,
            borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
            boxShadow: MoeTokens.shadowGlow(MoeTokens.pastelPink),
          ),
          child: const Icon(
            Icons.forum_rounded,
            color: Colors.white,
            size: MoeTokens.text2xl,
          ),
        ),
        const SizedBox(width: MoeTokens.spaceMd),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '意见反馈',
                style: TextStyle(
                  color: MoeTokens.titleText,
                  fontSize: MoeTokens.text2xl,
                  fontWeight: MoeTokens.fontWeightDisplay,
                  height: 1.2,
                ),
              ),
              SizedBox(height: MoeTokens.spaceXs),
              Text(
                '让每一条体验，都有机会被听见',
                style: TextStyle(
                  color: MoeTokens.inkMuted,
                  fontSize: MoeTokens.textSm,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: '关闭',
          child: IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: MoeTokens.inkMuted,
            iconSize: MoeTokens.textXl,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: MoeTokens.space3xl,
              minHeight: MoeTokens.space3xl,
            ),
            splashRadius: MoeTokens.spaceXl,
          ),
        ),
      ],
    );
  }

  Widget _buildGuidanceBanner() {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: MoeTokens.softChipBg.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: _sectionIconSize,
            height: _sectionIconSize,
            decoration: const BoxDecoration(
              gradient: MoeTokens.gradientSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: MoeTokens.textSm,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceSm),
          const Expanded(
            child: Text(
              '描述越具体，越容易帮你定位问题。可以写下发生了什么、何时发生，以及你当时正在做什么。',
              style: TextStyle(
                color: MoeTokens.caption,
                fontSize: MoeTokens.textSm,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel({
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return Row(
      children: [
        Container(
          width: _sectionIconSize,
          height: _sectionIconSize,
          decoration: BoxDecoration(
            color: MoeTokens.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: MoeTokens.primary,
            size: MoeTokens.textSm,
          ),
        ),
        const SizedBox(width: MoeTokens.spaceSm),
        Text(
          title,
          style: const TextStyle(
            color: MoeTokens.titleText,
            fontSize: MoeTokens.textMd,
            fontWeight: MoeTokens.fontWeightSubtitle,
          ),
        ),
        const SizedBox(width: MoeTokens.spaceSm),
        Expanded(
          child: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MoeTokens.hintText,
              fontSize: MoeTokens.textSm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth < _compactGridBreakpoint ? 1 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: MoeTokens.spaceSm,
            mainAxisSpacing: MoeTokens.spaceSm,
            mainAxisExtent: _categoryTileHeight,
          ),
          itemBuilder: (context, index) {
            final option = _categories[index];
            return _FeedbackCategoryTile(
              option: option,
              selected: _selectedCategory == option.label,
              onTap: () => setState(() => _selectedCategory = option.label),
            );
          },
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    final borderRadius = BorderRadius.circular(MoeTokens.radiusInput);
    final borderColor = _showContentError
        ? MoeTokens.danger.withValues(alpha: 0.65)
        : MoeTokens.surfaceBorder;

    return TextField(
      controller: _contentController,
      focusNode: _descriptionFocusNode,
      maxLines: 6,
      minLines: 5,
      maxLength: _maxDescriptionLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      cursorColor: MoeTokens.primary,
      style: const TextStyle(
        color: MoeTokens.titleText,
        fontSize: MoeTokens.textMd,
        height: 1.45,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: MoeTokens.surface0.withValues(alpha: 0.80),
        hintText: '例如：打开动态页后，向下滑动几次就没有新内容了',
        hintStyle: const TextStyle(
          color: MoeTokens.hintText,
          fontSize: MoeTokens.textMd,
          height: 1.45,
        ),
        errorText: _showContentError ? '请先写下你想告诉我们的内容' : null,
        errorStyle: const TextStyle(
          color: MoeTokens.danger,
          fontSize: MoeTokens.textSm,
        ),
        counterText: '',
        contentPadding: const EdgeInsets.all(MoeTokens.spaceLg),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: _showContentError ? MoeTokens.danger : MoeTokens.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: MoeTokens.danger.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(
            color: MoeTokens.danger,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldMeta() {
    return Row(
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: MoeTokens.hintText,
          size: MoeTokens.textSm,
        ),
        const SizedBox(width: MoeTokens.spaceXs),
        const Expanded(
          child: Text(
            '内容会发送给 Moe Social 团队',
            style: TextStyle(
              color: MoeTokens.hintText,
              fontSize: MoeTokens.textSm,
            ),
          ),
        ),
        Text(
          '$_characterCount / $_maxDescriptionLength',
          style: TextStyle(
            color: _characterCount > 0 ? MoeTokens.primary : MoeTokens.hintText,
            fontSize: MoeTokens.textSm,
            fontWeight: MoeTokens.fontWeightSubtitle,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: MoeTokens.inkMuted,
              padding: const EdgeInsets.symmetric(
                horizontal: MoeTokens.spaceSm,
                vertical: MoeTokens.spaceMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
              ),
            ),
            child: const Text(
              '关闭',
              style: TextStyle(
                fontSize: MoeTokens.textMd,
                fontWeight: MoeTokens.fontWeightSubtitle,
              ),
            ),
          ),
        ),
        const SizedBox(width: MoeTokens.spaceMd),
        Expanded(
          flex: 3,
          child: CustomButton(
            text: '提交反馈',
            onPressed: _submit,
            isLoading: _isSubmitting,
          ),
        ),
      ],
    );
  }
}

class _FeedbackCategoryOption {
  const _FeedbackCategoryOption({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _FeedbackCategoryTile extends StatelessWidget {
  const _FeedbackCategoryTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _FeedbackCategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MoeTokens.radiusLg);
    final foregroundColor = selected ? Colors.white : MoeTokens.titleText;
    final iconBackground = selected
        ? Colors.white.withValues(alpha: 0.18)
        : option.color.withValues(alpha: 0.12);

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: MoePressable(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: MoeTokens.motionFast,
          padding: const EdgeInsets.symmetric(
            horizontal: MoeTokens.spaceMd,
            vertical: MoeTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            gradient: selected ? MoeTokens.gradientPrimary : null,
            color: selected ? null : MoeTokens.surface0.withValues(alpha: 0.76),
            borderRadius: radius,
            border: selected
                ? null
                : Border.all(color: option.color.withValues(alpha: 0.22)),
            boxShadow: selected ? MoeTokens.shadowSm() : null,
          ),
          child: Row(
            children: [
              Container(
                width: MoeTokens.space3xl,
                height: MoeTokens.space3xl,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option.icon,
                  color: selected ? Colors.white : option.color,
                  size: MoeTokens.textLg,
                ),
              ),
              const SizedBox(width: MoeTokens.spaceSm),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: MoeTokens.textBase,
                    fontWeight: MoeTokens.fontWeightSubtitle,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: MoeTokens.motionFast,
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('selected'),
                        color: Colors.white,
                        size: MoeTokens.textLg,
                      )
                    : const SizedBox(
                        key: ValueKey('unselected'),
                        width: MoeTokens.textLg,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
