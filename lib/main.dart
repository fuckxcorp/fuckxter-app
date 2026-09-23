import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FuckXterApp());

class FuckXterApp extends StatelessWidget {
  const FuckXterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FuckXter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF050505),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF4D6D),
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final List<Post> _posts = [
    const Post('黎明之前', '@beforedaybreak', '2 分钟',
        '不被推荐算法操控的时间线，才是真正属于每个人的广场。\n\n今天也来说点你真正想说的。', 24, 8, 136),
    const Post('小山', '@mountainwalk', '18 分钟',
        '把手机放进口袋，沿着河边走了两个小时。风很大，脑袋反而安静下来。', 12, 3, 79),
    const Post('Kiri', '@kiri_notes', '36 分钟',
        '想做一个更慢一点的互联网：没有热搜，也没有「为你推荐」，只有人在认真交换想法。', 43, 17, 208),
  ];

  void _compose() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      builder: (_) => const Composer(),
    );
    if (text != null && text.trim().isNotEmpty) {
      setState(() =>
          _posts.insert(0, Post('mo', '@mo', '刚刚', text.trim(), 0, 0, 0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Feed(posts: _posts),
      const DiscoverPage(),
      const NoticesPage(),
      const ProfilePage()
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['FuckXter', '发现', '通知', '我的'][_tab],
            style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: _tab == 0
            ? [
                IconButton(
                    icon: const Icon(CupertinoIcons.slider_horizontal_3),
                    onPressed: () {})
              ]
            : null,
      ),
      body: SafeArea(child: pages[_tab]),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _compose,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('发帖'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(CupertinoIcons.house),
              selectedIcon: Icon(CupertinoIcons.house_fill),
              label: '首页'),
          NavigationDestination(icon: Icon(CupertinoIcons.search), label: '发现'),
          NavigationDestination(
              icon: Icon(CupertinoIcons.bell),
              selectedIcon: Icon(CupertinoIcons.bell_fill),
              label: '通知'),
          NavigationDestination(
              icon: Icon(CupertinoIcons.person),
              selectedIcon: Icon(CupertinoIcons.person_fill),
              label: '我的'),
        ],
      ),
    );
  }
}

class Feed extends StatelessWidget {
  const Feed({super.key, required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 4),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('全部',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFFFF7790))),
              SizedBox(width: 28),
              Text('关注', style: TextStyle(color: Colors.white60)),
            ])),
        const SizedBox(height: 12),
        Expanded(
            child: ListView.separated(
          itemCount: posts.length + 1,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFF252525)),
          itemBuilder: (_, index) => index == posts.length
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                      child: Text('你已经看完啦',
                          style: TextStyle(color: Colors.white38))),
                )
              : PostCard(post: posts[index]),
        )),
      ]);
}

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post});
  final Post post;
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool liked = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 21,
              backgroundColor: _colorFor(p.name),
              child: Text(p.name.characters.first,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 5),
                  Text(p.handle,
                      style: const TextStyle(color: Color(0x73FFFFFF))),
                  const SizedBox(width: 5),
                  Text('· ${p.time}',
                      style: const TextStyle(color: Color(0x73FFFFFF))),
                  const Spacer(),
                  const Icon(Icons.more_horiz, color: Colors.white54)
                ]),
                const SizedBox(height: 5),
                Text(p.body,
                    style: const TextStyle(fontSize: 15.5, height: 1.4)),
                const SizedBox(height: 13),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Action(
                          icon: CupertinoIcons.chat_bubble, count: p.comments),
                      _Action(icon: CupertinoIcons.repeat, count: p.reposts),
                      _Action(
                          icon: liked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          count: p.likes + (liked ? 1 : 0),
                          active: liked,
                          onTap: () => setState(() => liked = !liked)),
                      const Icon(CupertinoIcons.share,
                          size: 18, color: Colors.white54),
                    ]),
              ])),
        ]));
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {required this.icon,
      required this.count,
      this.active = false,
      this.onTap});
  final IconData icon;
  final int count;
  final bool active;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(children: [
            Icon(icon,
                size: 18,
                color: active ? const Color(0xFFFF4D6D) : Colors.white54),
            const SizedBox(width: 5),
            Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    color: active ? const Color(0xFFFF4D6D) : Colors.white54))
          ])));
}

class Composer extends StatefulWidget {
  const Composer({super.key});
  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
          height: 370,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  const Text('写点什么',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ]),
                Expanded(
                    child: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLength: 500,
                        maxLines: null,
                        decoration: const InputDecoration(
                            hintText: '分享此刻的想法…', border: InputBorder.none))),
                Row(children: [
                  const Icon(CupertinoIcons.photo, color: Color(0xFFFF7790)),
                  const SizedBox(width: 18),
                  const Icon(CupertinoIcons.number, color: Color(0xFFFF7790)),
                  const Spacer(),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text('发布'))
                ]),
              ]))));
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(18), children: const [
        SearchBar(hintText: '搜索用户、帖子或话题'),
        SizedBox(height: 24),
        Text('正在讨论',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Topic('独立开发', '1,482 帖'),
        Topic('今日份快乐', '892 帖'),
        Topic('Flutter', '616 帖')
      ]);
}

class Topic extends StatelessWidget {
  const Topic(this.name, this.count, {super.key});
  final String name, count;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      title:
          Text('# $name', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(count),
      trailing: const Icon(Icons.more_horiz));
}

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(children: const [
        ListTile(
            leading: CircleAvatar(
                child:
                    Icon(CupertinoIcons.heart_fill, color: Color(0xFFFF4D6D))),
            title: Text('Kiri 喜欢了你的帖子'),
            subtitle: Text('“今天也来说点你真正想说的。”'),
            trailing: Text('12m', style: TextStyle(color: Colors.white38))),
        Divider(),
        ListTile(
            leading: CircleAvatar(child: Icon(CupertinoIcons.person_add)),
            title: Text('晨雾 开始关注你'),
            trailing: Text('1h', style: TextStyle(color: Colors.white38)))
      ]);
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(children: [
        Container(height: 130, color: const Color(0xFF632F3B)),
        Transform.translate(
            offset: const Offset(0, -38),
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFFF4D6D),
                    child: Text('M',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold))))),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('mo',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              Text('@mo', style: TextStyle(color: Color(0x73FFFFFF))),
              SizedBox(height: 14),
              Text('在一个没有算法的角落，认识真实的人。'),
              SizedBox(height: 14),
              Text('12 关注     38 关注者',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 28),
              Text('帖子',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFFFF7790)))
            ]))
      ]);
}

Color _colorFor(String input) {
  const colors = [Color(0xFF6D5DFB), Color(0xFF00A896), Color(0xFFE07A5F)];
  return colors[input.codeUnitAt(0) % colors.length];
}

class Post {
  const Post(this.name, this.handle, this.time, this.body, this.comments,
      this.reposts, this.likes);
  final String name, handle, time, body;
  final int comments, reposts, likes;
}
