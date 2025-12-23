class User {
  final String id;
  final String username;
  final String email;
  final String avatar;
  final bool isVip;
  final String? vipExpiresAt; // 后端返回的是字符串格式
  final bool autoRenew;
  final double balance; // 钱包余额
  final String createdAt; // 后端返回的是字符串格式
  final String updatedAt; // 后端返回的是字符串格式

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatar = '',
    this.isVip = false,
    this.vipExpiresAt,
    this.autoRenew = false,
    this.balance = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  // 从JSON创建User实例（后端返回格式）
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String? ?? '',
      isVip: json['is_vip'] as bool? ?? false,
      vipExpiresAt: json['vip_expires_at'] as String?,
      autoRenew: json['auto_renew'] as bool? ?? false,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  // 转换为JSON（用于发送到后端）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'is_vip': isVip,
      'vip_expires_at': vipExpiresAt,
      'auto_renew': autoRenew,
      'balance': balance,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // 获取创建时间的DateTime对象（用于显示）
  DateTime? get createdAtDateTime {
    try {
      return DateTime.parse(createdAt);
    } catch (e) {
      return null;
    }
  }

  // 获取更新时间的DateTime对象（用于显示）
  DateTime? get updatedAtDateTime {
    try {
      return DateTime.parse(updatedAt);
    } catch (e) {
      return null;
    }
  }

  // 获取VIP过期时间的DateTime对象（用于显示）
  DateTime? get vipExpiresAtDateTime {
    if (vipExpiresAt == null || vipExpiresAt!.isEmpty) return null;
    try {
      return DateTime.parse(vipExpiresAt!);
    } catch (e) {
      return null;
    }
  }
}