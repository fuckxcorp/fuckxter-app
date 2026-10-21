import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<void> bootstrap() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _prefs?.remove('fk_session');
      await _prefs?.remove('fk_account');
    } catch (_) {
      _prefs = null;
    }
    final theme = _prefs?.getString('fk_theme');
    themeMode = switch (theme) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    try {
      api.cookie = await _storage.read(key: 'session');
      if (api.cookie != null) {
        account = await api.me();
        if (account == null) api.cookie = null;
        await _rememberCookie();
      }
    } catch (_) {
      api.cookie = null;
      account = null;
    } finally {
      _readHistory();
      ready = true;
      notifyListeners();
    }
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
    await _rememberCookie();
    await _setAccount(result.account);
    return result;
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    api.cookie = null;
    await _setAccount(null);
    await _storage.delete(key: 'session');
  }

  Future<void> refreshAccount() async {
    final next = await api.me();
    if (next == null) api.cookie = null;
    await _rememberCookie();
    await _setAccount(next);
  }

  Future<void> _rememberCookie() async {
    final value = api.cookie;
    if (value == null || value.isEmpty) {
      await _storage.delete(key: 'session');
    } else {
      try {
        await _storage.write(key: 'session', value: value);
      } catch (_) {
        api.cookie = null;
        await _setAccount(null);
        throw const ApiException('无法访问系统钥匙串，请解锁后重新登录。', 0);
      }
    }
  }

  Future<void> _setAccount(Account? next) async {
    if (account?.profile.handle != next?.profile.handle) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    account = next;
    _readHistory();
    notifyListeners();
  }

  void replaceAccount(Account next) {
    _setAccount(next);
  }

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs?.setString(
      'fk_theme',
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
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
      ...history.where(
        (item) => item.handle != post.author.handle || item.slug != post.slug,
      ),
    ].take(200).toList();
    history = next;
    await _prefs?.setString(
      _historyKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}
