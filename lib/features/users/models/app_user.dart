/// 用户模型。对齐 SGiT-Server `basic_information.users` 表字段。
class AppUser {
  const AppUser({
    required this.userId,
    this.userName,
    this.nickname,
    this.realName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.status = 1,
    this.userLevel,
    this.createdAt,
  });

  final String userId;
  final String? userName;
  final String? nickname;
  final String? realName;
  final String? phone;
  final String? email;
  final String? avatarUrl;

  /// 1-正常, 0-禁用。
  final int status;
  final String? userLevel;
  final String? createdAt;

  bool get isActive => status == 1;

  /// 展示名：昵称优先，其次用户名，最后用户ID。
  String get displayName =>
      (nickname?.isNotEmpty ?? false) ? nickname! : (userName ?? userId);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    int parseStatus(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 1;
      return 1;
    }

    return AppUser(
      userId: (json['user_id'] ?? '').toString(),
      userName: json['user_name']?.toString(),
      nickname: json['nickname']?.toString(),
      realName: json['real_name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      status: parseStatus(json['status']),
      userLevel: json['user_level']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
