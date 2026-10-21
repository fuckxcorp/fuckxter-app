import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/flows.dart';
import '../services/fuckxter_api.dart';
import '../session.dart';
import 'bits.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.session,
    this.onChanged,
    this.onOpen,
    this.onDeleted,
  });

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
    final shown = post;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 18,
        16,
        compact ? 12 : 18,
        10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.repostKind == 'repost')
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 56),
              child: Text(
                '${post.author.name} 转发了',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    openProfile(context, widget.session, shown.author.handle),
                child: Avatar(
                  name: shown.author.name,
                  size: 44,
                  headers: api.imageHeaders,
                  url: shown.author.avatarUrl,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (post.repostKind != 'repost')
                      GestureDetector(
                        onTap:
                            widget.onOpen ??
                            () => openPost(context, widget.session, shown),
                        child: Text(
                          shown.text,
                          style: const TextStyle(fontSize: 15.5, height: 1.45),
                        ),
                      ),
                    if (post.repostKind != null && post.source != null)
                      _Quote(post: post.source!, session: widget.session),
                    if (post.repostKind != null && post.source == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('原帖已删除或不可见'),
                      ),
                    if (post.repostKind != 'repost' && shown.media.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _MediaStrip(media: shown.media, api: api),
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
                          onTap: () => openPost(context, widget.session, shown),
                        ),
                        CountAction(
                          label: '转发与更多操作',
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
                            final result = await api.setLike(shown.id, next);
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
                        CountAction(
                          label: '复制链接',
                          icon: CupertinoIcons.share,
                          onTap: () => copyText(context, api.postWebUrl(shown)),
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
              title: Text(shown.reposted ? '取消转发' : '转发'),
              onTap: () => Navigator.pop(context, 'repost'),
            ),
            ListTile(
              title: const Text('引用'),
              onTap: () => Navigator.pop(context, 'quote'),
            ),
            if (post.repostKind != 'repost' && shown.isAuthor) ...[
              ListTile(
                title: const Text('编辑'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                title: const Text('删除'),
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
      final text = await askText(context, title: '引用', hint: '加上你的看法');
      if (text == null || text.trim().isEmpty || !mounted) return;
      await _run(() async {
        await api.quotePost(shown.id, text.trim());
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已引用')));
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
      final ok = await confirm(context, '删除帖子', '删除后不能恢复。');
      if (!ok || !mounted) return;
      await _run(() async {
        await api.deletePost(shown.id);
        if (!mounted) return;
        if (widget.onDeleted != null) {
          widget.onDeleted!();
        } else {
          Navigator.maybePop(context);
        }
      });
    }
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

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.media, required this.api});
  final List<PostMedia> media;
  final FuckXterApi api;

  Widget _tile(BuildContext context, int index) => Semantics(
    button: true,
    label: '查看图片 ${index + 1}/${media.length} ${media[index].alt}',
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _Gallery(media: media, api: api, initial: index),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetImage(
            url: media[index].url,
            fit: BoxFit.cover,
            headers: api.imageHeaders,
          ),
          if (index == 3 && media.length > 4)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '+${media.length - 4}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: media.length == 1 ? 4 / 3 : 3 / 2,
      child: media.length == 1
          ? _tile(context, 0)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: media.length < 4
                      ? _tile(context, 0)
                      : Column(
                          children: [
                            Expanded(child: _tile(context, 0)),
                            const SizedBox(height: 4),
                            Expanded(child: _tile(context, 2)),
                          ],
                        ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: media.length == 2
                      ? _tile(context, 1)
                      : Column(
                          children: [
                            Expanded(child: _tile(context, 1)),
                            const SizedBox(height: 4),
                            Expanded(
                              child: _tile(context, media.length == 3 ? 2 : 3),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    ),
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.media,
    required this.api,
    required this.initial,
  });
  final List<PostMedia> media;
  final FuckXterApi api;
  final int initial;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final controller = PageController(initialPage: widget.initial);
  late int index = widget.initial;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${index + 1} / ${widget.media.length}')),
    body: Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: widget.media.length,
            onPageChanged: (value) => setState(() => index = value),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: NetImage(
                  url: widget.media[i].url,
                  fit: BoxFit.contain,
                  width: MediaQuery.sizeOf(context).width,
                  height: MediaQuery.sizeOf(context).height - 160,
                  headers: widget.api.imageHeaders,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '上一张',
                onPressed: index == 0
                    ? null
                    : () => controller.previousPage(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '下一张',
                onPressed: index + 1 == widget.media.length
                    ? null
                    : () => controller.nextPage(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text),
          child: const Text('发送'),
        ),
      ],
    ),
  );
}
