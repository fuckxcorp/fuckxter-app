import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../services/fuckxter_api.dart';
import '../services/media_image.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.size,
    this.url,
    this.headers,
  });

  final String name;
  final double size;
  final String? url;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final letter = name.characters.firstOrNull?.toUpperCase() ?? '?';
    final fallback = ColoredBox(
      color: const Color(0xFF5B7AA8),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url == null || url!.isEmpty
            ? fallback
            : NetImage(
                url: url!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                fallback: fallback,
                headers: headers,
              ),
      ),
    );
  }
}

// Cache the public alpha mask, never the user's avatar pixels.
final _avatarMask = _makeAvatarMask();
Future<ui.Image> _makeAvatarMask() async {
  const bounds = Rect.fromLTWH(0, 0, 240, 240);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(4);
  const rect = Rect.fromLTWH(0, 0, 60, 60);
  final upper = Path()
    ..moveTo(0, 0)
    ..lineTo(60, 0)
    ..lineTo(60, 60)
    ..close();
  const colors = [Colors.white, Color(0xD9FFFFFF), Color(0x00FFFFFF)];
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(10, 10), 82.5, colors, [
        .3,
        .45,
        .72,
      ]),
  );
  canvas.drawPath(
    upper,
    Paint()
      ..blendMode = BlendMode.src
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(60, 60), colors, [
        .466667,
        .6,
        .833333,
      ]),
  );
  canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 46), const Offset(0, 60), [
        Colors.white,
        Colors.transparent,
      ]),
  );
  canvas.drawPath(
    upper,
    Paint()
      ..blendMode = BlendMode.src
      ..shader = ui.Gradient.linear(const Offset(46, 0), const Offset(60, 0), [
        Colors.white,
        Colors.transparent,
      ]),
  );
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    bounds.width.toInt(),
    bounds.height.toInt(),
  );
  picture.dispose();
  return image;
}

class FxAvatar extends StatelessWidget {
  const FxAvatar({
    super.key,
    required this.name,
    required this.size,
    this.url,
    this.headers,
    this.mirror = false,
  });
  final String name;
  final double size;
  final String? url;
  final Map<String, String>? headers;
  final bool mirror;
  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: name.codeUnits.fold(0, (a, b) => a + b).isEven
              ? const [Color(0xFFFF8152), Color(0xFFFFBD72)]
              : const [Color(0xFF487DF7), Color(0xFF37C5C2)],
        ),
      ),
      child: Center(
        child: Text(
          name.characters.firstOrNull?.toUpperCase() ?? '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .48,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(size * .22)),
      child: url == null || url!.isEmpty
          ? fallback
          : NetImage(
              url: url!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              headers: headers,
              fallback: fallback,
            ),
    );
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<ui.Image>(
        future: _avatarMask,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.expand();
          Widget masked = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (_) => ui.ImageShader(
              snapshot.data!,
              TileMode.clamp,
              TileMode.clamp,
              Matrix4.diagonal3Values(size / 240, size / 240, 1).storage,
            ),
            child: mirror ? Transform.flip(flipX: true, child: image) : image,
          );
          if (mirror) masked = Transform.flip(flipX: true, child: masked);
          return masked;
        },
      ),
    );
  }
}

