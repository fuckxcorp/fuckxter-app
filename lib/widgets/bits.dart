import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    required this.fit,
    this.width,
    this.height,
    this.fallback,
    this.headers,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final error =
        fallback ??
        const SizedBox(
          height: 120,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final logical = width != null && width!.isFinite
            ? width!
            : constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final pixels = (logical * ratio).clamp(48, 2048).round();
        final size = [
          128,
          640,
          1280,
          2048,
        ].firstWhere((size) => size >= pixels);
        final Uri uri;
        try {
          uri = FuckXterApi.displayUri(url, size);
        } on FormatException {
          return error;
        } on ApiException {
          return error;
        }
        return Image(
          image: ResizeImage.resizeIfNeeded(
            pixels,
            null,
            MediaImage(uri, cookie: headers?['Cookie']),
          ),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => error,
          frameBuilder: (_, child, frame, synchronous) =>
              synchronous || frame != null
              ? child
              : SizedBox(
                  width: width,
                  height: height ?? 120,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        );
      },
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 28});
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'FuckXter',
      child: Image.asset(
        'assets/brand/fuckxter-wordmark-v8.png',
        height: height,
        color: dark ? const Color(0xFFF2F4F6) : const Color(0xFF101215),
        colorBlendMode: BlendMode.srcIn,
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
  ).showSnackBar(const SnackBar(content: Text('已复制链接')));
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
      message: label,
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
      child: Text(text, textAlign: TextAlign.center),
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确定'),
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
