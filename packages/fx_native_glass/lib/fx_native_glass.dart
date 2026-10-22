import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class NativeGlass extends StatefulWidget {
  const NativeGlass({
    super.key,
    required this.dark,
    required this.radius,
    required this.fallback,
  });

  final bool dark;
  final double radius;
  final Widget fallback;

  @override
  State<NativeGlass> createState() => _NativeGlassState();
}

class _NativeGlassState extends State<NativeGlass> {
  static const channel = MethodChannel('site.fuckxter/native_glass');
  late final Future<bool> available = _available();

  Future<bool> _available() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return false;
    }
    try {
      return await channel.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: available,
    builder: (context, snapshot) {
      if (snapshot.data != true) return widget.fallback;
      final params = {'dark': widget.dark, 'radius': widget.radius};
      final key = ValueKey('${widget.dark}:${widget.radius}');
      return IgnorePointer(
        child: ExcludeSemantics(
          child: defaultTargetPlatform == TargetPlatform.iOS
              ? UiKitView(
                  key: key,
                  viewType: 'site.fuckxter/glass',
                  creationParams: params,
                  creationParamsCodec: const StandardMessageCodec(),
                )
              : AppKitView(
                  key: key,
                  viewType: 'site.fuckxter/glass',
                  creationParams: params,
                  creationParamsCodec: const StandardMessageCodec(),
                ),
        ),
      );
    },
  );
}
