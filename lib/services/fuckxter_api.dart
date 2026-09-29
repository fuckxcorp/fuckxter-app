import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/post.dart';

class FuckXterApi {
  FuckXterApi._(this._dio);

  static const origin = 'https://api.fuckxter.site';
  final Dio _dio;

  static Future<FuckXterApi> create() async {
    final directory = await getApplicationDocumentsDirectory();
    final jar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${directory.path}/.fuckxter_cookies/'),
    );
    final dio = Dio(BaseOptions(
      baseUrl: origin,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      validateStatus: (_) => true,
    ));
    dio.interceptors.add(CookieManager(jar));
    return FuckXterApi._(dio);
  }

  Uri mediaUri(String path) =>
      Uri.parse(path.startsWith('http') ? path : '$origin$path');

  Future<Map<String, dynamic>> _json(String method, String path,
      {Map<String, dynamic>? query, Map<String, dynamic>? body}) async {
    final response = await _dio.request<dynamic>(
      path,
      queryParameters: query,
      data: body,
      options: Options(method: method, contentType: Headers.jsonContentType),
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiException.fromJson(data, status);
    }
    return data;
  }

  Future<Account?> me() async {
    final data = await _json('GET', '/auth/me');
    final account = data['account'];
    return account is Map ? Account.fromJson(Map<String, dynamic>.from(account)) : null;
  }

  Future<Account> signIn(String identifier, String password,
      {String? code, String? recoveryCode}) async {
    final data = await _json('POST', '/auth/login', body: {
      'identifier': identifier,
      'password': password,
      if (code != null && code.isNotEmpty) 'code': code,
      if (recoveryCode != null && recoveryCode.isNotEmpty)
        'recoveryCode': recoveryCode,
    });
    return Account.fromJson(Map<String, dynamic>.from(data['account'] as Map));
  }

  Future<void> signOut() async => _json('POST', '/auth/logout');

  Future<FeedPage> timeline({required String tab, String? cursor}) async =>
      FeedPage.fromJson(await _json('GET', '/timeline', query: {
        'tab': tab,
        'limit': '10',
        if (cursor != null) 'cursor': cursor,
      }));

  Future<SearchResult> search(String query) async => SearchResult.fromJson(
      await _json('GET', '/search', query: {'q': query}));

  Future<void> createPost(String text) async => _json('POST', '/posts',
      body: {'text': text, 'visibility': 'public'});

  Future<Map<String, dynamic>> like(String id, bool active) =>
      _json(active ? 'PUT' : 'DELETE', '/posts/$id/like');

  Future<Map<String, dynamic>> repost(String id, bool active) =>
      _json(active ? 'PUT' : 'DELETE', '/posts/$id/repost');

  Future<void> save(String id, bool active) async =>
      _json(active ? 'PUT' : 'DELETE', '/posts/$id/save');

  Future<List<Post>> savedPosts() async {
    final data = await _json('GET', '/me/saved');
    return (data['posts'] as List<dynamic>? ?? const [])
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<UserProfile> profile(String handle) async {
    final data = await _json('GET', '/users/${Uri.encodeComponent(handle)}');
    return UserProfile.fromJson(
        Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<List<Post>> userPosts(String handle) async {
    final data =
        await _json('GET', '/users/${Uri.encodeComponent(handle)}/posts');
    return (data['posts'] as List<dynamic>? ?? const [])
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> follow(String handle, bool active) async =>
      _json(active ? 'PUT' : 'DELETE',
          '/users/${Uri.encodeComponent(handle)}/follow');

  Future<Map<String, dynamic>> comments(String postId) =>
      _json('GET', '/posts/$postId/comments');

  Future<void> comment(String postId, String text) async =>
      _json('POST', '/posts/$postId/comments', body: {'text': text});

  Future<Map<String, dynamic>> notifications() =>
      _json('GET', '/notice', query: {'limit': '30'});

  Future<void> markNotificationsRead() async =>
      _json('POST', '/notice', body: {});

  Future<Map<String, dynamic>> conversations() => _json('GET', '/messages');

  Future<Map<String, dynamic>> conversation(String handle) =>
      _json('GET', '/messages/${Uri.encodeComponent(handle)}');

  Future<void> sendMessage(String handle, String text) async => _json(
      'POST', '/messages/${Uri.encodeComponent(handle)}',
      body: {'text': text, 'id': DateTime.now().microsecondsSinceEpoch.toString()});
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode, [this.code]);

  factory ApiException.fromJson(Map<String, dynamic> json, int statusCode) {
    final error = json['error'];
    final detail =
        error is Map ? Map<String, dynamic>.from(error) : <String, dynamic>{};
    return ApiException(
      detail['message'] as String? ??
          json['message'] as String? ??
          '请求失败（$statusCode）',
      statusCode,
      detail['code'] as String?,
    );
  }

  final String message;
  final int statusCode;
  final String? code;

  @override
  String toString() => message;
}
