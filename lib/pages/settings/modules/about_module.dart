import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/device_info_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/update_service.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';

class AboutModule extends StatelessWidget {
  const AboutModule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deviceInfo = Provider.of<DeviceInfoProvider>(context);

    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: Icons.info_rounded,
          title: '软件版本',
          subtitle: '点击检查更新',
          color: Colors.teal,
          onTap: () {
            UpdateService.checkUpdate(context, showNoUpdateToast: true);
          },
          trailing: Text(
            deviceInfo.versionDisplayLabel,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        MoeMenuItem(
          icon: Icons.feedback_outlined,
          title: '意见反馈',
          subtitle: '问题描述与联系方式',
          color: Colors.deepOrange,
          onTap: () => _showFeedbackDialog(context),
        ),
        MoeMenuItem(
          icon: Icons.description_rounded,
          title: '用户协议',
          subtitle: '使用条款摘要',
          color: Colors.indigo,
          onTap: () => _showUserAgreementDialog(context),
        ),
      ],
    );
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
    final contentController = TextEditingController();
    String selectedCategory = '其他';
    bool isSubmitting = false;

    final categories = ['闪退崩溃', '登录问题', '功能异常', '功能建议', '其他'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('意见反馈'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '感谢使用 Moe Social！如遇闪退、无法登录、动态/评论异常等问题，欢迎反馈。',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text(
                  '问题分类',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map((cat) => ChoiceChip(
                            label: Text(cat, style: const TextStyle(fontSize: 13)),
                            selected: selectedCategory == cat,
                            onSelected: (selected) {
                              setState(() => selectedCategory = cat);
                            },
                            selectedColor: Colors.deepOrange.withOpacity(0.15),
                            labelStyle: selectedCategory == cat
                                ? const TextStyle(color: Colors.deepOrange)
                                : null,
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  '问题描述',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    hintText: '请详细描述问题现象、机型、系统版本等',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (contentController.text.trim().isEmpty) {
                        MoeToast.warning(context, '请填写问题描述');
                        return;
                      }
                      setState(() => isSubmitting = true);
                      try {
                        await ApiService.submitFeedback(
                          email: _feedbackEmail,
                          category: selectedCategory,
                          content: contentController.text.trim(),
                          source: 'app_feedback',
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        MoeToast.success(context, '反馈已提交');
                      } catch (e) {
                        if (!ctx.mounted) return;
                        MoeToast.error(context, '提交失败：$e');
                      } finally {
                        setState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('提交反馈'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserAgreementDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('用户协议（摘要）'),
        content: SingleChildScrollView(
          child: Text(
            _userAgreementSummary,
            style: const TextStyle(height: 1.45, fontSize: 14),
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
