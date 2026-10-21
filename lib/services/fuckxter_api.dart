import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class FuckXterApi {
  FuckXterApi({http.Client? client}) : _client = client ?? http.Client();

  static const origin = 'https://api.fuckxter.site';
  static const site = 'https://fuckxter.site';
  final http.Client _client;
  String? cookie;

  static bool isMediaUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.hasAuthority &&
      uri.origin == origin &&
      uri.userInfo.isEmpty &&
      RegExp(r'^/(media|avatars|headers)/[^/]+$').hasMatch(uri.path);

  static String media(String path) {
    final uri = Uri.parse(origin).resolve(path);
    if (!isMediaUri(uri)) {
      throw const ApiException('图片地址无效。', 0);
    }
    return uri.toString();
  }

  static Uri displayUri(String path, int width) {
    final uri = Uri.parse(media(path));
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'format': 'webp',
        'width': '$width',
      },
    );
  }

  Map<String, String> get imageHeaders {
    if (cookie == null || cookie!.isEmpty) return const {};
    return {'Cookie': 'fk_session=$cookie'};
  }

  String postWebUrl(Post post) =>
      '$site/post/${Uri.encodeComponent(post.author.handle)}/${Uri.encodeComponent(post.slug)}';

  Future<Account?> me() async {
    final json = await _json('GET', '/auth/me');
    final account = json['account'];
    if (account is! Map) return null;
    return Account.fromJson(Map<String, dynamic>.from(account));
  }

  Future<({Account account, bool restored})> login({
    required String identifier,
    required String password,
    String? code,
    String? recoveryCode,
  }) async {
    final json = await _json(
      'POST',
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
        if (code != null && code.isNotEmpty) 'code': code,
        if (recoveryCode != null && recoveryCode.isNotEmpty)
          'recoveryCode': recoveryCode,
      },
    );
    final account = json['account'];
    if (account is! Map) {
      throw const ApiException('登录响应中没有账号信息。', 0);
    }
    return (
      account: Account.fromJson(Map<String, dynamic>.from(account)),
      restored: json['restored'] == true,
    );
  }

  Future<void> logout() => _send('POST', '/auth/logout');

  Future<Account> updateProfile(Map<String, String> input) async {
    final json = await _json('PATCH', '/me', body: input);
    return _account(json);
  }

  Future<Account> changeEmail({
    required String email,
    required String password,
  }) async {
    final json = await _json(
      'PUT',
      '/me/email',
      body: {'email': email, 'password': password},
    );
    return _account(json);
  }

  Future<void> changePassword({
    required String current,
    required String next,
  }) => _send('PUT', '/me/password', body: {'current': current, 'next': next});

  Future<Account> setDmPolicy(String policy) async {
    final json = await _json(
      'PATCH',
      '/me/dm-policy',
      body: {'policy': policy},
    );
    return _account(json);
  }

  Future<void> deleteAccount() => _send('DELETE', '/me');

  Future<String> beginTwoFactor() async {
    final json = await _json('POST', '/me/2fa/setup');
    return json['secret'] as String? ?? '';
  }

  Future<Account> confirmTwoFactor(String code) async {
    final json = await _json('POST', '/me/2fa/confirm', body: {'code': code});
    return _account(json);
  }

  Future<List<String>> recoveryCodes() async {
    final json = await _json('POST', '/me/2fa/recovery-codes');
    return (json['codes'] as List<dynamic>? ?? const [])
        .map((item) => '$item')
        .toList();
  }

  Future<FeedPage> timeline({required String tab, String? cursor}) async {
    final json = await _json(
      'GET',
      '/timeline',
      query: {'tab': tab, 'limit': '10', if (cursor != null) 'cursor': cursor},
    );
    return FeedPage.fromJson(json);
  }

  Future<Post> createPost(
    String text, {
    List<String> mediaIds = const [],
    String visibility = 'public',
  }) async {
    final json = await _json(
      'POST',
      '/posts',
      body: {'text': text, 'mediaIDs': mediaIds, 'visibility': visibility},
    );
    return Post.fromJson(json);
  }

  Future<Post> updatePost(String id, String text, {String? visibility}) async {
    final json = await _json(
      'PATCH',
      '/posts/${Uri.encodeComponent(id)}',
      body: {'text': text, if (visibility != null) 'visibility': visibility},
    );
    return Post.fromJson(json);
  }

  Future<void> deletePost(String id) =>
      _send('DELETE', '/posts/${Uri.encodeComponent(id)}');

  Future<({bool liked, int likes})> setLike(String id, bool liked) async {
    final json = await _json(
      liked ? 'PUT' : 'DELETE',
      '/posts/${Uri.encodeComponent(id)}/like',
    );
    return (
      liked: json['liked'] as bool? ?? liked,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<({bool reposted, int reposts})> setRepost(
    String id,
    bool reposted,
  ) async {
    final json = await _json(
      reposted ? 'PUT' : 'DELETE',
      '/posts/${Uri.encodeComponent(id)}/repost',
    );
    return (
      reposted: json['reposted'] as bool? ?? reposted,
      reposts: (json['reposts'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Post> quotePost(String id, String text) async {
    final json = await _json(
      'POST',
      '/posts/${Uri.encodeComponent(id)}/quote',
      body: {'text': text},
    );
    return Post.fromJson(json);
  }

  Future<void> setSave(String id, bool saved) =>
      _send(saved ? 'PUT' : 'DELETE', '/posts/${Uri.encodeComponent(id)}/save');

  Future<List<Post>> savedPosts() async {
    final json = await _json('GET', '/me/saved');
    return (json['posts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Post?> postByPath(String handle, String slug) async {
    try {
      final json = await _json(
        'GET',
        '/posts/${Uri.encodeComponent(handle)}/${Uri.encodeComponent(slug)}',
      );
      return Post.fromJson(json);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Post>> postsByUser(String handle) async {
    final json = await _json(
      'GET',
      '/users/${Uri.encodeComponent(handle)}/posts',
    );
    return (json['posts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<({List<UserSummary> users, List<Post> posts})> search(
    String query,
  ) async {
    final json = await _json('GET', '/search', query: {'q': query});
    return (
      users: (json['users'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => UserSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      posts: (json['posts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Future<UserProfile> profile(String handle) async {
    final json = await _json('GET', '/users/${Uri.encodeComponent(handle)}');
    final user = json['user'];
    if (user is! Map) throw const ApiException('没有找到这个用户。', 404);
    return UserProfile.fromJson(Map<String, dynamic>.from(user));
  }

  Future<({bool following, int followers})> setFollow(
    String handle,
    bool following,
  ) async {
    final json = await _json(
      following ? 'PUT' : 'DELETE',
      '/users/${Uri.encodeComponent(handle)}/follow',
    );
    return (
      following: json['following'] as bool? ?? following,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> setBlock(String handle, bool blocked) async {
    final json = await _json(
      blocked ? 'PUT' : 'DELETE',
      '/users/${Uri.encodeComponent(handle)}/block',
    );
    return json['blocked'] as bool? ?? blocked;
  }

  Future<List<UserSummary>> connections(String handle, String kind) async {
    final json = await _json(
      'GET',
      '/users/${Uri.encodeComponent(handle)}/$kind',
    );
    return (json['users'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => UserSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Comment>> comments(String postId) async {
    final json = await _json(
      'GET',
      '/posts/${Uri.encodeComponent(postId)}/comments',
    );
    return (json['comments'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Comment.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentId,
    List<String> mediaIds = const [],
  }) async {
    final json = await _json(
      'POST',
      '/posts/${Uri.encodeComponent(postId)}/comments',
      body: {
        'text': text,
        if (parentId != null) 'parentId': parentId,
        'mediaIDs': mediaIds,
      },
    );
    final comment = json['comment'];
    if (comment is! Map) throw const ApiException('评论响应无效。', 0);
    return Comment.fromJson(Map<String, dynamic>.from(comment));
  }

  Future<void> deleteComment(String postId, String commentId) => _send(
    'DELETE',
    '/posts/${Uri.encodeComponent(postId)}/comments/${Uri.encodeComponent(commentId)}',
  );

  Future<({bool liked, int likes})> setCommentLike(
    String postId,
    String commentId,
    bool liked,
  ) async {
    final json = await _json(
      liked ? 'PUT' : 'DELETE',
      '/posts/${Uri.encodeComponent(postId)}/comments/${Uri.encodeComponent(commentId)}/like',
    );
    return (
      liked: json['liked'] as bool? ?? liked,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<AppNotice>> notices() async {
    final json = await _json('GET', '/notice', query: {'limit': '40'});
    return (json['notices'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => AppNotice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<int> markNoticesRead() async {
    final json = await _json('POST', '/notice', body: {});
    return (json['unread'] as num?)?.toInt() ?? 0;
  }

  Future<({List<Conversation> threads, int unread})> conversations() async {
    final json = await _json('GET', '/messages');
    return (
      threads: (json['threads'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<({List<DirectMessage> messages, bool canSend, String? hint})>
  conversation(String handle) async {
    final json = await _json('GET', '/messages/${Uri.encodeComponent(handle)}');
    return (
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => DirectMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      canSend: json['canSend'] as bool? ?? true,
      hint: json['hint'] as String?,
    );
  }

  Future<List<DirectMessage>> sendMessage(String handle, String text) async {
    final json = await _json(
      'POST',
      '/messages/${Uri.encodeComponent(handle)}',
      body: {'text': text},
    );
    return (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => DirectMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> markRead(String handle) =>
      _send('POST', '/messages/${Uri.encodeComponent(handle)}/read');

  Future<void> recallMessage(String handle, String messageId) => _send(
    'DELETE',
    '/messages/${Uri.encodeComponent(handle)}/${Uri.encodeComponent(messageId)}',
  );

  Future<PostMedia> uploadMedia({
    required List<int> bytes,
    required String name,
    required String contentType,
  }) async {
    final response = await _raw(
      'POST',
      '/media',
      bytes: bytes,
      headers: {
        'Content-Type': contentType.isEmpty
            ? 'application/octet-stream'
            : contentType,
        'X-File-Name': Uri.encodeComponent(name),
      },
    );
    final json = _decode(response);
    final media = json['media'];
    if (media is! Map) throw const ApiException('上传响应无效。', 0);
    return PostMedia.fromJson(Map<String, dynamic>.from(media));
  }

  Future<void> uploadAvatar({
    required List<int> bytes,
    required String name,
    required String contentType,
  }) => _uploadProfile('/me/avatar', bytes, name, contentType);

  Future<void> uploadHeader({
    required List<int> bytes,
    required String name,
    required String contentType,
  }) => _uploadProfile('/me/header', bytes, name, contentType);

  Future<void> removeAvatar() => _send('DELETE', '/me/avatar');

  Future<void> removeHeader() => _send('DELETE', '/me/header');

  Future<void> _uploadProfile(
    String path,
    List<int> bytes,
    String name,
    String contentType,
  ) async {
    await _raw(
      'PUT',
      path,
      bytes: bytes,
      headers: {
        'Content-Type': contentType.isEmpty
            ? 'application/octet-stream'
            : contentType,
        'X-File-Name': Uri.encodeComponent(name),
      },
    );
  }

  Account _account(Map<String, dynamic> json) {
    final account = json['account'];
    if (account is! Map) throw const ApiException('账号响应无效。', 0);
    return Account.fromJson(Map<String, dynamic>.from(account));
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final response = await _raw(
      method,
      path,
      query: query,
      body: body == null ? null : jsonEncode(body),
      headers: body == null
          ? const {}
          : const {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 204 || response.body.isEmpty) return const {};
    return _decode(response);
  }

  Future<void> _send(String method, String path, {Object? body}) async {
    await _json(method, path, body: body);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException('响应格式无效。', 0);
  }

  Future<http.Response> _raw(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String> headers = const {},
    List<int>? bytes,
  }) async {
    final uri = Uri.parse('$origin$path').replace(queryParameters: query);
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    )..followRedirects = false;
    final session = cookie;
    request.headers.addAll({
      'Accept': 'application/json',
      ...imageHeaders,
      ...headers,
    });
    if (bytes != null) {
      request.bodyBytes = bytes;
    } else if (body is String) {
      request.body = body;
    }
    final response =
        await (() async {
          final streamed = await _client.send(request);
          return http.Response.fromStream(streamed);
        })().timeout(
          Duration(seconds: method == 'GET' ? 15 : 30),
          onTimeout: () {
            abort.complete();
            throw TimeoutException('请求超时，请重试。');
          },
        );
    if (cookie == session) _captureCookie(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
    return response;
  }

  void _captureCookie(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;
    final match = RegExp(r'(?:^|,\s*)fk_session=([^;,\s]*)').firstMatch(raw);
    if (match == null) return;
    final value = match.group(1)!;
    cookie = value.isEmpty ? null : value;
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode, {this.code});

  factory ApiException.fromResponse(http.Response response) {
    var message = '请求失败（${response.statusCode}）';
    String? code;
    try {
      final json = jsonDecode(response.body);
      if (json is Map) {
        final error = json['error'];
        if (error is Map) {
          message = error['message'] as String? ?? message;
          code = error['code'] as String?;
        }
        if (json['message'] is String) message = json['message'] as String;
      }
    } catch (_) {}
    return ApiException(message, response.statusCode, code: code);
  }

  final String message;
  final int statusCode;
  final String? code;

  bool get needsLogin => statusCode == 401 || code == 'UNAUTHORIZED';

  @override
  String toString() => message;
}
