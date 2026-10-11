import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/fuckxter_api.dart';
import '../session.dart';
import '../widgets/bits.dart';
import '../widgets/post_card.dart';
import 'flows.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});
  final AppSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final scroll = ScrollController();
  final composer = TextEditingController();
  final search = TextEditingController();
  final posts = <Post>[];
  final media = <PostMedia>[];
  String tab = 'foryou';
  String visibility = 'public';
  String? cursor;
  Object? error;
  bool loading = false;
  bool posting = false;
  int _generation = 0;
  String? _handle;

  @override
  void initState() {
    super.initState();
    _handle = widget.session.account?.profile.handle;
    widget.session.addListener(_onSession);
    scroll.addListener(() {
      if (scroll.position.extentAfter < 500 && cursor != null && !loading) {
        _load();
      }
    });
    _load(reset: true);
  }

  void _onSession() {
    if (!mounted) return;
    final handle = widget.session.account?.profile.handle;
    final changed = handle != _handle;
    _handle = handle;
    setState(() {});
    if (changed) _load(reset: true);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    scroll.dispose();
    composer.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && loading) return;
    final generation = ++_generation;
    final requested = tab;
    final start = reset ? null : cursor;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        posts.clear();
        cursor = null;
      }
    });
    try {
      final page =
          await widget.session.api.timeline(tab: requested, cursor: start);
      if (!mounted || generation != _generation || tab != requested) return;
      setState(() {
        posts.addAll(page.posts);
        cursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => this.error = error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (widget.session.account == null) {
      final ok = await openLogin(context, widget.session);
      if (!ok || !mounted) return;
    }
    await action();
  }

  Future<void> _submit() async {
    final text = composer.text.trim();
    if (text.isEmpty || posting) return;
    await _guarded(() async {
      setState(() => posting = true);
      try {
        await widget.session.api.createPost(
          text,
          mediaIds: media
              .map((item) => item.id)
              .where((id) => id.isNotEmpty)
              .toList(),
          visibility: visibility,
        );
        composer.clear();
        media.clear();
        await _load(reset: true);
      } catch (error) {
        if (mounted) showError(context, error);
      } finally {
        if (mounted) setState(() => posting = false);
      }
    });
  }

  Future<void> _attach() async {
    await _guarded(() async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (picked == null || !mounted) return;
      try {
        for (final file in picked.files) {
          if (media.length >= 10) {
            if (mounted) showError(context, '最多 10 张图片');
            break;
          }
          final bytes = file.bytes;
          if (bytes == null) continue;
          final uploaded = await widget.session.api.uploadMedia(
            bytes: bytes,
            name: file.name,
            contentType: imageType(file.name) ?? 'image/jpeg',
          );
          if (mounted) setState(() => media.add(uploaded));
        }
      } catch (error) {
        if (mounted) showError(context, error);
      }
    });
  }

  Future<void> _openAccount(String value) async {
    switch (value) {
      case 'login':
        await openLogin(context, widget.session);
      case 'theme':
        widget.session.toggleTheme();
      case 'notices':
        await _guarded(() async => openNotices(context, widget.session));
      case 'messages':
        await _guarded(() async => openMessages(context, widget.session));
      case 'saved':
        await _guarded(() async => openSaved(context, widget.session));
      case 'history':
        openHistory(context, widget.session);
      case 'settings':
        openSettings(context, widget.session);
      case 'profile':
        final handle = widget.session.account?.profile.handle;
        if (handle != null) openProfile(context, widget.session, handle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.session.account;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _TopBar(
            search: search,
            tab: tab,
            account: account,
            imageHeaders: widget.session.api.imageHeaders,
            onSearch: () => openSearch(context, widget.session, search.text),
            onTab: (value) {
              if (tab == value) return;
              setState(() => tab = value);
              _load(reset: true);
            },
            onAccount: _openAccount,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: CustomScrollView(
                controller: scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: _Composer(
                      controller: composer,
                      posting: posting,
                      visibility: visibility,
                      mediaCount: media.length,
                      avatarUrl: account?.avatarUrl == null
                          ? null
                          : widget.session.api
                              .mediaUri(account!.avatarUrl!)
                              .toString(),
                      imageHeaders: widget.session.api.imageHeaders,
                      name: account?.profile.name ?? '?',
                      onVisibility: (value) =>
                          setState(() => visibility = value),
                      onAttach: _attach,
                      onSubmit: _submit,
                    ),
                  ),
                  if (posts.isEmpty && loading)
                    const SliverFillRemaining(child: LoadingPane())
                  else if (posts.isEmpty && error != null)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$error'),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _load(reset: true),
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (_, index) {
                          final post = posts[index];
                          return RepaintBoundary(
                            key: ValueKey(post.id),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 680),
                                child: PostCard(
                                  post: post,
                                  session: widget.session,
                                  onChanged: (next) =>
                                      setState(() => posts[index] = next),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 72,
                      child: Center(
                        child: loading && posts.isNotEmpty
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Text(
                                cursor == null && posts.isNotEmpty
                                    ? '你已看完全部内容'
                                    : '',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.search,
    required this.tab,
    required this.account,
    required this.imageHeaders,
    required this.onSearch,
    required this.onTab,
    required this.onAccount,
  });

  final TextEditingController search;
  final String tab;
  final Account? account;
  final Map<String, String> imageHeaders;
  final VoidCallback onSearch;
  final ValueChanged<String> onTab;
  final ValueChanged<String> onAccount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tabs = Row(mainAxisSize: MainAxisSize.min, children: [
      _Tab(label: '推荐', value: 'foryou', selected: tab, onTap: onTab),
      _Tab(label: '实时', value: 'latest', selected: tab, onTap: onTab),
      _Tab(label: '关注', value: 'following', selected: tab, onTap: onTab),
    ]);
    final menu = PopupMenuButton<String>(
      tooltip: '账号',
      onSelected: onAccount,
      itemBuilder: (_) => [
        if (account == null)
          const PopupMenuItem(value: 'login', child: Text('登录 / 注册'))
        else
          PopupMenuItem(
              value: 'profile', child: Text('@${account!.profile.handle}')),
        const PopupMenuItem(value: 'notices', child: Text('通知')),
        const PopupMenuItem(value: 'messages', child: Text('私信')),
        const PopupMenuItem(value: 'saved', child: Text('收藏')),
        const PopupMenuItem(value: 'history', child: Text('浏览记录')),
        const PopupMenuItem(value: 'settings', child: Text('设置')),
        const PopupMenuItem(value: 'theme', child: Text('切换主题')),
      ],
      child: Container(
        width: 62,
        height: 48,
        color: dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215),
        alignment: Alignment.center,
        child: account == null
            ? Icon(CupertinoIcons.person,
                color: dark ? Colors.black : Colors.white)
            : Avatar(
                name: account!.profile.name,
                size: 32,
                headers: imageHeaders,
                url: account!.avatarUrl == null
                    ? null
                    : FuckXterApi.media(account!.avatarUrl!),
              ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: LayoutBuilder(builder: (context, size) {
        final compact = size.maxWidth < 720;
        final field = TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.search, size: 18),
            hintText: '搜索 FuckXter',
            border: InputBorder.none,
          ),
        );
        if (compact) {
          return Column(children: [
            Row(children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: BrandMark(),
              ),
              const Spacer(),
              menu,
            ]),
            tabs,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: field,
            ),
          ]);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 0, 8),
          child: Row(children: [
            const BrandMark(),
            const SizedBox(width: 28),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: field,
                ),
              ),
            ),
            tabs,
            menu,
          ]),
        );
      }),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: () => onTap(value),
      style: TextButton.styleFrom(
        foregroundColor: active
            ? (dark ? Colors.black : Colors.white)
            : Theme.of(context).colorScheme.onSurfaceVariant,
        backgroundColor: active
            ? (dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215))
            : Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label,
          style: TextStyle(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.posting,
    required this.visibility,
    required this.mediaCount,
    required this.name,
    required this.avatarUrl,
    required this.imageHeaders,
    required this.onVisibility,
    required this.onAttach,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool posting;
  final String visibility;
  final int mediaCount;
  final String name;
  final String? avatarUrl;
  final Map<String, String> imageHeaders;
  final ValueChanged<String> onVisibility;
  final VoidCallback onAttach;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(
              name: name,
              size: 42,
              url: avatarUrl,
              headers: imageHeaders,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(children: [
                TextField(
                  controller: controller,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '有什么新鲜事？',
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
                Row(children: [
                  IconButton(
                    onPressed: onAttach,
                    icon: const Icon(CupertinoIcons.paperclip, size: 20),
                  ),
                  if (mediaCount > 0) Text('$mediaCount 张图片'),
                  PopupMenuButton<String>(
                    initialValue: visibility,
                    onSelected: onVisibility,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'public', child: Text('公开')),
                      PopupMenuItem(value: 'mutual', child: Text('互关可见')),
                      PopupMenuItem(value: 'private', child: Text('仅自己')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(visibilityLabel(visibility)),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: posting ? null : onSubmit,
                    child: Text(posting ? '发送中…' : '发帖'),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
