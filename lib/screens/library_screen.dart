import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/post.dart';
import '../services/fuckxter_api.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen(
      {super.key,
      required this.api,
      required this.mode,
      this.account,
      this.handle});

  final FuckXterApi api;
  final String mode;
  final Account? account;
  final String? handle;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool loading = true;
  Object? error;
  List<Post> posts = [];
  UserProfile? profile;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      switch (widget.mode) {
        case 'saved':
          posts = await widget.api.savedPosts();
        case 'profile':
          final handle = widget.handle ?? widget.account!.handle;
          profile = await widget.api.profile(handle);
          posts = await widget.api.userPosts(handle);
        case 'notice':
          data = await widget.api.notifications();
          await widget.api.markNotificationsRead();
        case 'messages':
          data = await widget.api.conversations();
      }
    } catch (e) {
      error = e;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(switch (widget.mode) {
            'saved' => '收藏',
            'profile' => profile?.name ?? '个人主页',
            'notice' => '通知',
            _ => 'FuckXChat',
          }),
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: loading
              ? const ListView(children: [
                  SizedBox(height: 260),
                  Center(child: CircularProgressIndicator(strokeWidth: 2))
                ])
              : error != null
                  ? ListView(children: [
                      const SizedBox(height: 180),
                      Center(child: Text('加载失败')),
                      Center(
                          child: TextButton(
                              onPressed: load, child: const Text('重新加载')))
                    ])
                  : _body(),
        ),
      );

  Widget _body() {
    if (widget.mode == 'profile') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profile != null) ...[
            Text(profile!.name,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            Text('@${profile!.handle}'),
            const SizedBox(height: 10),
            Text(profile!.bio),
            const SizedBox(height: 12),
            Text(
                '${profile!.posts} 帖子   ${profile!.followers} 关注者   ${profile!.following} 正在关注'),
            const Divider(height: 32),
          ],
          ...posts.map(_postTile),
        ],
      );
    }
    if (widget.mode == 'saved') {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: posts.map(_postTile).toList());
    }
    final items = (data?[widget.mode == 'notice' ? 'notices' : 'threads']
            as List<dynamic>? ??
        const []);
    if (items.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 220),
        Center(child: Text('这里还没有内容'))
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, index) {
        final item = Map<String, dynamic>.from(items[index] as Map);
        if (widget.mode == 'notice') {
          final actor = item['actor'] is Map
              ? Map<String, dynamic>.from(item['actor'] as Map)
              : <String, dynamic>{};
          return ListTile(
            title: Text(_noticeTitle(
                item['type'] as String? ?? 'system', actor['name'] as String?)),
            subtitle: Text(item['post'] is Map
                ? (item['post'] as Map)['text'] as String? ?? ''
                : ''),
          );
        }
        final other = Map<String, dynamic>.from(item['other'] as Map);
        final last = item['lastMessage'] is Map
            ? Map<String, dynamic>.from(item['lastMessage'] as Map)
            : <String, dynamic>{};
        return ListTile(
          title: Text(other['name'] as String? ?? ''),
          subtitle: Text(last['body'] as String? ?? '还没有消息'),
          trailing: (item['unread'] as num? ?? 0).toInt() > 0
              ? Badge(label: Text('${item['unread']}'))
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConversationScreen(
                api: widget.api,
                handle: other['handle'] as String? ?? '',
                name: other['name'] as String? ?? '',
              ),
            ),
          ).then((_) => load()),
        );
      },
    );
  }

  Widget _postTile(Post post) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          title: Text(post.author.name,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(post.text),
          trailing: Text('♥ ${post.stats.likes}'),
        ),
      );
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen(
      {super.key, required this.api, required this.handle, required this.name});

  final FuckXterApi api;
  final String handle;
  final String name;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final input = TextEditingController();
  List<dynamic> messages = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final data = await widget.api.conversation(widget.handle);
    if (mounted) {
      setState(() {
        messages = data['messages'] as List<dynamic>? ?? const [];
        loading = false;
      });
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    await widget.api.sendMessage(widget.handle, text);
    input.clear();
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: Column(
          children: [
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final message =
                            Map<String, dynamic>.from(messages[i] as Map);
                        final mine = message['mine'] as bool? ?? false;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(message['body'] as String? ?? ''),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: input,
                            decoration:
                                const InputDecoration(hintText: '发送消息…'))),
                    IconButton(onPressed: send, icon: const Icon(Icons.send))
                  ],
                ),
              ),
            )
          ],
        ),
      );
}

String _noticeTitle(String type, String? name) {
  final actor = name ?? '系统';
  return switch (type) {
    'like' => '$actor 赞了你的帖子',
    'repost' => '$actor 转发了你的帖子',
    'reply' => '$actor 回复了你',
    'follow' => '$actor 关注了你',
    _ => '系统通知',
  };
}
