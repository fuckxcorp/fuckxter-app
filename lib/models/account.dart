class Account {
  const Account({
    required this.name,
    required this.handle,
    required this.email,
    required this.bio,
    this.avatarUrl,
    this.headerUrl,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    return Account(
      name: profile['name'] as String? ?? '',
      handle: profile['handle'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      bio: profile['bio'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      headerUrl: json['headerUrl'] as String?,
    );
  }

  final String name;
  final String handle;
  final String email;
  final String bio;
  final String? avatarUrl;
  final String? headerUrl;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.handle,
    required this.bio,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isFollowing,
    this.avatarUrl,
    this.headerUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    return UserProfile(
      name: json['name'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      posts: (stats['posts'] as num?)?.toInt() ?? 0,
      followers: (stats['followers'] as num?)?.toInt() ?? 0,
      following: (stats['following'] as num?)?.toInt() ?? 0,
      isFollowing: viewer['following'] as bool? ?? false,
      avatarUrl: json['avatarUrl'] as String?,
      headerUrl: json['headerUrl'] as String?,
    );
  }

  final String name;
  final String handle;
  final String bio;
  final int posts;
  final int followers;
  final int following;
  final bool isFollowing;
  final String? avatarUrl;
  final String? headerUrl;
}
