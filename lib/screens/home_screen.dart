import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';

import '../models/post.dart';
import '../services/fuckxter_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = FuckXterApi();
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  final _search = TextEditingController();
  final List<Post> _posts = [];
  String _tab = 'foryou';
  String? _cursor;
  Object? _error;
  bool _loading = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _api.close();
    _scroll.dispose();
    _composer.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 500 && _cursor != null) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _posts.clear();
        _cursor = null;
      }
    });
    try {
      final page = await _api.timeline(tab: _tab, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.posts);
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeTab(String tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _load(reset: true);
  }

  Future<void> _submit() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await _api.createPost(text);
      _composer.clear();
      await _load(reset: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _TopBar(
              search: _search,
              tab: _tab,
              onTab: _changeTab,
              onTheme: widget.onToggleTheme),
          Expanded(
              child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: CustomScrollView(controller: _scroll, slivers: [
              SliverToBoxAdapter(
                  child: _Composer(
                      controller: _composer,
                      posting: _posting,
                      onSubmit: _submit)),
              if (_posts.isEmpty && _loading)
                const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_posts.isEmpty && _error != null)
                SliverFillRemaining(
                    child: _ErrorState(
                        error: _error.toString(),
                        onRetry: () => _load(reset: true)))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverLayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.crossAxisExtent >= 980 ? 2 : 1;
                    if (columns == 1) {
                      return SliverList.builder(
                          itemCount: _posts.length,
                          itemBuilder: (_, i) => Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 680),
                                  child:
                                      PostCard(post: _posts[i], api: _api))));
                    }
                    final left = <Post>[], right = <Post>[];
                    for (var i = 0; i < _posts.length; i++) {
                      (i.isEven ? left : right).add(_posts[i]);
                    }
                    return SliverToBoxAdapter(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Expanded(
                              child: Column(
                                  children: left
                                      .map((p) => PostCard(post: p, api: _api))
                                      .toList())),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  children: right
                                      .map((p) => PostCard(post: p, api: _api))
                                      .toList()))
                        ]));
                  }),
                ),
              SliverToBoxAdapter(
                  child: SizedBox(
                      height: 72,
                      child: Center(
                          child: _loading
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : Text(
                                  _cursor == null && _posts.isNotEmpty
                                      ? '你已看完全部内容'
                                      : '',
                                  style: TextStyle(
                                      color: dark
                                          ? Colors.white38
                                          : Colors.black38))))),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.search,
      required this.tab,
      required this.onTab,
      required this.onTheme});
  final TextEditingController search;
  final String tab;
  final ValueChanged<String> onTab;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = Theme.of(context).dividerColor;
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(bottom: BorderSide(color: border))),
      child: LayoutBuilder(builder: (context, size) {
        final compact = size.maxWidth < 720;
        final tabs = Row(mainAxisSize: MainAxisSize.min, children: [
          _Tab(label: '推荐', value: 'foryou', selected: tab, onTap: onTab),
          _Tab(label: '实时', value: 'latest', selected: tab, onTap: onTab),
          _Tab(label: '关注', value: 'following', selected: tab, onTap: onTab),
        ]);
        final account = PopupMenuButton<String>(
          tooltip: '账号',
          color: dark ? const Color(0xFF1A1D22) : const Color(0xFF101215),
          onSelected: (value) {
            if (value == 'theme') onTheme();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'login',
                child: Text('登录 / 注册', style: TextStyle(color: Colors.white))),
            PopupMenuItem(
                value: 'theme',
                child: Text('切换主题', style: TextStyle(color: Colors.white))),
            PopupMenuItem(
                value: 'settings',
                child: Text('设置', style: TextStyle(color: Colors.white)))
          ],
          child: Container(
              width: 62,
              height: 48,
              color: dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215),
              child: Icon(CupertinoIcons.person,
                  color: dark ? Colors.black : Colors.white)),
        );
        const brand = Text('FuckXter',
            style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2));
        if (compact) {
          return Column(children: [
            Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Row(children: [brand, const Spacer(), account])),
            tabs,
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                child: _SearchBox(controller: search)),
          ]);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 0, 8),
          child: Row(children: [
            brand,
            const SizedBox(width: 28),
            Expanded(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _SearchBox(controller: search)))),
            const SizedBox(width: 20),
            tabs,
            account
          ]),
        );
      }),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Container(
      height: 40,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F6F8),
      child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
              prefixIcon: Icon(CupertinoIcons.search, size: 18),
              hintText: '搜索 FuckXter',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10))));
}

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});
  final String label, value, selected;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton(
            onPressed: () => onTap(value),
            style: TextButton.styleFrom(
                foregroundColor: active
                    ? (dark ? Colors.black : Colors.white)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                backgroundColor: active
                    ? (dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215))
                    : Colors.transparent,
                shape: const RoundedRectangleBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: Text(label,
                style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600))));
  }
}

