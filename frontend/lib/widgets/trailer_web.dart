import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../platform/browser.dart';

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

class Trailer extends StatelessWidget {
  final String url;
  const Trailer({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    final src = embedUrl(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trailer',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (src != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: HtmlElementView.fromTagName(
              key: ValueKey(src),
              tagName: 'iframe',
              onElementCreated: (element) {
                final frame = element as web.HTMLIFrameElement;
                frame.src = src;
                frame.title = 'Trailer phim';
                frame.allow = 'fullscreen; encrypted-media; picture-in-picture';
                frame.referrerPolicy = 'strict-origin-when-cross-origin';
                frame.style.width = '100%';
                frame.style.height = '100%';
                frame.style.border = '0';
              },
            ),
          )
        else
          const Text('Nguồn trailer này chưa hỗ trợ phát trong trang.'),
        TextButton(
          onPressed: () => openExternal(url),
          child: const Text('Không phát được? Mở trailer gốc'),
        ),
      ],
    );
  }
}