class NetImage extends StatefulWidget {
  const NetImage({
    super.key,
    required this.url,
    required this.fit,
    this.width,
    this.height,
    this.decodeWidth,
    this.fallback,
    this.headers,
    this.onDimensions,
    this.alignment = Alignment.center,
    this.focus = false,
  });
  final String url;
  final BoxFit fit;
  final double? width, height, decodeWidth;
  final Widget? fallback;
  final Map<String, String>? headers;
  final ValueChanged<Size>? onDimensions;
  final Alignment alignment;
  final bool focus;

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  ImageStream? stream;
  ImageProvider? provider;
  late final listener = ImageStreamListener(
    _size,
    onError: (Object error, StackTrace? stack) {},
  );
  void _size(ImageInfo info, bool synchronous) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    final source = provider;
    info.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && provider == source) widget.onDimensions?.call(size);
    });
  }

  @override
  void dispose() {
    stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error =
        widget.fallback ??
        const SizedBox(
          height: 120,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final logical =
            widget.decodeWidth ??
            (widget.width != null && widget.width!.isFinite
                ? widget.width!
                : constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width);
        final pixels = (logical * ratio).clamp(48, 2048).round();
        final size = [
          128,
          640,
          1280,
          2048,
        ].firstWhere((size) => size >= pixels);
        final Uri uri;
        try {
          uri = FuckXterApi.displayUri(widget.url, size);
        } on FormatException {
          return error;
        } on ApiException {
          return error;
        }
        final next = ResizeImage.resizeIfNeeded(
          pixels,
          null,
          MediaImage(uri, cookie: widget.headers?['Cookie']),
        );
        if (provider != next) {
          stream?.removeListener(listener);
          provider = next;
          if (widget.onDimensions != null) {
            stream = next.resolve(createLocalImageConfiguration(context));
            stream!.addListener(listener);
          }
        }
        return Image(
          image: next,
          fit: widget.fit,
          alignment: widget.alignment,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, __, ___) => error,
          frameBuilder: (_, child, frame, synchronous) {
            if (synchronous || frame != null) {
              return widget.focus && !synchronous
                  ? _ImageFocus(key: ValueKey(next), child: child)
                  : child;
            }
            return SizedBox(
              width: widget.width,
              height: widget.height ?? 120,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        );
      },
    );
  }
}

class _ImageFocus extends StatefulWidget {
  const _ImageFocus({super.key, required this.child});
  final Widget child;
  @override
  State<_ImageFocus> createState() => _ImageFocusState();
}

class _ImageFocusState extends State<_ImageFocus>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) controller.value = 1;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        child: widget.child,
        builder: (context, child) {
          if (controller.isCompleted) return child!;
          final t = const Cubic(.45, 0, .2, 1).transform(controller.value);
          final blur = t < .15
              ? 12.0
              : t < .55
              ? ui.lerpDouble(12, 5, (t - .15) / .4)!
              : t < .9
              ? ui.lerpDouble(5, 0, (t - .55) / .35)!
              : 0.0;
          return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: child,
          );
        },
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 28});
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _ImageFocus(
      child: Semantics(
        label: 'FuckXter',
        child: Image.asset(
          'assets/brand/fuckxter-wordmark-v8.png',
          height: height,
          color: dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215),
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}

void showError(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(SnackBar(content: Text('$error')));
}

Future<void> copyText(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: AppText('已复制链接')));
}

String relativeTime(DateTime value) {
  final delta = DateTime.now().difference(value.toLocal());
  if (delta.inMinutes < 1) return '刚刚';
  if (delta.inHours < 1) return '${delta.inMinutes} 分钟';
  if (delta.inDays < 1) return '${delta.inHours} 小时';
  if (delta.inDays < 30) return '${delta.inDays} 天';
  return '${value.month}月${value.day}日';
}

String compactCount(int value) =>
    value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : '$value';

String visibilityLabel(String value) => switch (value) {
  'mutual' => '互关可见',
  'private' => '仅自己',
  _ => '公开',
};

class CountAction extends StatelessWidget {
  const CountAction({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.active = false,
    this.activeColor = const Color(0xFF5B7AA8),
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int? value;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? activeColor
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tr(context, label),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              if (value != null) ...[
                const SizedBox(width: 5),
                Text(
                  compactCount(value!),
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: AppText(text, textAlign: TextAlign.center),
    ),
  );
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(strokeWidth: 2));
}

Future<bool> confirm(BuildContext context, String title, String body) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const AppText('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const AppText('确定'),
        ),
      ],
    ),
  );
  return result == true;
}

String? imageType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.avif')) return 'image/avif';
  return null;
}

bool isAuthError(Object error) =>
    error is ApiException && (error.needsLogin || error.statusCode == 401);

Future<Uint8List> readPickedImage(PlatformFile file) async {
  const limit = 30 * 1024 * 1024;
  if ((file.lengthSync() ?? 0) > limit) {
    throw const ApiException('图片不能超过 30 MB。', 413);
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.readAsByteStream()) {
    if (bytes.length + chunk.length > limit) {
      throw const ApiException('图片不能超过 30 MB。', 413);
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
