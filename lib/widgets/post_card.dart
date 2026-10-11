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
  });

  final Post post;
  final AppSession session;
  final ValueChanged<Post>? onChanged;
  final VoidCallback? onOpen;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post post = widget.post;
  bool busy = false;

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.liked != widget.post.liked ||
        oldWidget.post.text != widget.post.text) {
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
    final wrapper = post.repostKind == 'repost' &&
            post.source != null &&
            next.id == post.source!.id
        ? post.copyWith(source: next, updateSource: true)
        : next;
    setState(() => post = wrapper);
    widget.onChanged?.call(wrapper);
  }

  @override
  Widget build(BuildContext context) {
    final shown = post.repostKind == 'repost' && post.source != null
        ? post.source!
        : post;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.repostKind == 'repost')
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 56),
              child: Text('${post.author.name} 转发了',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () =>
                  openProfile(context, widget.session, shown.author.handle),
              child: Avatar(
                name: shown.author.name,
                size: 44,
                headers: api.imageHeaders,
                url: shown.author.avatarUrl == null
                    ? null
                    : api.mediaUri(shown.author.avatarUrl!).toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(shown.author.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (shown.author.verified)
                        const Icon(Icons.verified,
                            size: 15, color: Color(0xFF5B7AA8)),
                      Text(
                        '@${shown.author.handle} · ${relativeTime(shown.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (shown.visibility != 'public')
                        Text(visibilityLabel(shown.visibility),
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: widget.onOpen ??
                        () => openPost(context, widget.session, shown),
                    child: Text(shown.text,
                        style: const TextStyle(fontSize: 15.5, height: 1.45)),
                  ),
                  if (post.repostKind == 'quote' && post.source != null)
                    _Quote(post: post.source!, session: widget.session),
                  if (shown.media.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _MediaStrip(media: shown.media, api: api),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CountAction(
                        icon: CupertinoIcons.chat_bubble,
                        value: shown.stats.replies,
                        onTap: () => openPost(context, widget.session, shown),
                      ),
                      CountAction(
                        icon: CupertinoIcons.repeat,
                        value: shown.stats.reposts,
                        active: shown.reposted,
                        activeColor: const Color(0xFF00BA7C),
                        onTap: () => _repostMenu(shown),
                      ),
                      CountAction(
                        icon: shown.liked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        value: shown.stats.likes,
                        active: shown.liked,
                        activeColor: const Color(0xFFF91880),
                        onTap: () => _run(() async {
                          final next = !shown.liked;
                          final result = await api.setLike(shown.id, next);
                          _emit(shown.copyWith(
                            liked: result.liked,
                            stats: shown.stats.copyWith(likes: result.likes),
                          ));
                        }),
                      ),
                      CountAction(
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
                        icon: CupertinoIcons.share,
                        onTap: () => copyText(context, api.postWebUrl(shown)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _repostMenu(Post shown) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'repost') {
      await _run(() async {
        final next = !shown.reposted;
        final result = await api.setRepost(shown.id, next);
        _emit(shown.copyWith(
          reposted: result.reposted,
          stats: shown.stats.copyWith(reposts: result.reposts),
        ));
      });
    } else if (choice == 'quote') {
      final text = await askText(context, title: '引用', hint: '加上你的看法');
      if (text == null || text.trim().isEmpty || !mounted) return;
      await _run(() async {
        await api.quotePost(shown.id, text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已引用')));
        }
      });
    } else if (choice == 'edit') {
      final text = await askText(context,
          title: '编辑帖子', hint: '正文', initial: shown.text);
      if (text == null || !mounted) return;
      await _run(() async {
        final updated = await api.updatePost(shown.id, text.trim(),
            visibility: shown.visibility);
        _emit(updated);
      });
    } else if (choice == 'delete') {
      final ok = await confirm(context, '删除帖子', '删除后不能恢复。');
      if (!ok || !mounted) return;
      await _run(() async {
        await api.deletePost(shown.id);
        if (mounted) Navigator.maybePop(context);
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
              border: Border.all(color: Theme.of(context).dividerColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${post.author.name} @${post.author.handle}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(post.text, maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.media, required this.api});
  final List<PostMedia> media;
  final FuckXterApi api;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final item in media)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: NetImage(
                  url: api.mediaUri(item.url).toString(),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  headers: api.imageHeaders,
                ),
              ),
            ),
        ],
      );
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        maxLength: 1000,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('发送')),
      ],
    ),
  );
}
