import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fx_native_glass/fx_native_glass.dart';

import '../l10n.dart';

const fxLabels = ['首页', '搜索', '通知', '我的'];
const fxIcons = [
  CupertinoIcons.house,
  CupertinoIcons.search,
  CupertinoIcons.bell,
  CupertinoIcons.person_crop_circle,
];

class FxSurface extends StatelessWidget {
  const FxSurface({super.key, required this.child, this.radius = 20});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final apple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: apple
                ? NativeGlass(
                    dark: dark,
                    radius: radius,
                    fallback: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  )
                : ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: .96),
                  ),
          ),
          child,
        ],
      ),
    );
  }
}

class FxTabs extends StatelessWidget {
  const FxTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.icons,
    this.lastIcon,
    this.height = 48,
  });
  final List<String> labels;
  final List<IconData>? icons;
  final Widget? lastIcon;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth / labels.length;
          final edgeInset = height * math.tan(14 * math.pi / 180) / 2 + 5;
          final leftInset = selected == 0 ? edgeInset : 5.0;
          final rightInset = selected == labels.length - 1 ? edgeInset : 5.0;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                top: 4,
                bottom: 4,
                left: selected * width + leftInset,
                width: math.max(0, width - leftInset - rightInset),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(-14 * math.pi / 180),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ink, ink.withValues(alpha: .76)],
                      ),
                      border: Border.all(color: ink.withValues(alpha: .75)),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected == i,
                        label: tr(context, labels[i]),
                        child: InkWell(
                          key: ValueKey('fx-tab-${labels[i]}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onChanged(i),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (lastIcon != null && i == labels.length - 1)
                                  lastIcon!
                                else if (icons != null)
                                  Icon(
                                    icons![i],
                                    size: 20,
                                    color: selected == i
                                        ? (dark ? Colors.black : Colors.white)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                AppText(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: icons == null ? 14 : 10,
                                    fontWeight: selected == i
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: selected == i
                                        ? (dark ? Colors.black : Colors.white)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class FxNavigationBar extends StatelessWidget {
  const FxNavigationBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accountIcon,
  });
  final Widget? accountIcon;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: FxSurface(
        child: FxTabs(
          labels: fxLabels,
          icons: fxIcons,
          lastIcon: accountIcon,
          height: 60,
          selected: selected,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

class FxSidebar extends StatelessWidget {
  const FxSidebar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accountIcon,
  });
  final Widget? accountIcon;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: FxSurface(
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fxLabels.length; i++)
              Semantics(
                button: true,
                selected: selected == i,
                label: tr(context, fxLabels[i]),
                child: InkWell(
                  key: ValueKey('fx-rail-$i'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 6,
                    ),
                    child: Column(
                      children: [
                        if (i == fxLabels.length - 1 && accountIcon != null)
                          accountIcon!
                        else
                          Icon(
                            fxIcons[i],
                            size: 23,
                            color: selected == i
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        const SizedBox(height: 4),
                        AppText(
                          fxLabels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected == i
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