class _Composer extends StatefulWidget {
  const _Composer(
      {required this.controller,
      required this.posting,
      required this.onSubmit});
  final TextEditingController controller;
  final bool posting;
  final VoidCallback onSubmit;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: Theme.of(context).dividerColor))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Avatar(name: '?', size: 42),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(children: [
                  TextField(
                      controller: widget.controller,
                      maxLength: 1000,
                      maxLines: null,
                      minLines: 2,
                      decoration: const InputDecoration(
                          hintText: '有什么新鲜事？',
                          counterText: '',
                          border: InputBorder.none)),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(children: [
                    IconButton(
                        onPressed: null,
                        icon: const Icon(CupertinoIcons.paperclip, size: 20)),
                    Text('${widget.controller.text.characters.length} / 1000',
                        style: Theme.of(context).textTheme.labelSmall),
                    const Spacer(),
                    FilledButton(
                        onPressed: widget.controller.text.trim().isEmpty ||
                                widget.posting
                            ? null
                            : widget.onSubmit,
                        child: Text(widget.posting ? '发送中…' : '发帖'))
                  ])
                ]))
              ]))));
}

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, required this.api});
  final Post post;
  final FuckXterApi api;
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool liked = widget.post.liked;
  late bool reposted = widget.post.reposted;
  late bool saved = widget.post.saved;
  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Avatar(
              name: p.author.name,
              size: 44,
              url: p.author.avatarUrl == null
                  ? null
                  : widget.api.mediaUri(p.author.avatarUrl!).toString()),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(p.author.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (p.author.verified)
                        const Icon(Icons.verified,
                            size: 15, color: Color(0xFF5B7AA8)),
                      Text('@${p.author.handle} · ${_relative(p.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall)
                    ]),
                const SizedBox(height: 7),
                Text(p.text,
                    style: const TextStyle(fontSize: 15.5, height: 1.45)),
                if (p.media != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _NetworkImage(
                        url: widget.api.mediaUri(p.media!.url).toString(),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Action(
                          icon: CupertinoIcons.chat_bubble,
                          value: p.stats.replies),
                      _Action(
                          icon: CupertinoIcons.repeat,
                          value: p.stats.reposts +
                              (reposted && !p.reposted ? 1 : 0),
                          active: reposted,
                          activeColor: const Color(0xFF00BA7C),
                          onTap: () => setState(() => reposted = !reposted)),
                      _Action(
                          icon: liked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          value: p.stats.likes + (liked && !p.liked ? 1 : 0),
                          active: liked,
                          activeColor: const Color(0xFFF91880),
                          onTap: () => setState(() => liked = !liked)),
                      _Action(
                          icon: saved
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          active: saved,
                          onTap: () => setState(() => saved = !saved)),
                      _Action(
                          icon: CupertinoIcons.chart_bar, value: p.stats.views),
                    ])
              ]))
        ]));
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {required this.icon,
      this.value,
      this.active = false,
      this.activeColor = const Color(0xFF5B7AA8),
      this.onTap});
  final IconData icon;
  final int? value;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            Icon(icon,
                size: 17,
                color: active
                    ? activeColor
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            if (value != null) ...[
              const SizedBox(width: 5),
              Text(_compact(value!),
                  style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? activeColor
                          : Theme.of(context).colorScheme.onSurfaceVariant))
            ]
          ])));
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size, this.url});
  final String name;
  final double size;
  final String? url;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
        color: const Color(0xFF5B7AA8),
        alignment: Alignment.center,
        child: Text(name.characters.firstOrNull?.toUpperCase() ?? '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)));
    return ClipOval(
        child: SizedBox.square(
            dimension: size,
            child: url == null
                ? fallback
                : _NetworkImage(
                    url: url!, fit: BoxFit.cover, fallback: fallback)));
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({
    required this.url,
    required this.fit,
    this.width,
    this.fallback,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final error = fallback ??
        const SizedBox(
          height: 120,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
    return Image.network(
      url,
      fit: fit,
      width: width,
      errorBuilder: (_, __, ___) => AvifImage.network(
        url,
        fit: fit,
        width: width,
        errorBuilder: (_, __, ___) => error,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(CupertinoIcons.wifi_exclamationmark, size: 36),
        const SizedBox(height: 12),
        Text(error),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('重新加载'))
      ]));
}

String _relative(DateTime value) {
  final d = DateTime.now().difference(value.toLocal());
  if (d.inMinutes < 1) return '刚刚';
  if (d.inHours < 1) return '${d.inMinutes} 分钟';
  if (d.inDays < 1) return '${d.inHours} 小时';
  if (d.inDays < 30) return '${d.inDays} 天';
  return '${value.month}月${value.day}日';
}

String _compact(int value) =>
    value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : '$value';
