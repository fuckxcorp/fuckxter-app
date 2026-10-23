import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/models.dart';
import '../services/fuckxter_api.dart';
import '../session.dart';
import '../widgets/bits.dart';
import '../widgets/post_card.dart';
import '../widgets/fx_motion.dart';
import '../widgets/fx_controls.dart';
import 'preferences_screen.dart';

Future<bool> openLogin(BuildContext context, AppSession session) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => LoginScreen(session: session)),
  );
  return ok == true || session.account != null;
}

void openPost(
  BuildContext context,
  AppSession session,
  Post post, {
  VoidCallback? onCovered,
}) {
  session.rememberPost(post);
  final route = MaterialPageRoute<void>(
    builder: (_) => PostScreen(session: session, post: post),
  );
  Navigator.of(context).push(route).whenComplete(() => onCovered?.call());
  if (onCovered != null) {
    void covered(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        route.animation?.removeStatusListener(covered);
        onCovered();
      }
    }

    route.animation?.addStatusListener(covered);
  }
}

void openProfile(BuildContext context, AppSession session, String handle) {
  if (handle.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProfileScreen(session: session, handle: handle),
    ),
  );
}

void openSearch(BuildContext context, AppSession session, String query) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SearchScreen(session: session, query: query),
    ),
  );
}

void openNotices(BuildContext context, AppSession session) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => NoticesScreen(session: session)));
}

Future<void> openMessages(
  BuildContext context,
  AppSession session, {
  String? handle,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => handle == null
          ? MessagesScreen(session: session)
          : ThreadScreen(session: session, handle: handle),
    ),
  );
}

void openSaved(BuildContext context, AppSession session) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SavedScreen(session: session)));
}

void openHistory(BuildContext context, AppSession session) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => HistoryScreen(session: session)));
}

void openSettings(BuildContext context, AppSession session) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PreferencesScreen(session: session)),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final AppSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  final recovery = TextEditingController();
  bool busy = false;
  bool useRecovery = false;
  bool needCode = false;
  String status = '用邮箱登录。没有账号时会直接注册。';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    recovery.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = email.text.trim();
    if (!identifier.contains('@') || !identifier.contains('.')) {
      setState(() => status = '请输入有效的邮箱地址');
      return;
    }
    setState(() {
      busy = true;
      status = '登录中…';
    });
    try {
      final result = await widget.session.login(
        identifier: identifier,
        password: useRecovery ? '' : password.text,
        code: needCode && !useRecovery ? code.text.trim() : null,
        recoveryCode: useRecovery ? recovery.text.trim() : null,
      );
      if (!mounted) return;
      if (result.restored) {
        setState(() => status = '已取消删除申请，账号恢复了。');
      }
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'TWO_FACTOR_REQUIRED') {
        setState(() {
          needCode = true;
          status = '这个账号开了双重验证，请输入动态验证码。';
        });
      } else {
        setState(() => status = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => status = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('登录 / 注册')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '邮箱'),
          ),
          if (!useRecovery)
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
          if (needCode && !useRecovery)
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: '动态验证码'),
            ),
          if (useRecovery)
            TextField(
              controller: recovery,
              decoration: const InputDecoration(labelText: '恢复码'),
            ),
          const SizedBox(height: 12),
          Text(status),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? '请稍候…' : '继续'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    useRecovery = !useRecovery;
                    needCode = useRecovery || needCode;
                  }),
            child: Text(useRecovery ? '改用密码登录' : '使用恢复码'),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.session,
    required this.query,
    this.embedded = false,
  });
  final AppSession session;
  final bool embedded;
  final String query;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final controller = TextEditingController(text: widget.query);
  List<UserSummary> users = const [];
  List<Post> posts = const [];
  bool loading = true;
  Object? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      controller.text = widget.query;
      _run();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final request = ++generation;
    final query = controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        users = const [];
        posts = const [];
        error = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.session.api.search(query);
      if (!mounted || request != generation) return;
      setState(() {
        users = result.users;
        posts = result.posts;
      });
    } catch (error) {
      if (mounted && request == generation) setState(() => this.error = error);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: '搜索 FuckXter',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _run(),
              ),
            ),
      body: loading
          ? const LoadingPane()
          : error != null
          ? EmptyHint('$error')
          : ListView.builder(
              itemCount: users.isEmpty && posts.isEmpty
                  ? 1
                  : users.length + posts.length,
              itemBuilder: (_, index) {
                if (users.isEmpty && posts.isEmpty) {
                  return EmptyHint(
                    controller.text.trim().isEmpty ? '搜索用户和帖子' : '没有匹配的用户或帖子',
                  );
                }
                if (index < users.length) {
                  final user = users[index];
                  return ListTile(
                    leading: Avatar(
                      name: user.name,
                      size: 40,
                      url: user.avatarUrl,
                    ),
                    title: Text(user.name),
                    subtitle: Text(
                      '@${user.handle} · 帖子 ${user.posts} · 粉丝 ${user.followers}',
                    ),
                    onTap: () =>
                        openProfile(context, widget.session, user.handle),
                  );
                }
                final post = posts[index - users.length];
                return PostCard(
                  key: ValueKey(post.id),
                  post: post,
                  session: widget.session,
                );
              },
            ),
    );
  }
}

