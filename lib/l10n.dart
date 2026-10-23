import 'package:flutter/material.dart';

String tr(BuildContext context, String text) {
  if (context.dependOnInheritedWidgetOfExactType<AppTranslations>() == null ||
      Localizations.localeOf(context).languageCode != 'en') {
    return text;
  }
  return _english[text] ?? text;
}

class AppTranslations extends InheritedWidget {
  const AppTranslations({super.key, required super.child});
  @override
  bool updateShouldNotify(AppTranslations oldWidget) => false;
}

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Text(
    tr(context, data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
  );
}

const _english = {
  '首页': 'Home',
  '搜索': 'Search',
  '通知': 'Notifications',
  '我的': 'Me',
  '私信': 'Messages',
  '收藏': 'Saved',
  '历史记录': 'History',
  '浏览记录': 'History',
  '设置': 'Settings',
  '编辑个人资料': 'Edit profile',
  '个人主页选项': 'Profile options',
  '存储': 'Storage',
  '主题': 'Theme',
  '语言': 'Language',
  '账号安全': 'Account security',
  '密码、双重验证、删除账号': 'Password, two-factor authentication, account deletion',
  '跟随系统': 'System',
  '浅色': 'Light',
  '深色': 'Dark',
  '平台存储': 'Platform storage',
  '没有默认自定义存储时使用平台存储': 'Used when no custom default is configured',
  '添加存储': 'Add storage',
  '编辑存储': 'Edit storage',
  '删除存储': 'Delete storage',
  '删除此存储配置？已有媒体由服务器保留引用。':
      'Delete this configuration? The server retains references for existing media.',
  '名称': 'Name',
  'Secret Access Key（留空保留）': 'Secret Access Key (leave blank to keep)',
  '必填': 'Required',
  '请输入 HTTPS 地址': 'Enter an HTTPS URL',
  '路径式寻址': 'Path-style addressing',
  '启用': 'Enabled',
  '默认上传存储': 'Default upload storage',
  '保存': 'Save',
  '测试连接': 'Test connection',
  '推荐': 'For you',
  '实时': 'Latest',
  '关注': 'Following',
  '不接收私信': 'No messages',
  '互关可见': 'Mutual followers',
  '仅互关可私信': 'Messages from mutual followers',
  '仅自己': 'Only me',
  '保存资料': 'Save profile',
  '修改密码': 'Change password',
  '公开': 'Public',
  '删除': 'Delete',
  '加载失败，点击重试': 'Failed to load. Tap to retry',
  '原帖已删除或不可见': 'Original post deleted or unavailable',
  '双重验证': 'Two-factor authentication',
  '发送': 'Send',
  '取消': 'Cancel',
  '已发布': 'Published',
  '已复制链接': 'Link copied',
  '已引用': 'Quoted',
  '帖子': 'Post',
  '引用': 'Quote',
  '恢复码': 'Recovery codes',
  '我已保存': 'I saved them',
  '所有人可私信': 'Messages from everyone',
  '更换头像': 'Change avatar',
  '更换头图': 'Change header',
  '申请删除账号': 'Request account deletion',
  '登录': 'Log in',
  '登录 / 注册': 'Log in / Sign up',
  '确定': 'OK',
  '确认': 'Confirm',
  '移除头像': 'Remove avatar',
  '简体中文': '简体中文',
  '编辑': 'Edit',
  '这个账号已申请删除。': 'This account is pending deletion.',
  '退出登录': 'Log out',
  '重新加载': 'Reload',
  '验证身份': 'Verify identity',
  '名字': 'Name',
  '用户名': 'Username',
  '简介': 'Bio',
  '地区': 'Region',
  '性别': 'Gender',
  '生日': 'Birthday',
  '当前密码': 'Current password',
  '新密码': 'New password',
  '动态验证码': 'Authenticator code',
  '当前动态验证码': 'Current authenticator code',
  '双重验证已开启': 'Two-factor authentication enabled',
  '开启双重验证': 'Set up two-factor authentication',
  '评论': 'Reply',
  '转发': 'Repost',
  '取消转发': 'Undo repost',
  '点赞': 'Like',
  '取消点赞': 'Unlike',
  '取消收藏': 'Unsave',
  '分享': 'Share',
  '删除帖子': 'Delete post',
  '删除后不能恢复。': 'This cannot be undone.',
  '还没有帖子': 'No posts yet',
  '还没有收藏': 'No saved posts yet',
  '没有找到这个用户': 'User not found',
  '搜索 FuckXter': 'Search FuckXter',
  '关闭搜索': 'Close search',
  '撰写帖子': 'Write a post',
};
