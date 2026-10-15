import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../platform/browser.dart';
import 'common.dart';

String? embedUrl(String raw) {
  final u = Uri.tryParse(raw);
  if (u == null || u.scheme != 'https') return null;
  String? id;
  if (u.host == 'youtu.be' && u.pathSegments.isNotEmpty) {
    id = u.pathSegments.first;
  }
  if ([
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'www.youtube-nocookie.com',
  ].contains(u.host)) {
    id = u.queryParameters['v'];
    if (u.pathSegments.length >= 2 &&
        ['embed', 'shorts'].contains(u.pathSegments.first)) {
      id = u.pathSegments[1];
    }
  }
  if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
    return 'https://www.youtube-nocookie.com/embed/$id?rel=0';
  }
  if (['vimeo.com', 'www.vimeo.com'].contains(u.host) &&
      u.pathSegments.isNotEmpty &&
      RegExp(r'^\d+$').hasMatch(u.pathSegments.last)) {
    return 'https://player.vimeo.com/video/${u.pathSegments.last}';
  }
  return null;
}

String? _youtubeThumb(String src) {
  final u = Uri.parse(src);
  return u.host == 'www.youtube-nocookie.com' && u.pathSegments.length >= 2
      ? 'https://i.ytimg.com/vi/${u.pathSegments.last}/hqdefault.jpg'
      : null;
}

/// Trailer nhỏ gọn. Chưa bấm phát thì chỉ là ảnh bìa nên cuộn chuột trên video vẫn
/// cuộn trang bình thường; iframe chỉ được tạo khi người xem bấm phát.
class Trailer extends StatefulWidget {
  final String url;
  final double maxWidth;
  const Trailer({super.key, required this.url, this.maxWidth = 400});
  @override
  State<Trailer> createState() => _TrailerState();
}

class _TrailerState extends State<Trailer> {
  bool playing = false;

  Widget _cover(String? thumb) => Semantics(
    button: true,
    label: 'Phát trailer',
    child: InkWell(
      onTap: () => setState(() => playing = true),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: night),
          if (thumb != null)
            Image.network(
              thumb,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (c, e, s) => const SizedBox.shrink(),
            ),
          const ColoredBox(color: Color(0x33000000)),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: coral,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _player(String src) {
    final uri = Uri.parse(src);
    final playSrc = uri
        .replace(queryParameters: {...uri.queryParameters, 'autoplay': '1'})
        .toString();
    return HtmlElementView.fromTagName(
      key: ValueKey(playSrc),
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as web.HTMLIFrameElement;
        frame.src = playSrc;
        frame.title = 'Trailer phim';
        frame.allow =
            'autoplay; fullscreen; encrypted-media; picture-in-picture';
        frame.referrerPolicy = 'strict-origin-when-cross-origin';
        frame.style.width = '100%';
        frame.style.height = '100%';
        frame.style.border = '0';
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = embedUrl(widget.url);
    if (src == null) {
      // Nguồn không nhúng được (không phải YouTube/Vimeo): mở trang gốc.
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => openExternal(widget.url),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Xem trailer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0x66FFFFFF)),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: playing ? _player(src) : _cover(_youtubeThumb(src)),
        ),
      ),
    );
  }
}
