class FeedPage {
  const FeedPage({required this.posts, this.nextCursor});

  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
    posts: (json['posts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    nextCursor: json['nextCursor'] as String?,
  );

  final List<Post> posts;
  final String? nextCursor;
}

class Post {
  const Post({
    required this.id,
    required this.slug,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.stats,
    this.visibility = 'public',
    this.media = const [],
    this.liked = false,
    this.reposted = false,
    this.saved = false,
    this.followingAuthor = false,
    this.isAuthor = false,
    this.repostKind,
    this.source,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    final source = json['source'];
    return Post(
      id: '${json['id'] ?? ''}',
      slug: json['slug'] as String? ?? '',
      author: Author.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      visibility: json['visibility'] as String? ?? 'public',
      stats: PostStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? const {},
      ),
      media: mediaList(json['media']),
      liked: viewer['liked'] as bool? ?? false,
      reposted: viewer['reposted'] as bool? ?? false,
      saved: viewer['saved'] as bool? ?? false,
      followingAuthor: viewer['followingAuthor'] as bool? ?? false,
      isAuthor: viewer['isAuthor'] as bool? ?? false,
      repostKind: json['repostKind'] as String?,
      source: source is Map
          ? Post.fromJson(Map<String, dynamic>.from(source))
          : null,
    );
  }

  final String id;
  final String slug;
  final Author author;
  final String text;
  final DateTime createdAt;
  final String visibility;
  final PostStats stats;
  final List<PostMedia> media;
  final bool liked;
  final bool reposted;
  final bool saved;
  final bool followingAuthor;
  final bool isAuthor;
  final String? repostKind;
  final Post? source;

  Post copyWith({
    String? text,
    String? visibility,
    PostStats? stats,
    bool? liked,
    bool? reposted,
    bool? saved,
    List<PostMedia>? media,
    Post? source,
    bool updateSource = false,
  }) => Post(
    id: id,
    slug: slug,
    author: author,
    text: text ?? this.text,
    createdAt: createdAt,
    visibility: visibility ?? this.visibility,
    stats: stats ?? this.stats,
    media: media ?? this.media,
    liked: liked ?? this.liked,
    reposted: reposted ?? this.reposted,
    saved: saved ?? this.saved,
    followingAuthor: followingAuthor,
    isAuthor: isAuthor,
    repostKind: repostKind,
    source: updateSource ? source : this.source,
  );
}

class Author {
  const Author({
    required this.name,
    required this.handle,
    this.id = '',
    this.avatarUrl,
    this.verified = false,
  });

