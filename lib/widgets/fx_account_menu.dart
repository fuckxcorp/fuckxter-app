import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'bits.dart';
import 'fx_controls.dart';
import 'fx_motion.dart';

Future<String?> showFxAccountMenu(
  BuildContext context,
  Account? account,
  Map<String, String> headers,
) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭账号菜单',
    barrierColor: Colors.black.withValues(alpha: .22),
    transitionDuration: Duration(milliseconds: reduced ? 0 : 240),
    pageBuilder: (context, _, _) {
      final entries = <(String, String, IconData)>[
        if (account == null)
          ('login', '登录 / 注册', CupertinoIcons.person)
        else
          ('profile', account.profile.name, CupertinoIcons.person),
        ('saved', '收藏', CupertinoIcons.bookmark),
        ('history', '浏览记录', CupertinoIcons.clock),
        ('settings', '设置', CupertinoIcons.gear),
        ('theme', '切换主题', CupertinoIcons.circle_lefthalf_fill),
      ];
      final scheme = Theme.of(context).colorScheme;
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Material(
                    type: MaterialType.transparency,
                    child: FxSurface(
                      radius: 28,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        shrinkWrap: true,
                        children: [
                          Row(
                            children: [
                              const Spacer(),
                              IconButton(
                                tooltip: '关闭账号菜单',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  CupertinoIcons.xmark,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          for (var i = 0; i < entries.length; i++)
                            FxReveal(
                              delay: Duration(milliseconds: 20 * i),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minVerticalPadding: 10,
                                leading: i == 0 && account != null
                                    ? Avatar(
                                        name: account.profile.name,
                                        size: 44,
                                        url: account.avatarUrl,
                                        headers: headers,
                                      )
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: scheme.surfaceContainerHighest
                                              .withValues(alpha: .55),
                                          border: Border.all(
                                            color: scheme.onSurface.withValues(
                                              alpha: .35,
                                            ),
                                          ),
                                        ),
                                        child: Icon(entries[i].$3, size: 23),
                                      ),
                                title: Text(
                                  entries[i].$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: i == 0 && account != null
                                    ? Text('@${account.profile.handle}')
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onTap: () =>
                                    Navigator.pop(context, entries[i].$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    ),
  );
}
