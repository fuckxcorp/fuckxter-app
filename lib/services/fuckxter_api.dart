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
      if (cursor != null) 'cursor': cursor
    });
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw ApiException.fromResponse(response);
    return FeedPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> createPost(String text) async {
    final response = await _client.post(Uri.parse('$origin/posts'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'text': text, 'visibility': 'public'}));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  factory ApiException.fromResponse(http.Response response) {
    var message = '请求失败（${response.statusCode}）';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        message = error['message'] as String? ?? message;
      }
      if (json['message'] is String) message = json['message'] as String;
    } catch (_) {}
    return ApiException(message, response.statusCode);
  }
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}
