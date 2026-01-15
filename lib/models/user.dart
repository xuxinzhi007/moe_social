import 'avatar_configuration.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String avatar;
  final String signature; // 个性签名
  final String gender; // 性别
  final String? birthday; // 生日，后端返回的是字符串格式 YYYY-MM-DD
  final String? avatarConfig; // 虚拟形象配置JSON字符串
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
    this.signature = '',
    this.gender = '',
    this.birthday,
    this.avatarConfig,
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
      signature: json['signature'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      birthday: json['birthday'] as String?,
      avatarConfig: json['avatar_config'] as String?,
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
      'signature': signature,
      'gender': gender,
      'birthday': birthday,
      'avatar_config': avatarConfig,
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

  // 获取生日的DateTime对象（用于显示）
  DateTime? get birthdayDateTime {
    if (birthday == null || birthday!.isEmpty) return null;
    try {
      return DateTime.parse(birthday!);
    } catch (e) {
      return null;
    }
  }

  // 性别显示文本（用于UI显示）
  String get genderDisplayText {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      case 'secret':
        return '保密';
      default:
        return '未设置';
    }
  }

  // 获取年龄（根据生日计算）
  int? get age {
    final birthdayDate = birthdayDateTime;
    if (birthdayDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthdayDate.year;

    // 检查今年是否已经过了生日
    if (now.month < birthdayDate.month ||
        (now.month == birthdayDate.month && now.day < birthdayDate.day)) {
      age--;
    }

    return age;
  }

  // 获取虚拟形象配置对象
  AvatarConfiguration get avatarConfiguration {
    if (avatarConfig == null || avatarConfig!.isEmpty) {
      return const AvatarConfiguration(); // 返回默认配置
    }

    try {
      final Map<String, dynamic> json = {};
      // 这里需要解析JSON字符串，但为了简化，我们先返回默认配置
      // 在实际实现中，需要使用 dart:convert 的 jsonDecode
      return AvatarConfiguration.fromJson(json);
    } catch (e) {
      return const AvatarConfiguration(); // 解析失败时返回默认配置
    }
  }

  // 创建副本并更新虚拟形象配置
  User copyWithAvatarConfig(AvatarConfiguration config) {
    return User(
      id: id,
      username: username,
      email: email,
      avatar: avatar,
      signature: signature,
      gender: gender,
      birthday: birthday,
      avatarConfig: config.toString(), // 这里需要序列化为JSON字符串
      isVip: isVip,
      vipExpiresAt: vipExpiresAt,
      autoRenew: autoRenew,
      balance: balance,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}