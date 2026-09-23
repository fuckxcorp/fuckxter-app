class FeedPage {
  const FeedPage({required this.posts, this.nextCursor});

  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
        posts: (json['posts'] as List<dynamic>? ?? const [])
            .map((item) => Post.fromJson(item as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );

  final List<Post> posts;
  final String? nextCursor;
}

class Post {
  const Post(
      {required this.id,
      required this.author,
      required this.text,
      required this.createdAt,
      required this.stats,
      this.media,
      this.liked = false,
      this.reposted = false,
      this.saved = false});

  factory Post.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    return Post(
      id: json['id'] as String,
      author: Author.fromJson(json['author'] as Map<String, dynamic>),
      text: json['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      stats: PostStats.fromJson(
          json['stats'] as Map<String, dynamic>? ?? const {}),
      media: json['media'] is Map<String, dynamic>
          ? PostMedia.fromJson(json['media'] as Map<String, dynamic>)
          : null,
      liked: viewer['liked'] as bool? ?? false,
      reposted: viewer['reposted'] as bool? ?? false,
      saved: viewer['saved'] as bool? ?? false,
    );
  }

  final String id;
  final Author author;
  final String text;
  final DateTime createdAt;
  final PostStats stats;
  final PostMedia? media;
  final bool liked;
  final bool reposted;
  final bool saved;
}

class Author {
  const Author(
      {required this.name,
      required this.handle,
      this.avatarUrl,
      this.verified = false});
  factory Author.fromJson(Map<String, dynamic> json) => Author(
      name: json['name'] as String? ?? '未命名用户',
      handle: json['handle'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      verified: json['verified'] as bool? ?? false);
  final String name;
  final String handle;
  final String? avatarUrl;
  final bool verified;
}

class PostStats {
  const PostStats(
      {required this.replies,
      required this.reposts,
      required this.likes,
      required this.views});
  factory PostStats.fromJson(Map<String, dynamic> json) => PostStats(
      replies: (json['replies'] as num?)?.toInt() ?? 0,
      reposts: (json['reposts'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0);
  final int replies;
  final int reposts;
  final int likes;
  final int views;
}

class PostMedia {
  const PostMedia({required this.url, required this.alt});
  factory PostMedia.fromJson(Map<String, dynamic> json) => PostMedia(
      url: json['url'] as String? ?? '', alt: json['alt'] as String? ?? '');
  final String url;
  final String alt;
}
