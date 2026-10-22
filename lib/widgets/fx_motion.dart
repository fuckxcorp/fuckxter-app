import 'dart:async';
import 'package:flutter/widgets.dart';

class FxReveal extends StatefulWidget {
  const FxReveal({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  State<FxReveal> createState() => _FxRevealState();
}

class _FxRevealState extends State<FxReveal>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(widget.delay, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      timer?.cancel();
      controller.value = 1;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) {
      if (controller.isCompleted) return child!;
      final opacity = Curves.easeOutCubic.transform(controller.value);
      final t = Curves.easeOutBack.transform(controller.value);
      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(-10 * (1 - t), -8 * (1 - t)),
          child: Transform.scale(scale: .98 + .02 * t, child: child),
        ),
      );
    },
  );
}
