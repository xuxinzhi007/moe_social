import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/device_info_provider.dart';
import '../../../services/update_service.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';

class AboutModule extends StatelessWidget {
  const AboutModule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deviceInfo = Provider.of<DeviceInfoProvider>(context);

    return FadeInUp(
      delay: const Duration(milliseconds: 600),
      child: MoeMenuCard(
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
          MoeMenuItem(
            icon: Icons.star_rounded,
            title: '给我们评分',
            subtitle: '在应用商店给我们好评',
            color: Colors.amber,
            onTap: () => _showRateAppDialog(context),
          ),
        ],
      ),
    );
  }

  /// 预留邮箱，上线前可在服务端/配置中替换为正式支持地址。
  static const String _feedbackEmail = 'feedback@moe-social.app';

  static const String _userAgreementSummary =
      '欢迎使用 Moe Social。使用本应用即表示您知悉并同意下列要点（完整版以实际上线文案为准）：\n\n'
      '1. 账号与内容：请妥善保管账号信息；您发布的内容需合法合规，不得侵害他人权益。\n'
      '2. 隐私：我们会在必要范围内处理设备与网络信息以提供服务，详见「隐私设置」相关说明。\n'
      '3. 服务变更：功能可能随版本迭代调整；重要变更将通过应用内提示或公告告知。\n'
      '4. 责任限制：在适用法律允许范围内，对不可抗力或第三方原因导致的服务中断，我们将尽力协助但不承担超出法律要求的责任。\n\n'
      '若您不同意上述内容，请停止使用本应用。';

  void _showFeedbackDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('意见反馈'),
        content: const SingleChildScrollView(
          child: Text(
            '感谢使用 Moe Social！\n\n'
            '如遇闪退、无法登录、动态/评论异常等问题，欢迎反馈。你可先复制下方预留邮箱，将问题现象与机型、系统版本一并发送，便于我们排查。\n\n'
            '（正式环境请将 feedback@moe-social.app 替换为你的支持邮箱。）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _feedbackEmail),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              MoeToast.success(context, '已复制反馈邮箱');
            },
            child: const Text('复制邮箱'),
          ),
        ],
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

  void _showRateAppDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('给我们评分'),
        content: const Text(
          '如果你喜欢 Moe Social，请在应用商店给我们好评，这对我们非常重要！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 这里应该跳转到应用商店评分页面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('功能开发中')),
              );
            },
            child: const Text('去评分'),
          ),
        ],
      ),
    );
  }
}
