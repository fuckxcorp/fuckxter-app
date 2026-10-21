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
  final composerFocus = FocusNode();
  final feeds =
      <
        String,
        ({List<Post> posts, String? cursor, double offset, Object? error})
      >{};
  final search = TextEditingController();
  final posts = <Post>[];
  final media = <PostMedia>[];
  String tab = 'foryou';
  String visibility = 'public';
  String? cursor;
  Object? error;
  bool loading = false;
  bool posting = false;
  bool uploading = false;
  int _generation = 0;
  String? _handle;

  @override
  void initState() {
    super.initState();
    _handle = widget.session.account?.profile.handle;
    widget.session.addListener(_onSession);
    scroll.addListener(() {
      if (scroll.position.extentAfter < 500 &&
          cursor != null &&
          !loading &&
          error == null) {
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
    if (changed) {
      feeds.clear();
      posts.clear();
      if (scroll.hasClients) scroll.jumpTo(0);
      composer.clear();
      media.clear();
      visibility = 'public';
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    scroll.dispose();
    composer.dispose();
    composerFocus.dispose();
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
      if (reset) cursor = null;
    });
    try {
      final page = await widget.session.api.timeline(
        tab: requested,
        cursor: start,
      );
      if (!mounted || generation != _generation || tab != requested) return;
      setState(() {
        if (reset) posts.clear();
        final ids = posts.map((post) => post.id).toSet();
        posts.addAll(page.posts.where((post) => ids.add(post.id)));
        cursor = page.nextCursor == start ? null : page.nextCursor;
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

  void _switchTab(String value) {
    if (tab == value) return;
    if (!loading || posts.isNotEmpty) {
      feeds[tab] = (
        posts: List.of(posts),
        cursor: cursor,
        offset: scroll.hasClients ? scroll.offset : 0,
        error: error,
      );
    }
    final cached = feeds[value];
    setState(() {
      _generation++;
      tab = value;
      posts
        ..clear()
        ..addAll(cached?.posts ?? const []);
      cursor = cached?.cursor;
      error = cached?.error;
      loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tab != value || !scroll.hasClients) return;
      scroll.jumpTo(
        (cached?.offset ?? 0).clamp(0, scroll.position.maxScrollExtent),
      );
    });
    if (cached == null) _load(reset: true);
  }

  Future<void> _compose() async {
    if (scroll.hasClients) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
    if (mounted) composerFocus.requestFocus();
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
    if (text.isEmpty || posting || uploading) return;
    await _guarded(() async {
      if (posting || uploading) return;
      final handle = widget.session.account?.profile.handle;
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
        if (!mounted || widget.session.account?.profile.handle != handle) {
          return;
        }
        composer.clear();
        media.clear();
        feeds.clear();
        FocusManager.instance.primaryFocus?.unfocus();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已发布')));
        await _load(reset: true);
      } catch (error) {
        if (mounted) showError(context, error);
      } finally {
        if (mounted) setState(() => posting = false);
      }
    });
  }

  Future<void> _attach() async {
    if (uploading || posting) return;
    await _guarded(() async {
      if (uploading || posting) return;
      final handle = widget.session.account?.profile.handle;
      setState(() => uploading = true);
      try {
        final picked = await FilePicker.pickFiles(type: FileType.image);
        if (picked.isEmpty || !mounted) return;
        for (final file in picked) {
          if (!mounted || widget.session.account?.profile.handle != handle) {
            return;
          }
          if (media.length >= 10) {
            showError(context, '最多 10 张图片');
            break;
          }
          final bytes = await readPickedImage(file);
          if (!mounted || widget.session.account?.profile.handle != handle) {
            return;
          }
          final uploaded = await widget.session.api.uploadMedia(
            bytes: bytes,
            name: file.name,
            contentType: imageType(file.name) ?? 'image/jpeg',
          );
          if (!mounted || widget.session.account?.profile.handle != handle) {
            return;
          }
          setState(() => media.add(uploaded));
        }
      } catch (error) {
        if (mounted) showError(context, error);
      } finally {
        if (mounted) setState(() => uploading = false);
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
    if (!widget.session.ready) {
      return const Scaffold(body: SafeArea(child: LoadingPane()));
    }
    final compact = MediaQuery.sizeOf(context).width < 720;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      floatingActionButton: compact && !keyboard
          ? FloatingActionButton.small(
              tooltip: '撰写帖子',
              onPressed: _compose,
              child: const Icon(CupertinoIcons.square_pencil),
            )
          : null,
      bottomNavigationBar: compact && !keyboard
          ? NavigationBar(
              selectedIndex: 0,
              height: 64,
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    if (scroll.hasClients) {
                      scroll.animateTo(
                        0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      );
                    }
                  case 1:
                    openSearch(context, widget.session, search.text);
                  case 2:
                    _openAccount('notices');
                  case 3:
                    _openAccount('messages');
                  case 4:
                    _openAccount('saved');
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(CupertinoIcons.house),
                  selectedIcon: Icon(CupertinoIcons.house_fill),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(CupertinoIcons.search),
                  label: '搜索',
                ),
                NavigationDestination(
                  icon: Icon(CupertinoIcons.bell),
                  label: '通知',
                ),
                NavigationDestination(
                  icon: Icon(CupertinoIcons.envelope),
                  label: '私信',
                ),
                NavigationDestination(
                  icon: Icon(CupertinoIcons.bookmark),
                  label: '收藏',
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              search: search,
              tab: tab,
              account: account,
              imageHeaders: widget.session.api.imageHeaders,
              onSearch: () => openSearch(context, widget.session, search.text),
              onTab: _switchTab,
              onAccount: _openAccount,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: CustomScrollView(
                  controller: scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Composer(
                        controller: composer,
                        focusNode: composerFocus,
                        posting: posting,
                        visibility: visibility,
                        media: media,
                        api: widget.session.api,
                        uploading: uploading,
                        onRemove: (id) => setState(
                          () => media.removeWhere((item) => item.id == id),
                        ),
                        avatarUrl: account?.avatarUrl == null
                            ? null
                            : account!.avatarUrl!,
                        imageHeaders: widget.session.api.imageHeaders,
                        name: account?.profile.name ?? '?',
                        onVisibility: (value) =>
                            setState(() => visibility = value),
                        onAttach: _attach,
                        onSubmit: _submit,
                      ),
                    ),
                    if (posts.isEmpty && loading)
                      SliverList.list(
                        children: const [
                          _PostPlaceholder(),
                          _PostPlaceholder(),
                          _PostPlaceholder(),
                        ],
                      )
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
                    else if (posts.isEmpty)
                      const SliverFillRemaining(
                        child: EmptyHint('还没有帖子，发出第一条动态吧'),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 8 : 16,
                          12,
                          compact ? 8 : 16,
                          0,
                        ),
                        sliver: SliverList.builder(
                          itemCount: posts.length,
                          itemBuilder: (_, index) {
                            final post = posts[index];
                            return RepaintBoundary(
                              key: ValueKey(post.id),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 680,
                                  ),
                                  child: PostCard(
                                    post: post,
                                    session: widget.session,
                                    onChanged: (next) => setState(() {
                                      final i = posts.indexWhere(
                                        (item) => item.id == next.id,
                                      );
                                      if (i >= 0) posts[i] = next;
                                      for (final feed in feeds.values) {
                                        final i = feed.posts.indexWhere(
                                          (item) => item.id == next.id,
                                        );
                                        if (i >= 0) feed.posts[i] = next;
                                      }
                                    }),
                                    onDeleted: () => setState(() {
                                      posts.removeWhere(
                                        (item) => item.id == post.id,
                                      );
                                      for (final feed in feeds.values) {
                                        feed.posts.removeWhere(
                                          (item) => item.id == post.id,
                                        );
                                      }
                                    }),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 96,
                        child: Center(
                          child: loading && posts.isNotEmpty
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : error != null
                              ? TextButton(
                                  onPressed: () => _load(reset: cursor == null),
                                  child: const Text('加载失败，点击重试'),
                                )
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
          ],
        ),
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
    final tabs = <Widget>[
      _Tab(label: '推荐', value: 'foryou', selected: tab, onTap: onTab),
      _Tab(label: '实时', value: 'latest', selected: tab, onTap: onTab),
      _Tab(label: '关注', value: 'following', selected: tab, onTap: onTab),
    ];
    final menu = PopupMenuButton<String>(
      tooltip: '账号',
      onSelected: onAccount,
      itemBuilder: (_) => [
        if (account == null)
          const PopupMenuItem(value: 'login', child: Text('登录 / 注册'))
        else
          PopupMenuItem(
            value: 'profile',
            child: Text('@${account!.profile.handle}'),
          ),
        const PopupMenuItem(value: 'notices', child: Text('通知')),
        const PopupMenuItem(value: 'messages', child: Text('私信')),
        const PopupMenuItem(value: 'saved', child: Text('收藏')),
        const PopupMenuItem(value: 'history', child: Text('浏览记录')),
        const PopupMenuItem(value: 'settings', child: Text('设置')),
        const PopupMenuItem(value: 'theme', child: Text('切换主题')),
      ],
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        alignment: Alignment.center,
        child: account == null
            ? Icon(
                CupertinoIcons.person,
                color: Theme.of(context).colorScheme.onSurface,
              )
            : Avatar(
                name: account!.profile.name,
                size: 32,
                headers: imageHeaders,
                url: account!.avatarUrl,
              ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, size) {
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
            return Column(
              children: [
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: BrandMark(),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '搜索',
                      onPressed: onSearch,
                      icon: const Icon(CupertinoIcons.search),
                    ),
                    menu,
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [for (final item in tabs) Expanded(child: item)],
                  ),
                ),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 0, 8),
            child: Row(
              children: [
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
                Row(mainAxisSize: MainAxisSize.min, children: tabs),
                menu,
              ],
            ),
          );
        },
      ),
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
    return Semantics(
      selected: active,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [const Color(0xFFF2F4F6), const Color(0xFFBDC6D1)]
                        : [const Color(0xFF101215), const Color(0xFF465362)],
                  )
                : null,
            border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.outline
                  : Colors.transparent,
            ),
          ),
          child: TextButton(
            onPressed: () => onTap(value),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 44),
              foregroundColor: active
                  ? (dark ? Colors.black : Colors.white)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.posting,
    required this.visibility,
    required this.media,
    required this.api,
    required this.uploading,
    required this.onRemove,
    required this.name,
    required this.avatarUrl,
    required this.imageHeaders,
    required this.onVisibility,
    required this.onAttach,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool posting;
  final String visibility;
  final List<PostMedia> media;
  final FuckXterApi api;
  final bool uploading;
  final ValueChanged<String> onRemove;
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
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(
                name: name,
                size: 42,
                url: avatarUrl,
                headers: imageHeaders,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !posting,
                      maxLength: 1000,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: '有什么新鲜事？',
                        counterStyle: TextStyle(fontSize: 11),
                        border: InputBorder.none,
                      ),
                    ),
                    if (media.isNotEmpty)
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: media.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, index) => SizedBox(
                            width: 96,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: NetImage(
                                    url: media[index].url,
                                    fit: BoxFit.cover,
                                    width: 96,
                                    height: 96,
                                    headers: api.imageHeaders,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton.filled(
                                    tooltip: '移除图片',
                                    onPressed: posting || uploading
                                        ? null
                                        : () => onRemove(media[index].id),
                                    icon: const Icon(Icons.close, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: '添加图片',
                          onPressed: uploading || posting ? null : onAttach,
                          icon: const Icon(CupertinoIcons.paperclip, size: 20),
                        ),
                        if (uploading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        PopupMenuButton<String>(
                          tooltip: '帖子可见范围',
                          enabled: !posting && !uploading,
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
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (_, value, __) => FilledButton(
                            onPressed:
                                posting ||
                                    uploading ||
                                    value.text.trim().isEmpty
                                ? null
                                : onSubmit,
                            child: Text(posting ? '发送中…' : '发帖'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostPlaceholder extends StatelessWidget {
  const _PostPlaceholder();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: color),
                    const SizedBox(height: 16),
                    Container(height: 12, color: color),
                    const SizedBox(height: 8),
                    Container(height: 12, color: color),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: .65,
                      child: Container(height: 12, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