  factory Author.fromJson(Map<String, dynamic> json) => Author(
    id: '${json['id'] ?? ''}',
    name: json['name'] as String? ?? '未命名用户',
    handle: json['handle'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    verified: json['verified'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool verified;
}

class PostStats {
  const PostStats({
    required this.replies,
    required this.reposts,
    required this.likes,
    required this.views,
  });

  factory PostStats.fromJson(Map<String, dynamic> json) => PostStats(
    replies: (json['replies'] as num?)?.toInt() ?? 0,
    reposts: (json['reposts'] as num?)?.toInt() ?? 0,
    likes: (json['likes'] as num?)?.toInt() ?? 0,
    views: (json['views'] as num?)?.toInt() ?? 0,
  );

  final int replies;
  final int reposts;
  final int likes;
  final int views;

  PostStats copyWith({int? replies, int? reposts, int? likes, int? views}) =>
      PostStats(
        replies: replies ?? this.replies,
        reposts: reposts ?? this.reposts,
        likes: likes ?? this.likes,
        views: views ?? this.views,
      );
}

class PostMedia {
  const PostMedia({
    required this.url,
    required this.alt,
    this.id = '',
    this.contentType = '',
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) => PostMedia(
    id: '${json['id'] ?? ''}',
    url: json['url'] as String? ?? '',
    alt: json['alt'] as String? ?? '',
    contentType: json['contentType'] as String? ?? '',
  );

  final String id;
  final String url;
  final String alt;
  final String contentType;
}

List<PostMedia> mediaList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => PostMedia.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.url.isNotEmpty)
        .toList();
  }
  if (raw is Map) {
    final media = PostMedia.fromJson(Map<String, dynamic>.from(raw));
    return media.url.isEmpty ? const [] : [media];
  }
  return const [];
}

class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.handle,
    required this.bio,
    required this.email,
    required this.region,
    required this.gender,
    required this.birthday,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    name: json['name'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    bio: json['bio'] as String? ?? '',
    email: json['email'] as String? ?? '',
    region: json['region'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    birthday: json['birthday'] as String? ?? '',
  );

  final String name;
  final String handle;
  final String bio;
  final String email;
  final String region;
  final String gender;
  final String birthday;
}

class Account {
  const Account({
    required this.profile,
    this.avatarUrl,
    this.headerUrl,
    this.twoFactorEnabled = false,
    this.recoveryCodeCount = 0,
    this.dmPolicy = 'everyone',
    this.createdAt = '',
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    profile: AccountProfile.fromJson(
      json['profile'] as Map<String, dynamic>? ?? const {},
    ),
    avatarUrl: json['avatarUrl'] as String?,
    headerUrl: json['headerUrl'] as String?,
    twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
    recoveryCodeCount: (json['recoveryCodeCount'] as num?)?.toInt() ?? 0,
    dmPolicy: json['dmPolicy'] as String? ?? 'everyone',
    createdAt: json['createdAt'] as String? ?? '',
  );

  final AccountProfile profile;
  final String? avatarUrl;
  final String? headerUrl;
  final bool twoFactorEnabled;
  final int recoveryCodeCount;
  final String dmPolicy;
  final String createdAt;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.handle,
    required this.name,
    required this.bio,
    required this.createdAt,
    required this.posts,
    required this.followers,
    required this.following,
    this.verified = false,
    this.region = '',
    this.avatarUrl,
    this.headerUrl,
    this.viewerFollowing = false,
    this.blocked = false,
    this.canMessage = true,
    this.deleted = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    return UserProfile(
      id: '${json['id'] ?? ''}',
      handle: json['handle'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      region: json['region'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      headerUrl: json['headerUrl'] as String?,
      verified: json['verified'] as bool? ?? false,
      posts: (stats['posts'] as num?)?.toInt() ?? 0,
      followers: (stats['followers'] as num?)?.toInt() ?? 0,
      following: (stats['following'] as num?)?.toInt() ?? 0,
      viewerFollowing: viewer['following'] as bool? ?? false,
      blocked: viewer['blocked'] as bool? ?? false,
      canMessage: viewer['canMessage'] as bool? ?? true,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  final String id;
  final String handle;
  final String name;
  final String bio;
  final String region;
  final String createdAt;
  final String? avatarUrl;
  final String? headerUrl;
  final bool verified;
  final int posts;
  final int followers;
  final int following;
  final bool viewerFollowing;
  final bool blocked;
  final bool canMessage;
  final bool deleted;
}

class UserSummary {
  const UserSummary({
    required this.handle,
    required this.name,
    required this.bio,
    required this.posts,
    required this.followers,
    required this.following,
    this.avatarUrl,
    this.verified = false,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    return UserSummary(
      handle: json['handle'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      verified: json['verified'] as bool? ?? false,
      posts: (stats['posts'] as num?)?.toInt() ?? 0,
      followers: (stats['followers'] as num?)?.toInt() ?? 0,
      following: (stats['following'] as num?)?.toInt() ?? 0,
    );
  }

  final String handle;
  final String name;
  final String bio;
  final String? avatarUrl;
  final bool verified;
  final int posts;
  final int followers;
  final int following;
}

class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.likes,
    required this.reposts,
    this.media = const [],
    this.liked = false,
    this.reposted = false,
    this.parentHandle,
    this.parentName,
    this.parentText,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    final parent = json['parent'];
    return Comment(
      id: '${json['id'] ?? ''}',
      author: Author.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      media: mediaList(json['media']),
      likes: (stats['likes'] as num?)?.toInt() ?? 0,
      reposts: (stats['reposts'] as num?)?.toInt() ?? 0,
      liked: viewer['liked'] as bool? ?? false,
      reposted: viewer['reposted'] as bool? ?? false,
      parentHandle: parent is Map ? parent['handle'] as String? : null,
      parentName: parent is Map ? parent['name'] as String? : null,
      parentText: parent is Map ? parent['text'] as String? : null,
    );
  }

  final String id;
  final Author author;
  final String text;
  final DateTime createdAt;
  final List<PostMedia> media;
  final int likes;
  final int reposts;
  final bool liked;
  final bool reposted;
  final String? parentHandle;
  final String? parentName;
  final String? parentText;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.mine,
    required this.read,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
    id: '${json['id'] ?? ''}',
    body: json['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    mine: json['mine'] as bool? ?? false,
    read: json['read'] as bool? ?? false,
  );

  final String id;
  final String body;
  final DateTime createdAt;
  final bool mine;
  final bool read;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.other,
    required this.unread,
    this.lastBody = '',
    this.lastMine = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return Conversation(
      id: '${json['id'] ?? ''}',
      other: Author.fromJson(
        json['other'] as Map<String, dynamic>? ?? const {},
      ),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      lastBody: last is Map ? last['body'] as String? ?? '' : '',
      lastMine: last is Map ? last['mine'] as bool? ?? false : false,
    );
  }

  final String id;
  final Author other;
  final int unread;
  final String lastBody;
  final bool lastMine;
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.read,
    this.actor,
    this.postText,
    this.postHandle,
    this.postSlug,
    this.commentText,
  });

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    final post = json['post'];
    final comment = json['comment'];
    return AppNotice(
      id: '${json['id'] ?? ''}',
      type: json['type'] as String? ?? 'system',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      read: json['read'] as bool? ?? false,
      actor: actor is Map
          ? Author.fromJson(Map<String, dynamic>.from(actor))
          : null,
      postText: post is Map ? post['text'] as String? : null,
      postHandle: post is Map ? post['authorHandle'] as String? : null,
      postSlug: post is Map ? post['slug'] as String? : null,
      commentText: comment is Map ? comment['text'] as String? : null,
    );
  }

  final String id;
  final String type;
  final DateTime createdAt;
  final bool read;
  final Author? actor;
  final String? postText;
  final String? postHandle;
  final String? postSlug;
  final String? commentText;
}

class HistoryItem {
  const HistoryItem({
    required this.handle,
    required this.slug,
    required this.name,
    required this.text,
    required this.at,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    handle: json['handle'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? '',
    text: json['text'] as String? ?? '',
    at: json['at'] as String? ?? '',
  );

  Map<String, String> toJson() => {
    'handle': handle,
    'slug': slug,
    'name': name,
    'text': text,
    'at': at,
  };

  final String handle;
  final String slug;
  final String name;
  final String text;
  final String at;
}
