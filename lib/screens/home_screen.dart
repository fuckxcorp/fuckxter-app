import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/fuckxter_api.dart';
import '../session.dart';
import '../widgets/bits.dart';
import '../widgets/post_card.dart';
import '../widgets/fx_controls.dart';
import '../widgets/fx_motion.dart';
import '../widgets/fx_account_menu.dart';
import 'flows.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});
  final AppSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final scroll = ScrollController();
  final pages = PageController();
  late final exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool opening = false;
  final searchFocus = FocusNode();
  int section = 0;
  int? destination;
  int navigation = 0;
  String query = '';
  bool collapsed = false;
  double lastOffset = 0;
  double scrollTravel = 0;
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
  late String tab = widget.session.feedTab;
  String visibility = 'public';
  String? cursor;
  Object? error;
  bool loading = false;
  bool posting = false;
  bool uploading = false;
  int _generation = 0;
  String? _handle;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _handle = widget.session.account?.profile.handle;
    _ready = widget.session.ready;
    widget.session.addListener(_onSession);
    scroll.addListener(_onScroll);
    if (_ready) _load(reset: true);
  }

  void _onScroll() {
    if (section != 0 || !scroll.hasClients) return;
    final offset = scroll.offset;
    final delta = offset - lastOffset;
    lastOffset = offset;
    if (delta.abs() > .5) {
      if (delta.sign != scrollTravel.sign) scrollTravel = 0;
      scrollTravel += delta;
      final next =
          offset > 80 &&
          (scrollTravel > 28 || (collapsed && scrollTravel > -16));
      if (next != collapsed) setState(() => collapsed = next);
    }
    if (scroll.position.extentAfter < 500 &&
        cursor != null &&
        !loading &&
        error == null) {
      _load();
    }
  }

  Future<void> _selectSection(int index, {bool focus = false}) async {
    if (index == 4) {
      final value = await showFxAccountMenu(
        context,
        widget.session.account,
        widget.session.api.imageHeaders,
      );
      if (value != null && mounted) await _openAccount(value);
      return;
    }
    if (index == section && index == 0 && scroll.hasClients) {
      await _composeScroll();
      return;
    }
    final request = ++navigation;
    destination = index;
    setState(() {
      section = index;
      collapsed = false;
    });
    if (index != 1) FocusManager.instance.primaryFocus?.unfocus();
    if (pages.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        pages.jumpToPage(index);
      } else {
        await pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (!mounted || request != navigation) return;
    destination = null;
    if (index == 1 && focus) searchFocus.requestFocus();
  }

  void _showSearch() => _selectSection(1, focus: true);

  void _search() {
    setState(() => query = search.text.trim());
    _selectSection(1);
    searchFocus.unfocus();
  }

  Future<void> _composeScroll() async {
    setState(() => collapsed = false);
    if (scroll.hasClients) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSession() {
    if (!mounted) return;
    final handle = widget.session.account?.profile.handle;
    final changed = handle != _handle;
    final becameReady = !_ready && widget.session.ready;
    _ready = widget.session.ready;
    if (becameReady) tab = widget.session.feedTab;
    _handle = handle;
    setState(() {});
    if (changed || becameReady) {
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
    pages.dispose();
    exit.dispose();
    searchFocus.dispose();
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
    widget.session.rememberFeedTab(value);
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
        await _selectSection(2);
      case 'messages':
        await _selectSection(3);
      case 'saved':
        await _guarded(() async {
          openSaved(context, widget.session);
        });
      case 'history':
        openHistory(context, widget.session);
      case 'settings':
        openSettings(context, widget.session);
      case 'profile':
        final handle = widget.session.account?.profile.handle;
        if (handle != null) openProfile(context, widget.session, handle);
    }
  }

  Future<void> _openFeedPost(Post post) async {
    if (opening) return;
    opening = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!MediaQuery.disableAnimationsOf(context)) await exit.forward();
    if (!mounted) return;
    void restore() {
      if (mounted) {
        exit.value = 0;
        opening = false;
      }
    }

    openPost(context, widget.session, post, onCovered: restore);
  }

  Widget _accountIcon() {
    final account = widget.session.account;
    return account == null
        ? const Icon(CupertinoIcons.person_crop_circle, size: 24)
        : Avatar(
            name: account.profile.name,
            size: 24,
            headers: widget.session.api.imageHeaders,
            url: account.avatarUrl,
          );
  }

  Widget _page(int index, bool compact) {
    if (index == 0) {
      return AnimatedBuilder(
        animation: exit,
        child: _feed(compact),
        builder: (context, child) => IgnorePointer(
          ignoring: opening,
          child: Opacity(
            opacity: 1 - exit.value,
            child: Transform.translate(
              offset: Offset(8 * exit.value, 6 * exit.value),
              child: child,
            ),
          ),
        ),
      );
    }
    if (index == 1) {
      return SearchScreen(
        session: widget.session,
        query: query,
        embedded: true,
      );
    }
    if (widget.session.account == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('登录后查看${fxLabels[index]}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => openLogin(context, widget.session),
              child: const Text('登录 / 注册'),
            ),
          ],
        ),
      );
    }
    return switch (index) {
      2 => NoticesScreen(
        session: widget.session,
        embedded: true,
        active: section == 2,
      ),
      3 => MessagesScreen(
        session: widget.session,
        embedded: true,
        active: section == 3,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _feed(bool compact) => RefreshIndicator(
    onRefresh: () => _load(reset: true),
    child: CustomScrollView(
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            onRemove: (id) =>
                setState(() => media.removeWhere((item) => item.id == id)),
            avatarUrl: widget.session.account?.avatarUrl,
            imageHeaders: widget.session.api.imageHeaders,
            name: widget.session.account?.profile.name ?? '?',
            onVisibility: (value) => setState(() => visibility = value),
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
          const SliverFillRemaining(child: EmptyHint('还没有帖子，发出第一条动态吧'))
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
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: FxReveal(
                        delay: Duration(
                          milliseconds: (index * 36).clamp(0, 180),
                        ),
                        child: PostCard(
                          post: post,
                          onOpen: () => _openFeedPost(post),
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
                            posts.removeWhere((item) => item.id == post.id);
                            for (final feed in feeds.values) {
                              feed.posts.removeWhere(
                                (item) => item.id == post.id,
                              );
                            }
                          }),
                        ),
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
                  : Text(cursor == null && posts.isNotEmpty ? '你已看完全部内容' : ''),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.session.ready) {
      return const Scaffold(body: SafeArea(child: LoadingPane()));
    }
    final compact = MediaQuery.sizeOf(context).width < 720;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      extendBody: true,
      floatingActionButton: compact && !keyboard && section == 0
          ? FloatingActionButton.small(
              tooltip: '撰写帖子',
              onPressed: _compose,
              child: const Icon(CupertinoIcons.square_pencil),
            )
          : null,
      bottomNavigationBar: compact && !keyboard
          ? FxNavigationBar(
              selected: section,
              accountIcon: _accountIcon(),
              onChanged: (index) => _selectSection(index, focus: index == 1),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              search: search,
              searchFocus: searchFocus,
              tab: tab,
              section: section,
              collapsed: compact && collapsed,
              onSearch: _showSearch,
              onSubmit: _search,
              onCloseSearch: () => _selectSection(0),
              onExpand: () => setState(() {
                collapsed = false;
                scrollTravel = 0;
              }),
              onHome: () => _selectSection(0),
              onTab: _switchTab,
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: compact ? 0 : 82,
                    child: Offstage(
                      offstage: compact,
                      child: FxSidebar(
                        selected: section,
                        accountIcon: _accountIcon(),
                        onChanged: (index) =>
                            _selectSection(index, focus: index == 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (event) {
                        if (event.dragDetails != null && event.depth == 0) {
                          destination = null;
                          navigation++;
                        }
                        return false;
                      },
                      child: PageView.builder(
                        key: const ValueKey('home-pages'),
                        controller: pages,
                        itemCount: fxLabels.length - 1,
                        onPageChanged: (index) {
                          if (destination != null) return;
                          setState(() {
                            section = index;
                            collapsed = false;
                          });
                          if (index != 1) searchFocus.unfocus();
                        },
                        itemBuilder: (_, index) => _KeepAlivePage(
                          key: ValueKey('section-$index-${_handle ?? 'guest'}'),
                          child: TickerMode(
                            enabled: section == index,
                            child: _page(index, compact),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});
  final Widget child;
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.search,
    required this.searchFocus,
    required this.tab,
    required this.section,
    required this.collapsed,
    required this.onSearch,
    required this.onSubmit,
    required this.onCloseSearch,
    required this.onExpand,
    required this.onHome,
    required this.onTab,
  });
  final TextEditingController search;
  final FocusNode searchFocus;
  final String tab;
  final int section;
  final bool collapsed;
  final VoidCallback onSearch, onSubmit, onCloseSearch, onExpand, onHome;
  final ValueChanged<String> onTab;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final searching = section == 1;
    final field = TextField(
      key: const ValueKey('inline-search'),
      controller: search,
      focusNode: searchFocus,
      textInputAction: TextInputAction.search,
      onTap: compact ? null : onSearch,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.search, size: 18),
        hintText: '搜索 FuckXter',
        border: InputBorder.none,
        suffixIcon: searching
            ? IconButton(
                tooltip: '关闭搜索',
                onPressed: onCloseSearch,
                icon: const Icon(CupertinoIcons.xmark, size: 18),
              )
            : null,
      ),
    );
    final feedTabs = FxTabs(
      labels: const ['推荐', '实时', '关注'],
      selected: ['foryou', 'latest', 'following'].indexOf(tab),
      onChanged: (index) => onTab(['foryou', 'latest', 'following'][index]),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              if (!compact || !searching)
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: GestureDetector(
                    onTap: onHome,
                    child: const BrandMark(),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: searching
                        ? FxSurface(radius: 14, child: field)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              if (!compact && section == 0)
                SizedBox(width: 240, child: feedTabs),
            ],
          ),
        ),
        if (compact && section == 0)
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: collapsed
                  ? SizedBox(
                      height: 28,
                      child: Center(
                        child: Semantics(
                          button: true,
                          label: '展开信息流选项',
                          child: InkWell(
                            key: const ValueKey('collapsed-feed-tabs'),
                            onTap: onExpand,
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Icon(CupertinoIcons.ellipsis, size: 26),
                            ),
                          ),
                        ),
                      ),
                    )
                  : FxSurface(radius: 16, child: feedTabs),
            ),
          ),
        if (section > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                fxLabels[section],
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
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
