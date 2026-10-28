import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../models/models.dart';
import '../screens/flows.dart';
import '../services/fuckxter_api.dart';
import '../session.dart';
import 'bits.dart';
import 'fx_controls.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.session,
    this.onChanged,
    this.onOpen,
    this.onDeleted,
    this.detail = false,
  });

  final bool detail;
  final Post post;
  final AppSession session;
  final ValueChanged<Post>? onChanged;
  final VoidCallback? onOpen;
  final VoidCallback? onDeleted;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post post = widget.post;
  bool busy = false;
  bool deleted = false;

  bool get isOwner =>
      widget.session.account != null &&
      (post.isAuthor ||
          widget.session.account!.profile.handle == post.author.handle);

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.post, widget.post)) {
      post = widget.post;
    }
  }

  FuckXterApi get api => widget.session.api;

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    if (widget.session.account == null) {
      final ok = await openLogin(context, widget.session);
      if (!ok || !mounted) return;
    }
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _emit(Post next) {
    if (!mounted) return;
    setState(() => post = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    if (deleted) return const SizedBox.shrink();
    final shown = post;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.detail
          ? null
          : widget.onOpen ?? () => openPost(context, widget.session, shown),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                onTap: () =>
                    openProfile(context, widget.session, shown.author.handle),
                child: FxAvatar(
                  name: shown.author.name,
                  size: compact ? 60 : 64,
                  headers: api.imageHeaders,
                  url: shown.author.avatarUrl,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 70 : 76,
                12,
                compact ? 12 : 16,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.repostKind == 'repost')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${post.author.name} 转发了',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  shown.author.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (shown.author.verified)
                                  const Icon(
                                    Icons.verified,
                                    size: 15,
                                    color: Color(0xFF5B7AA8),
                                  ),
                                Text(
                                  '@${shown.author.handle} · ${relativeTime(shown.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (shown.visibility != 'public')
                                  Text(
                                    visibilityLabel(shown.visibility),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            if (post.repostKind != 'repost')
                              GestureDetector(
                                onTap:
                                    widget.onOpen ??
                                    () => openPost(
                                      context,
                                      widget.session,
                                      shown,
                                    ),
                                child: Text(
                                  shown.text,
                                  maxLines: widget.detail
                                      ? null
                                      : (shown.media.isEmpty ? 5 : 3),
                                  overflow: widget.detail
                                      ? null
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            if (post.repostKind != null && post.source != null)
                              _Quote(
                                post: post.source!,
                                session: widget.session,
                              ),
                            if (post.repostKind != null && post.source == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: AppText('原帖已删除或不可见'),
                              ),
                            if (post.repostKind != 'repost' &&
                                shown.media.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _MediaStrip(
                                  media: shown.media,
                                  api: api,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                CountAction(
                                  label: '评论',
                                  icon: CupertinoIcons.chat_bubble,
                                  value: shown.stats.replies,
                                  onTap:
                                      widget.onOpen ??
                                      () => openPost(
                                        context,
                                        widget.session,
                                        shown,
                                      ),
                                ),
                                CountAction(
                                  label: '转发',
                                  icon: CupertinoIcons.repeat,
                                  value: shown.stats.reposts,
                                  active: shown.reposted,
                                  activeColor: const Color(0xFF00BA7C),
                                  onTap: () => _repostMenu(shown),
                                ),
                                CountAction(
                                  label: shown.liked ? '取消点赞' : '点赞',
                                  icon: shown.liked
                                      ? CupertinoIcons.heart_fill
                                      : CupertinoIcons.heart,
                                  value: shown.stats.likes,
                                  active: shown.liked,
                                  activeColor: const Color(0xFFF91880),
                                  onTap: () => _run(() async {
                                    final next = !shown.liked;
                                    final result = await api.setLike(
                                      shown.id,
                                      next,
                                    );
                                    _emit(
                                      shown.copyWith(
                                        liked: result.liked,
                                        stats: shown.stats.copyWith(
                                          likes: result.likes,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                CountAction(
                                  label: shown.saved ? '取消收藏' : '收藏',
                                  icon: shown.saved
                                      ? CupertinoIcons.bookmark_fill
                                      : CupertinoIcons.bookmark,
                                  active: shown.saved,
                                  onTap: () => _run(() async {
                                    final next = !shown.saved;
                                    await api.setSave(shown.id, next);
                                    _emit(shown.copyWith(saved: next));
                                  }),
                                ),
                                if (isOwner)
                                  CountAction(
                                    label: '删除',
                                    icon: CupertinoIcons.trash,
                                    onTap: busy ? null : () => _delete(shown),
                                  ),
                                Builder(
                                  builder: (shareContext) => CountAction(
                                    label: '分享',
                                    icon: CupertinoIcons.share,
                                    onTap: () => _share(shareContext, shown),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Future<void> _repostMenu(Post shown) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tr(context, shown.reposted ? '取消转发' : '转发')),
              onTap: () => Navigator.pop(context, 'repost'),
            ),
            ListTile(
              title: const AppText('引用'),
              onTap: () => Navigator.pop(context, 'quote'),
            ),
            if (post.repostKind != 'repost' && isOwner) ...[
              ListTile(
                title: const AppText('编辑'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                title: const AppText('删除'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'repost') {
      await _run(() async {
        final next = !shown.reposted;
        final result = await api.setRepost(shown.id, next);
        _emit(
          shown.copyWith(
            reposted: result.reposted,
            stats: shown.stats.copyWith(reposts: result.reposts),
          ),
        );
      });
    } else if (choice == 'quote') {
      final text = await askText(
        context,
        title: tr(context, '引用'),
        hint: tr(context, '加上你的看法'),
      );
      if (text == null || text.trim().isEmpty || !mounted) return;
      await _run(() async {
        await api.quotePost(shown.id, text.trim());
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: AppText('已引用')));
        }
      });
    } else if (choice == 'edit') {
      final text = await askText(
        context,
        title: '编辑帖子',
        hint: '正文',
        initial: shown.text,
      );
      if (text == null || !mounted) return;
      await _run(() async {
        final updated = await api.updatePost(
          shown.id,
          text.trim(),
          visibility: shown.visibility,
        );
        _emit(updated);
      });
    } else if (choice == 'delete') {
      await _delete(shown);
    }
  }

  Future<void> _share(BuildContext shareContext, Post shown) async {
    try {
      final box = shareContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.parse(api.postWebUrl(shown)),
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete(Post shown) async {
    if (!isOwner || busy) return;
    final ok = await confirm(context, '删除帖子', '删除后不能恢复。');
    if (!ok || !mounted) return;
    await _run(() async {
      await api.deletePost(shown.id);
      if (!mounted) return;
      setState(() => deleted = true);
      widget.onDeleted?.call();
      if (widget.detail && mounted) Navigator.maybePop(context);
    });
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.post, required this.session});
  final Post post;
  final AppSession session;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => openPost(context, session, post),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${post.author.name} @${post.author.handle}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(post.text, maxLines: 4, overflow: TextOverflow.ellipsis),
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _MediaStrip(media: post.media, api: session.api),
            ),
        ],
      ),
    ),
  );
}

class _MediaStrip extends StatefulWidget {
  const _MediaStrip({required this.media, required this.api});
  final List<PostMedia> media;
  final FuckXterApi api;
  @override
  State<_MediaStrip> createState() => _MediaStripState();
}

class _MediaStripState extends State<_MediaStrip> {
  final ratios = <String, double>{};
  final scroll = ScrollController();
  bool previous = false, next = false;
  @override
  void initState() {
    super.initState();
    scroll.addListener(_sync);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted || !scroll.hasClients) return;
    final prev = scroll.offset > 2;
    final following = scroll.position.extentAfter > 2;
    if (prev != previous || following != next) {
      setState(() {
        previous = prev;
        next = following;
      });
    }
  }

  void _move(int direction) {
    if (!scroll.hasClients) return;
    scroll.animateTo(
      (scroll.offset + direction * scroll.position.viewportDimension * .86)
          .clamp(0, scroll.position.maxScrollExtent),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cap = math.min(MediaQuery.sizeOf(context).height * .42, 360.0);
      final available = box.maxWidth;
      final maxWidth = available * (widget.media.length > 1 ? .86 : 1);
      final tiles = <Widget>[];
      for (var i = 0; i < widget.media.length; i++) {
        final item = widget.media[i];
        final ratio = ratios[item.url] ?? 4 / 3;
        final tall = ratio < .5;
        final width = tall ? maxWidth : math.min(maxWidth, cap * ratio);
        final height = tall ? cap : width / ratio;
        tiles.add(
          Semantics(
            button: true,
            label: '查看图片 ${i + 1}/${widget.media.length} ${item.alt}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: width,
                height: height,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MediaGallery(
                        media: widget.media,
                        api: widget.api,
                        initial: i,
                        ratios: Map.of(ratios),
                      ),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetImage(
                        key: ValueKey(item.url),
                        url: item.url,
                        fit: tall ? BoxFit.cover : BoxFit.contain,
                        alignment: tall
                            ? Alignment.topCenter
                            : Alignment.center,
                        width: width,
                        height: height,
                        decodeWidth: available,
                        headers: widget.api.imageHeaders,
                        focus: true,
                        onDimensions: (size) {
                          final value = size.width / size.height;
                          if ((value - (ratios[item.url] ?? 0)).abs() > .001 &&
                              mounted) {
                            setState(() => ratios[item.url] = value);
                          }
                        },
                      ),
                      if (tall)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 48,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x66000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (tiles.length == 1) return tiles.first;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      return Stack(
        alignment: Alignment.center,
        children: [
          SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  tiles[i],
                ],
              ],
            ),
          ),
          if (previous) Positioned(left: 4, child: _arrow(-1)),
          if (next) Positioned(right: 4, child: _arrow(1)),
        ],
      );
    },
  );
  Widget _arrow(int direction) => SizedBox.square(
    dimension: 32,
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: tr(context, direction < 0 ? '上一张' : '下一张'),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: .55),
        foregroundColor: Colors.white,
      ),
      onPressed: () => _move(direction),
      icon: Icon(
        direction < 0
            ? CupertinoIcons.chevron_left
            : CupertinoIcons.chevron_right,
        size: 18,
      ),
    ),
  );
}

class MediaGallery extends StatefulWidget {
  const MediaGallery({
    super.key,
    required this.media,
    required this.api,
    required this.initial,
    this.ratios = const {},
  });
  final List<PostMedia> media;
  final FuckXterApi api;
  final int initial;
  final Map<String, double> ratios;
  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery>
    with SingleTickerProviderStateMixin {
  late final controller = PageController(initialPage: widget.initial);
  late final resize = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..value = 1;
  late final ratios = Map<String, double>.of(widget.ratios);
  final previous = <String, double>{};
  late int index = widget.initial;

  double _ratio(String url) => ui.lerpDouble(
    previous[url] ?? ratios[url] ?? 4 / 3,
    ratios[url] ?? 4 / 3,
    Curves.easeOutCubic.transform(resize.value),
  )!;
  void _size(String url, Size size) {
    final value = size.width / size.height;
    if (!mounted || (value - (ratios[url] ?? 0)).abs() < .001) return;
    final snapshot = {
      for (final item in widget.media) item.url: _ratio(item.url),
    };
    setState(() {
      previous
        ..clear()
        ..addAll(snapshot);
      ratios[url] = value;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      resize.value = 1;
    } else {
      resize.forward(from: 0);
    }
  }

  void _move(int direction) {
    final next = (index + direction).clamp(0, widget.media.length - 1);
    if (next == index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(next);
    } else {
      controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    resize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${index + 1} / ${widget.media.length}'),
    ),
    body: Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              double height(int i) {
                final ratio = _ratio(widget.media[i].url);
                return ratio < .5
                    ? box.maxHeight
                    : math.min(box.maxHeight, box.maxWidth / ratio);
              }

              return AnimatedBuilder(
                animation: Listenable.merge([controller, resize]),
                child: PageView.builder(
                  controller: controller,
                  itemCount: widget.media.length,
                  onPageChanged: (value) => setState(() => index = value),
                  itemBuilder: (_, i) {
                    final item = widget.media[i];
                    final tall = (ratios[item.url] ?? 1) < .5;
                    final image = NetImage(
                      url: item.url,
                      fit: BoxFit.contain,
                      width: box.maxWidth,
                      height: tall ? null : double.infinity,
                      decodeWidth: box.maxWidth,
                      headers: widget.api.imageHeaders,
                      onDimensions: (size) => _size(item.url, size),
                    );
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: tall
                          ? SingleChildScrollView(child: image)
                          : Center(child: image),
                    );
                  },
                ),
                builder: (context, child) {
                  final page =
                      (controller.hasClients
                              ? controller.page ?? index.toDouble()
                              : index.toDouble())
                          .clamp(0.0, widget.media.length - 1.0);
                  final first = page.floor();
                  final last = page.ceil();
                  final progress = Curves.easeInOutCubic.transform(
                    page - first,
                  );
                  return Center(
                    child: SizedBox(
                      key: const ValueKey('gallery-viewport'),
                      height: ui.lerpDouble(
                        height(first),
                        height(last),
                        progress,
                      ),
                      width: box.maxWidth,
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: FxSurface(
            radius: 22,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: tr(context, '上一张'),
                    color: Colors.white,
                    onPressed: index == 0 ? null : () => _move(-1),
                    icon: const Icon(CupertinoIcons.chevron_left),
                  ),
                  IconButton(
                    tooltip: tr(context, '下一张'),
                    color: Colors.white,
                    onPressed: index + 1 == widget.media.length
                        ? null
                        : () => _move(1),
                    icon: const Icon(CupertinoIcons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) {
  var text = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        onChanged: (value) => text = value,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        maxLength: 1000,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text),
          child: const AppText('发送'),
        ),
      ],
    ),
  );
}
