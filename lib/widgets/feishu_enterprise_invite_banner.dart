import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/feishu_public_config.dart';
import '../services/api_service.dart';
import 'moe_toast.dart';

/// 可选：说明机器人仅企业内可用，并提供「申请加入企业」链接。
class FeishuEnterpriseInviteBanner extends StatefulWidget {
  const FeishuEnterpriseInviteBanner({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<FeishuEnterpriseInviteBanner> createState() =>
      _FeishuEnterpriseInviteBannerState();
}

class _FeishuEnterpriseInviteBannerState
    extends State<FeishuEnterpriseInviteBanner> {
  FeishuPublicConfig? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cfg = await ApiService.getFeishuPublicConfig();
      if (mounted) setState(() => _config = cfg);
    } catch (_) {
      // 配置拉取失败则不展示，不阻断登录
    }
  }

  Future<void> _openInvite() async {
    final url = _config?.enterpriseInviteUrl ?? '';
    if (url.isEmpty) {
      MoeToast.error(context, '暂未配置企业邀请链接');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) MoeToast.error(context, '无法打开邀请链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    if (cfg == null || !cfg.enabled) return const SizedBox.shrink();

    final notice = cfg.notice;
    if (notice.isEmpty && !cfg.hasInviteLink) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            if (notice.isNotEmpty)
              Text(
                notice,
                style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.35),
              ),
            if (cfg.hasInviteLink)
              TextButton(
                onPressed: _openInvite,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF3370FF),
                ),
                child: const Text('申请加入企业', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3370FF).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice.isNotEmpty)
            Text(
              notice,
              style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.45),
            ),
          if (cfg.hasInviteLink) ...[
            if (notice.isNotEmpty) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openInvite,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('申请加入企业（可选）'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3370FF),
                side: const BorderSide(color: Color(0xFF3370FF)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
