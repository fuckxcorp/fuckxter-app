import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/post.dart';

class FuckXterApi {
  FuckXterApi({http.Client? client}) : _client = client ?? http.Client();

  static const origin = 'https://api.fuckxter.site';
  final http.Client _client;

  Uri mediaUri(String path) =>
      Uri.parse(path.startsWith('http') ? path : '$origin$path');

  Future<FeedPage> timeline({required String tab, String? cursor}) async {
    final uri = Uri.parse('$origin/timeline').replace(queryParameters: {
      'tab': tab,
      'limit': '10',
      if (cursor != null) 'cursor': cursor,
    });
    return FeedPage.fromJson(await _json('GET', uri));
  }

  Future<SearchResult> search(String query) async {
    final uri = Uri.parse('$origin/search').replace(queryParameters: {'q': query});
    return SearchResult.fromJson(await _json('GET', uri));
  }

  Future<void> createPost(String text) async {
    await _json('POST', Uri.parse('$origin/posts'),
        body: {'text': text, 'visibility': 'public'});
  }

  Future<Map<String, dynamic>> like(String id, bool active) =>
      _json(active ? 'PUT' : 'DELETE', Uri.parse('$origin/posts/$id/like'));

  Future<Map<String, dynamic>> repost(String id, bool active) =>
      _json(active ? 'PUT' : 'DELETE', Uri.parse('$origin/posts/$id/repost'));

  Future<void> save(String id, bool active) async {
    await _json(active ? 'PUT' : 'DELETE', Uri.parse('$origin/posts/$id/save'));
  }

  Future<Map<String, dynamic>> _json(String method, Uri uri,
      {Map<String, dynamic>? body}) async {
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _client.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromJson(json, response.statusCode);
    }
    return json;
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  factory ApiException.fromJson(Map<String, dynamic> json, int statusCode) {
    final error = json['error'];
    final message = error is Map<String, dynamic>
        ? error['message'] as String?
        : json['message'] as String?;
    return ApiException(message ?? '请求失败（$statusCode）', statusCode);
  }

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
