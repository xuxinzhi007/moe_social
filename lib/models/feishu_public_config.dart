class FeishuPublicConfig {
  final bool enabled;
  final String enterpriseInviteUrl;
  final String notice;

  const FeishuPublicConfig({
    this.enabled = false,
    this.enterpriseInviteUrl = '',
    this.notice = '',
  });

  bool get hasInviteLink => enterpriseInviteUrl.trim().isNotEmpty;

  factory FeishuPublicConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeishuPublicConfig();
    return FeishuPublicConfig(
      enabled: json['enabled'] as bool? ?? false,
      enterpriseInviteUrl:
          (json['enterprise_invite_url'] as String?)?.trim() ?? '',
      notice: (json['notice'] as String?)?.trim() ?? '',
    );
  }
}
