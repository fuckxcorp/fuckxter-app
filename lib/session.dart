import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';
import 'services/fuckxter_api.dart';

class AppSession extends ChangeNotifier {
  AppSession({FuckXterApi? api}) : api = api ?? FuckXterApi();

  final FuckXterApi api;
  Account? account;
  ThemeMode themeMode = ThemeMode.system;
  List<HistoryItem> history = const [];
  bool ready = false;
  SharedPreferences? _prefs;

  Future<void> bootstrap() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
    final stored = _prefs?.getString('fk_session');
    if (stored != null && stored.isNotEmpty) api.cookie = stored;
    final theme = _prefs?.getString('fk_theme');
    themeMode = switch (theme) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    _readHistory();
    final cached = _prefs?.getString('fk_account');
    if (cached != null) {
      try {
        account = Account.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
    if (api.cookie == null) return;
    try {
      final next = await api.me();
      _rememberCookie();
      await _setAccount(next);
    } catch (_) {}
  }

  Future<({Account account, bool restored})> login({
    required String identifier,
    required String password,
    String? code,
    String? recoveryCode,
  }) async {
    final result = await api.login(
      identifier: identifier,
      password: password,
      code: code,
      recoveryCode: recoveryCode,
    );
    _rememberCookie();
    await _setAccount(result.account);
    return result;
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    api.cookie = null;
    await _prefs?.remove('fk_session');
    await _setAccount(null);
  }

  Future<void> refreshAccount() async {
    final next = await api.me();
    _rememberCookie();
    await _setAccount(next);
  }

  void _rememberCookie() {
    final value = api.cookie;
    if (value == null || value.isEmpty) {
      _prefs?.remove('fk_session');
    } else {
      _prefs?.setString('fk_session', value);
    }
  }

  Future<void> _setAccount(Account? next) async {
    account = next;
    if (next == null) {
      await _prefs?.remove('fk_account');
    } else {
      await _prefs?.setString(
        'fk_account',
        jsonEncode({
          'profile': {
            'name': next.profile.name,
            'handle': next.profile.handle,
            'bio': next.profile.bio,
            'email': next.profile.email,
            'region': next.profile.region,
            'gender': next.profile.gender,
            'birthday': next.profile.birthday,
          },
          'avatarUrl': next.avatarUrl,
          'headerUrl': next.headerUrl,
          'twoFactorEnabled': next.twoFactorEnabled,
          'recoveryCodeCount': next.recoveryCodeCount,
          'dmPolicy': next.dmPolicy,
          'createdAt': next.createdAt,
        }),
      );
    }
    _readHistory();
    notifyListeners();
  }

  void replaceAccount(Account next) {
    account = next;
    notifyListeners();
    _setAccount(next);
  }

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs?.setString(
        'fk_theme', themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  String get _historyKey => 'fk_history:${account?.profile.handle ?? 'guest'}';

  void _readHistory() {
    final raw = _prefs?.getString(_historyKey);
    if (raw == null) {
      history = const [];
      return;
    }
    try {
      final items = jsonDecode(raw) as List<dynamic>;
      history = items
          .whereType<Map>()
          .map((item) => HistoryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      history = const [];
    }
  }

  Future<void> rememberPost(Post post) async {
    if (post.slug.isEmpty || post.author.handle.isEmpty) return;
    final next = [
      HistoryItem(
        handle: post.author.handle,
        slug: post.slug,
        name: post.author.name,
        text: post.text,
        at: DateTime.now().toIso8601String(),
      ),
      ...history.where((item) =>
          item.handle != post.author.handle || item.slug != post.slug),
    ].take(200).toList();
    history = next;
    await _prefs?.setString(
        _historyKey, jsonEncode(next.map((item) => item.toJson()).toList()));
    notifyListeners();
  }
}