class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.session, required this.post});
  final AppSession session;
  final Post post;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late Post post = widget.post;
  List<Comment> comments = const [];
  final reply = TextEditingController();
  String? parentId;
  bool loading = true;
  bool sending = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final (fresh, items) = await (
        post.slug.isEmpty
            ? Future.value(post)
            : widget.session.api.postByPath(post.author.handle, post.slug),
        widget.session.api.comments(post.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        if (fresh != null) post = fresh;
        comments = items;
      });
    } catch (error) {
      if (mounted) setState(() => this.error = error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = reply.text.trim();
    if (text.isEmpty || sending) return;
    if (widget.session.account == null) {
      final ok = await openLogin(context, widget.session);
      if (!ok || !mounted) return;
    }
    if (sending) return;
    setState(() => sending = true);
    try {
      await widget.session.api.createComment(post.id, text, parentId: parentId);
      if (!mounted) return;
      reply.clear();
      parentId = null;
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('帖子')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount:
                    1 +
                    (loading || error != null || comments.isEmpty
                        ? 1
                        : comments.length),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return FxReveal(
                      child: PostCard(
                        post: post,
                        detail: true,
                        session: widget.session,
                        onChanged: (next) => setState(() => post = next),
                        onOpen: () {},
                        onDeleted: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (loading) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: LoadingPane(),
                    );
                  }
                  if (error != null) return EmptyHint('$error');
                  if (comments.isEmpty) return const EmptyHint('还没有评论');
                  final comment = comments[index - 1];
                  return FxReveal(
                    key: ValueKey(comment.id),
                    delay: Duration(milliseconds: (index * 36).clamp(0, 180)),
                    child: _CommentTile(
                      comment: comment,
                      session: widget.session,
                      postId: post.id,
                      onReply: () => setState(() {
                        parentId = comment.id;
                        reply.text = '@${comment.author.handle} ';
                      }),
                      onChanged: _load,
                    ),
                  );
                },
              ),
            ),
          ),
          FxSurface(
            radius: 22,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: reply,
                        enabled: !sending,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: parentId == null ? '写一条评论' : '回复评论',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: sending ? null : _send,
                      icon: const Icon(Icons.send),
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
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.session,
    required this.postId,
    required this.onReply,
    required this.onChanged,
  });

  final Comment comment;
  final AppSession session;
  final String postId;
  final VoidCallback onReply;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final mine = session.account?.profile.handle == comment.author.handle;
    return ListTile(
      leading: Avatar(
        name: comment.author.name,
        size: 36,
        url: comment.author.avatarUrl,
      ),
      title: Text(
        '${comment.author.name} · ${relativeTime(comment.createdAt)}',
      ),
      subtitle: Text(
        [
          if (comment.parentName != null) '回复 ${comment.parentName}',
          comment.text,
        ].join('\n'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CountAction(
            label: comment.liked ? '取消点赞' : '点赞',
            icon: comment.liked
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            value: comment.likes,
            active: comment.liked,
            activeColor: const Color(0xFFF91880),
            onTap: () async {
              try {
                await session.api.setCommentLike(
                  postId,
                  comment.id,
                  !comment.liked,
                );
                await onChanged();
              } catch (error) {
                if (context.mounted) showError(context, error);
              }
            },
          ),
          IconButton(
            onPressed: onReply,
            icon: const Icon(CupertinoIcons.reply),
          ),
          if (mine)
            IconButton(
              onPressed: () async {
                final ok = await confirm(context, '删除评论', '删除后不能恢复。');
                if (!ok || !context.mounted) return;
                try {
                  await session.api.deleteComment(postId, comment.id);
                  await onChanged();
                } catch (error) {
                  if (context.mounted) showError(context, error);
                }
              },
              icon: const Icon(CupertinoIcons.trash),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.session, required this.handle});
  final AppSession session;
  final String handle;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String currentHandle = widget.handle;
  UserProfile? user;
  List<Post> posts = const [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final (profile, items) = await (
        widget.session.api.profile(currentHandle),
        widget.session.api.postsByUser(currentHandle),
      ).wait;
      if (!mounted) return;
      setState(() {
        user = profile;
        posts = items;
      });
    } catch (error) {
      if (mounted) setState(() => this.error = error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _follow(UserProfile user) async {
    if (widget.session.account == null) {
      final ok = await openLogin(context, widget.session);
      if (!ok || !mounted) return;
    }
    try {
      final result = await widget.session.api.setFollow(
        user.handle,
        !user.viewerFollowing,
      );
      setState(() {
        this.user = UserProfile(
          id: user.id,
          handle: user.handle,
          name: user.name,
          bio: user.bio,
          createdAt: user.createdAt,
          posts: user.posts,
          followers: result.followers,
          following: user.following,
          verified: user.verified,
          region: user.region,
          avatarUrl: user.avatarUrl,
          headerUrl: user.headerUrl,
          viewerFollowing: result.following,
          blocked: user.blocked,
          canMessage: user.canMessage,
          deleted: user.deleted,
        );
      });
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    return Scaffold(
      appBar: AppBar(
        title: Text('@$currentHandle'),
        actions: [
          if (widget.session.account?.profile.handle == currentHandle)
            PopupMenuButton<String>(
              tooltip: tr(context, '个人主页选项'),
              icon: const Icon(CupertinoIcons.gear),
              onSelected: (value) async {
                switch (value) {
                  case 'settings':
                    openSettings(context, widget.session);
                  case 'edit':
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(session: widget.session),
                      ),
                    );
                    if (mounted) {
                      currentHandle =
                          widget.session.account?.profile.handle ??
                          currentHandle;
                      await _load();
                    }
                  case 'messages':
                    openMessages(context, widget.session);
                  case 'saved':
                    openSaved(context, widget.session);
                  case 'history':
                    openHistory(context, widget.session);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'settings', child: AppText('设置')),
                PopupMenuItem(value: 'edit', child: AppText('编辑个人资料')),
                PopupMenuItem(value: 'messages', child: AppText('私信')),
                PopupMenuItem(value: 'saved', child: AppText('收藏')),
                PopupMenuItem(value: 'history', child: AppText('历史记录')),
              ],
            ),
        ],
      ),
      body: loading
          ? const LoadingPane()
          : error != null
          ? EmptyHint('$error')
          : user == null
          ? const EmptyHint('没有找到这个用户')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: 1 + (posts.isEmpty ? 1 : posts.length),
                itemBuilder: (context, index) {
                  if (index > 0) {
                    if (posts.isEmpty) {
                      return const EmptyHint('还没有帖子');
                    }
                    final item = posts[index - 1];
                    return PostCard(
                      key: ValueKey(item.id),
                      post: item,
                      session: widget.session,
                      onChanged: (next) => setState(() {
                        posts = [
                          for (final post in posts)
                            post.id == next.id ? next : post,
                        ];
                      }),
                      onDeleted: () => setState(() {
                        posts = posts
                            .where((post) => post.id != item.id)
                            .toList();
                      }),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (user.headerUrl != null)
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: NetImage(
                            url: user.headerUrl!,
                            fit: BoxFit.cover,
                            headers: widget.session.api.imageHeaders,
                          ),
                        ),
                      ListTile(
                        leading: Avatar(
                          name: user.name,
                          size: 56,
                          headers: widget.session.api.imageHeaders,
                          url: user.avatarUrl,
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        subtitle: Text('@${user.handle}'),
                        trailing:
                            widget.session.account?.profile.handle ==
                                user.handle
                            ? null
                            : FilledButton(
                                onPressed: () => _follow(user),
                                child: Text(
                                  user.viewerFollowing ? '已关注' : '关注',
                                ),
                              ),
                      ),
                      if (user.deleted)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: AppText('这个账号已申请删除。'),
                        ),
                      if (user.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(user.bio),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => openConnections(
                                context,
                                widget.session,
                                user,
                                'followers',
                              ),
                              child: Text('粉丝 ${user.followers}'),
                            ),
                            TextButton(
                              onPressed: () => openConnections(
                                context,
                                widget.session,
                                user,
                                'following',
                              ),
                              child: Text('关注 ${user.following}'),
                            ),
                            const Spacer(),
                            if (widget.session.account?.profile.handle !=
                                user.handle)
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'message') {
                                    openMessages(
                                      context,
                                      widget.session,
                                      handle: user.handle,
                                    );
                                  } else if (value == 'block') {
                                    try {
                                      await widget.session.api.setBlock(
                                        user.handle,
                                        !user.blocked,
                                      );
                                      await _load();
                                    } catch (error) {
                                      if (context.mounted) {
                                        showError(context, error);
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (user.canMessage)
                                    const PopupMenuItem(
                                      value: 'message',
                                      child: AppText('私信'),
                                    ),
                                  PopupMenuItem(
                                    value: 'block',
                                    child: Text(user.blocked ? '取消屏蔽' : '屏蔽'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

void openConnections(
  BuildContext context,
  AppSession session,
  UserProfile user,
  String kind,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ConnectionsScreen(session: session, handle: user.handle, kind: kind),
    ),
  );
}

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({
    super.key,
    required this.session,
    required this.handle,
    required this.kind,
  });

  final AppSession session;
  final String handle;
  final String kind;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  List<UserSummary> users = const [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.session.api.connections(
        widget.handle,
        widget.kind,
      );
      if (mounted) setState(() => users = items);
    } catch (error) {
      if (mounted) setState(() => this.error = error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind == 'followers' ? '粉丝' : '关注')),
      body: loading
          ? const LoadingPane()
          : error != null
          ? EmptyHint('$error')
          : users.isEmpty
          ? const EmptyHint('这里还没有人')
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, index) {
                final user = users[index];
                return ListTile(
                  leading: Avatar(name: user.name, size: 40),
                  title: Text(user.name),
                  subtitle: Text('@${user.handle}\n${user.bio}'),
                  isThreeLine: user.bio.isNotEmpty,
                  onTap: () =>
                      openProfile(context, widget.session, user.handle),
                );
              },
            ),
    );
  }
}

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({
    super.key,
    required this.session,
    this.active = true,
    this.embedded = false,
  });
  final AppSession session;
  final bool embedded;
  final bool active;

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<AppNotice> notices = const [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(NoticesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  bool fetching = false;
  Future<void> _load() async {
    if (fetching) return;
    fetching = true;
    if (mounted) setState(() => error = null);
    try {
      final items = await widget.session.api.notices();
      if (mounted && widget.active) await widget.session.api.markNoticesRead();
      if (mounted) setState(() => notices = items);
    } catch (error) {
      if (mounted) setState(() => this.error = error);
    } finally {
      fetching = false;
      if (mounted) setState(() => loading = false);
    }
  }

  String _label(AppNotice notice) {
    final who = notice.actor?.name ?? '系统';
    return switch (notice.type) {
      'reply' => '$who 回复了你',
      'like' => '$who 赞了你',
      'repost' => '$who 转发了你',
      'follow' => '$who 关注了你',
      _ => who,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const AppText('通知')),
      body: loading
          ? const LoadingPane()
          : error != null
          ? EmptyHint('$error')
          : notices.isEmpty
          ? const EmptyHint('没有通知')
          : ListView.builder(
              padding: EdgeInsets.only(bottom: widget.embedded ? 100 : 24),
              itemCount: notices.length,
              itemBuilder: (_, index) {
                final notice = notices[index];
                return ListTile(
                  title: Text(_label(notice)),
                  subtitle: Text(
                    notice.commentText ??
                        notice.postText ??
                        relativeTime(notice.createdAt),
                  ),
                  onTap: notice.postHandle == null || notice.postSlug == null
                      ? (notice.actor == null
                            ? null
                            : () => openProfile(
                                context,
                                widget.session,
                                notice.actor!.handle,
                              ))
                      : () async {
                          final post = await widget.session.api.postByPath(
                            notice.postHandle!,
                            notice.postSlug!,
                          );
                          if (post != null && context.mounted) {
                            openPost(context, widget.session, post);
                          }
                        },
                );
              },
            ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.session,
    this.active = true,
    this.embedded = false,
  });
  final AppSession session;
  final bool embedded;
  final bool active;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> threads = const [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  bool fetching = false;
  Future<void> _load() async {
    if (fetching) return;
    fetching = true;
    if (mounted) setState(() => error = null);
    try {
      final page = await widget.session.api.conversations();
      if (mounted) setState(() => threads = page.threads);
    } catch (error) {
      if (mounted) setState(() => this.error = error);
    } finally {
      fetching = false;
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const AppText('私信')),
      body: loading
          ? const LoadingPane()
          : error != null
          ? EmptyHint('$error')
          : threads.isEmpty
          ? const EmptyHint('还没有会话。到别人的主页可以发起私信。')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: widget.embedded ? 100 : 24),
                itemCount: threads.length,
                itemBuilder: (_, index) {
                  final thread = threads[index];
                  return ListTile(
                    leading: FxAvatar(
                      name: thread.other.name,
                      size: 40,
                      url: thread.other.avatarUrl,
                    ),
                    title: Text(
                      thread.other.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      thread.lastBody.replaceAll(RegExp(r'\s+'), ' ').trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: thread.unread == 0
                        ? null
                        : Text('${thread.unread}'),
                    onTap: () async {
                      await openMessages(
                        context,
                        widget.session,
                        handle: thread.other.handle,
                      );
                      if (mounted) _load();
                    },
                  );
                },
              ),
            ),
    );
  }
}

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, required this.session, required this.handle});
  final AppSession session;
  final String handle;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final input = TextEditingController();
  List<DirectMessage> messages = const [];
  bool canSend = true;
  String? hint;
  bool loading = true;
  bool sending = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++generation;
    try {
      final page = await widget.session.api.conversation(widget.handle);
      await widget.session.api.markRead(widget.handle);
      if (!mounted || request != generation) return;
      setState(() {
        messages = page.messages;
        canSend = page.canSend;
        hint = page.hint;
      });
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || !canSend || sending || loading) return;
    generation++;
    setState(() => sending = true);
    try {
      final next = await widget.session.api.sendMessage(widget.handle, text);
      if (!mounted) return;
      input.clear();
      setState(() => messages = next);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.handle}'),
        actions: [
          if (widget.session.account?.profile.handle == widget.handle)
            PopupMenuButton<String>(
              tooltip: tr(context, '个人主页选项'),
              icon: const Icon(CupertinoIcons.gear),
              onSelected: (value) async {
                switch (value) {
                  case 'settings':
                    openSettings(context, widget.session);
                  case 'edit':
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(session: widget.session),
                      ),
                    );
                    if (mounted) await _load();
                  case 'messages':
                    openMessages(context, widget.session);
                  case 'saved':
                    openSaved(context, widget.session);
                  case 'history':
                    openHistory(context, widget.session);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'settings', child: AppText('设置')),
                PopupMenuItem(value: 'edit', child: AppText('编辑个人资料')),
                PopupMenuItem(value: 'messages', child: AppText('私信')),
                PopupMenuItem(value: 'saved', child: AppText('收藏')),
                PopupMenuItem(value: 'history', child: AppText('历史记录')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const LoadingPane()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[index];
                      return Align(
                        alignment: message.mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: message.mine
                              ? () async {
                                  final ok = await confirm(
                                    context,
                                    '撤回',
                                    '撤回这条私信？',
                                  );
                                  if (!ok || !context.mounted) return;
                                  try {
                                    await widget.session.api.recallMessage(
                                      widget.handle,
                                      message.id,
                                    );
                                    await _load();
                                  } catch (error) {
                                    if (context.mounted) {
                                      showError(context, error);
                                    }
                                  }
                                }
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(maxWidth: 420),
                            color: message.mine
                                ? const Color(0xFF5B7AA8)
                                : Theme.of(context).dividerColor,
                            child: Text(
                              message.body,
                              style: TextStyle(
                                color: message.mine ? Colors.white : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (hint != null && hint!.isNotEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text(hint!)),
          FxSurface(
            radius: 22,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        enabled: canSend && !sending && !loading,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: canSend ? '写一条私信' : '现在不能发私信',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: canSend && !sending && !loading ? _send : null,
                      icon: const Icon(Icons.send),
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
}

class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
    required this.session,
    this.active = true,
    this.embedded = false,
  });
  final AppSession session;
  final bool embedded;
  final bool active;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Post> posts = const [];
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(SavedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  bool fetching = false;
  Future<void> _load() async {
    if (fetching) return;
    fetching = true;
    if (mounted) setState(() => error = null);
    try {
      final items = await widget.session.api.savedPosts();
      if (mounted) setState(() => posts = items);
    } catch (error) {
      if (mounted) setState(() => this.error = error);
    } finally {
      fetching = false;
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const AppText('收藏')),
      body: loading
          ? const LoadingPane()
          : error != null
          ? EmptyHint('$error')
          : posts.isEmpty
          ? const EmptyHint('还没有收藏')
          : ListView.builder(
              padding: EdgeInsets.only(bottom: widget.embedded ? 100 : 24),
              itemCount: posts.length,
              itemBuilder: (_, index) => PostCard(
                key: ValueKey(posts[index].id),
                post: posts[index],
                session: widget.session,
              ),
            ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final items = session.history;
    return Scaffold(
      appBar: AppBar(title: const AppText('浏览记录')),
      body: items.isEmpty
          ? const EmptyHint('打开过的帖子会记在这里')
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.text),
                  onTap: () async {
                    final post = await session.api.postByPath(
                      item.handle,
                      item.slug,
                    );
                    if (post != null && context.mounted) {
                      openPost(context, session, post);
                    }
                  },
                );
              },
            ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    this.security = false,
  });
  final bool security;
  final AppSession session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final name = TextEditingController(text: _p?.name);
  late final handle = TextEditingController(text: _p?.handle);
  late final bio = TextEditingController(text: _p?.bio);
  late final region = TextEditingController(text: _p?.region);
  late final gender = TextEditingController(text: _p?.gender);
  late final birthday = TextEditingController(text: _p?.birthday);
  late String policy = widget.session.account?.dmPolicy ?? 'everyone';
  String status = '';

  AccountProfile? get _p => widget.session.account?.profile;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  void _onSession() {
    final profile = widget.session.account?.profile;
    if (profile != null && name.text.isEmpty && profile.name.isNotEmpty) {
      name.text = profile.name;
      handle.text = profile.handle;
      bio.text = profile.bio;
      region.text = profile.region;
      gender.text = profile.gender;
      birthday.text = profile.birthday;
      policy = widget.session.account?.dmPolicy ?? policy;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    name.dispose();
    handle.dispose();
    bio.dispose();
    region.dispose();
    gender.dispose();
    birthday.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final account = await widget.session.api.updateProfile({
        'name': name.text.trim(),
        'handle': handle.text.trim(),
        'bio': bio.text.trim(),
        'region': region.text.trim(),
        'gender': gender.text.trim(),
        'birthday': birthday.text.trim(),
      });
      widget.session.replaceAccount(account);
      if (mounted) setState(() => status = '资料已保存');
    } catch (error) {
      if (mounted) setState(() => status = '$error');
    }
  }

  Future<void> _pick(bool header) async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    if (picked == null || !mounted) return;
    final type = imageType(picked.name) ?? 'image/jpeg';
    try {
      final bytes = await readPickedImage(picked);
      if (!mounted) return;
      if (header) {
        await widget.session.api.uploadHeader(
          bytes: bytes,
          name: picked.name,
          contentType: type,
        );
      } else {
        await widget.session.api.uploadAvatar(
          bytes: bytes,
          name: picked.name,
          contentType: type,
        );
      }
      await widget.session.refreshAccount();
      if (mounted) setState(() => status = header ? '头图已更新' : '头像已更新');
    } catch (error) {
      if (mounted) setState(() => status = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.session.account;
    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: AppText(widget.security ? '账号安全' : '编辑个人资料')),
        body: Center(
          child: FilledButton(
            onPressed: () => openLogin(context, widget.session),
            child: const AppText('登录'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: AppText(widget.security ? '账号安全' : '编辑个人资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.security) ...[
            Text('邮箱 ${account.profile.email}'),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: tr(context, '名字')),
            ),
            TextField(
              controller: handle,
              decoration: InputDecoration(labelText: tr(context, '用户名')),
            ),
            TextField(
              controller: bio,
              decoration: InputDecoration(labelText: tr(context, '简介')),
              maxLines: 3,
            ),
            TextField(
              controller: region,
              decoration: InputDecoration(labelText: tr(context, '地区')),
            ),
            TextField(
              controller: gender,
              decoration: InputDecoration(labelText: tr(context, '性别')),
            ),
            TextField(
              controller: birthday,
              decoration: InputDecoration(labelText: tr(context, '生日')),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: policy,
              items: const [
                DropdownMenuItem(value: 'everyone', child: AppText('所有人可私信')),
                DropdownMenuItem(value: 'mutual', child: AppText('仅互关可私信')),
                DropdownMenuItem(value: 'nobody', child: AppText('不接收私信')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                final next = await widget.session.api.setDmPolicy(value);
                widget.session.replaceAccount(next);
                setState(() => policy = value);
              },
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pick(false),
                  child: const AppText('更换头像'),
                ),
                OutlinedButton(
                  onPressed: () => _pick(true),
                  child: const AppText('更换头图'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await widget.session.api.removeAvatar();
                    await widget.session.refreshAccount();
                  },
                  child: const AppText('移除头像'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const AppText('保存资料')),
          ],
          if (widget.security) ...[
            TextButton(
              onPressed: () => _password(context),
              child: const AppText('修改密码'),
            ),
            TextButton(
              onPressed: () => _twoFactor(context),
              child: AppText(account.twoFactorEnabled ? '双重验证已开启' : '开启双重验证'),
            ),
            TextButton(
              onPressed: () async {
                final ok = await confirm(context, '退出', '退出当前账号？');
                if (!ok || !context.mounted) return;
                await widget.session.logout();
                if (context.mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              child: const AppText('退出登录'),
            ),
            TextButton(
              onPressed: () async {
                final ok = await confirm(
                  context,
                  '删除账号',
                  '申请删除后有 3 天宽限期，期间登录会取消删除。',
                );
                if (!ok || !context.mounted) return;
                try {
                  await widget.session.api.deleteAccount();
                  await widget.session.logout();
                } catch (error) {
                  if (mounted) setState(() => status = '$error');
                  return;
                }
                if (context.mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              child: const AppText('申请删除账号'),
            ),
          ],
          if (status.isNotEmpty) Text(status),
        ],
      ),
    );
  }

  Future<void> _password(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(labelText: tr(context, '当前密码')),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(labelText: tr(context, '新密码')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('保存'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await widget.session.api.changePassword(
        current: current.text,
        next: next.text,
      );
      if (context.mounted) setState(() => status = '密码已更新');
    } catch (error) {
      if (context.mounted) setState(() => status = '$error');
    }
  }

  Future<Map<String, String>?> _securityProof(
    BuildContext context,
    bool enabled,
  ) async {
    final password = TextEditingController();
    final code = TextEditingController();
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('验证身份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: tr(context, '当前密码')),
              ),
              if (enabled)
                TextField(
                  controller: code,
                  decoration: InputDecoration(
                    labelText: tr(context, '当前动态验证码'),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'password': password.text,
                if (enabled) 'code': code.text.trim(),
              }),
              child: const AppText('确认'),
            ),
          ],
        ),
      );
    } finally {
      password.dispose();
      code.dispose();
    }
  }

  Future<void> _twoFactor(BuildContext context) async {
    final enabled = widget.session.account?.twoFactorEnabled ?? false;
    final proceed = await confirm(
      context,
      '开启双重验证',
      enabled ? '验证身份后可更换验证器。完成新验证前，原验证器继续有效。' : '验证密码后生成新的验证器密钥。',
    );
    if (!proceed || !context.mounted) return;
    final proof = await _securityProof(context, enabled);
    if (proof == null || !context.mounted) return;
    try {
      final secret = await widget.session.api.beginTwoFactor(proof);
      if (!context.mounted) return;
      final code = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('双重验证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText('密钥：$secret'),
              TextField(
                controller: code,
                decoration: InputDecoration(labelText: tr(context, '动态验证码')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('确认'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        await widget.session.refreshAccount();
        if (context.mounted) {
          setState(() => status = '双重验证设置已中断，请按当前状态重新确认。');
        }
        return;
      }
      final account = await widget.session.api.confirmTwoFactor(
        code.text.trim(),
      );
      widget.session.replaceAccount(account);
      final codes = await widget.session.api.recoveryCodes({
        'password': proof['password']!,
        'code': code.text.trim(),
      });
      code.dispose();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('恢复码'),
          content: SelectableText(codes.join('\n')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('我已保存'),
            ),
          ],
        ),
      );
    } catch (error) {
      try {
        await widget.session.refreshAccount();
      } catch (_) {}
      if (context.mounted) setState(() => status = '$error');
    }
  }
}
