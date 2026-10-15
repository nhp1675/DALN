import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import 'common.dart';

const _gold = gold;

/// Slide giới thiệu (không phụ thuộc dữ liệu phim).
class _InfoSlide {
  final String eyebrow, title, text, cta, route;
  final IconData icon;
  const _InfoSlide({
    required this.eyebrow,
    required this.title,
    required this.text,
    required this.cta,
    required this.route,
    required this.icon,
  });
}

const _infoSlides = <_InfoSlide>[
  _InfoSlide(
    eyebrow: 'Khám phá CineGo',
    title: 'Chọn ghế đẹp.\nTrọn cảm xúc.',
    text:
        'Khám phá lịch chiếu, chọn ghế yêu thích và nhận vé điện tử trên CineGo.',
    cta: 'Khám phá hệ thống rạp',
    route: '/cinemas',
    icon: Icons.event_seat_outlined,
  ),
  _InfoSlide(
    eyebrow: 'Bỏng nước',
    title: 'Bỏng nước,\nnhận ngay tại rạp.',
    text:
        'Đặt bỏng nước kèm vé hoặc đặt riêng, rồi nhận tại quầy bằng mã nhận hàng.',
    cta: 'Đặt bỏng nước',
    route: '/snacks',
    icon: Icons.local_cafe_outlined,
  ),
  _InfoSlide(
    eyebrow: 'Khám phá CineGo',
    title: 'Hẹn nhau ở rạp.',
    text: 'Tìm rạp gần bạn và lên kế hoạch cho buổi xem phim tiếp theo.',
    cta: 'Tìm rạp gần bạn',
    route: '/cinemas',
    icon: Icons.location_on_outlined,
  ),
];

/// Film slides follow the active catalogue; information slides work without data.
class HomeCarousel extends StatefulWidget {
  final List<Json> movies;
  final String Function(Json) moviePath;
  const HomeCarousel({
    super.key,
    required this.movies,
    required this.moviePath,
  });
  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final controller = PageController(initialPage: 1);
  Timer? timer;
  int index = 0;
  int page = 1;
  bool moving = false;
  bool hover = false, focused = false, touching = false;
  List<Json> get movies =>
      widget.movies.where((m) => m['status'] == 'now').take(4).toList();
  int get count => movies.length + _infoSlides.length;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          hover ||
          focused ||
          touching ||
          !controller.hasClients ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      move(index + 1);
    });
  }

  Future<void> move(int next) async {
    if (!controller.hasClients || moving) return;
    moving = true;
    final target = next + 1;
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpToPage(target);
      } else {
        await controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
      wrapPage();
    } finally {
      moving = false;
    }
  }

  void wrapPage() {
    if (!mounted || !controller.hasClients) return;
    final current = controller.page?.round();
    if (current == 0) {
      controller.jumpToPage(count);
    }
    if (current == count + 1) {
      controller.jumpToPage(1);
    }
  }

  @override
  void didUpdateWidget(covariant HomeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies.where((m) => m["status"] == "now").take(4).length !=
        movies.length) {
      index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(1);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final films = movies;
    final tall = MediaQuery.sizeOf(context).width < 600;
    return Focus(
      onFocusChange: (v) => focused = v,
      child: MouseRegion(
        onEnter: (_) => hover = true,
        onExit: (_) => hover = false,
        child: Listener(
          onPointerDown: (_) => touching = true,
          onPointerUp: (_) => touching = false,
          onPointerCancel: (_) => touching = false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: tall ? 480 : 440,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: NotificationListener<ScrollEndNotification>(
                          onNotification: (_) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => wrapPage(),
                            );
                            return false;
                          },
                          child: PageView.builder(
                            controller: controller,
                            itemCount: count + 2,
                            onPageChanged: (v) => setState(() {
                              page = v;
                              index = (v - 1 + count) % count;
                            }),
                            itemBuilder: (context, raw) {
                              final i = (raw - 1 + count) % count;
                              final movie = i < films.length ? films[i] : null;
                              final info = movie == null
                                  ? _infoSlides[i - films.length]
                                  : null;
                              return _BannerSlide(
                                seed: i,
                                movie: movie,
                                info: info,
                                onAction: () => go(
                                  context,
                                  movie != null
                                      ? widget.moviePath(movie)
                                      : info!.route,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: tall ? 14 : 28,
                      right: tall ? 14 : 28,
                      bottom: 12,
                      child: _controls(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chỉ báo vị trí (bấm để nhảy) và hai nút chuyển slide.
  Widget _controls() {
    final arrow = IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .14),
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
    );
    return Row(
      children: [
        Expanded(
          child: Wrap(
            children: List.generate(
              count,
              (i) => Semantics(
                selected: i == index,
                child: IconButton(
                  tooltip: 'Slide ${i + 1}',
                  onPressed: () => move(i),
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: i == index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index ? _gold : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Slide trước',
          onPressed: () => move(index - 1),
          style: arrow,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Slide sau',
          onPressed: () => move(index + 1),
          style: arrow,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// Một slide: nền gradient có quầng sáng, nội dung bên trái, hình bên phải.
class _BannerSlide extends StatelessWidget {
  final int seed;
  final Json? movie;
  final _InfoSlide? info;
  final VoidCallback onAction;
  const _BannerSlide({
    required this.seed,
    required this.movie,
    required this.info,
    required this.onAction,
  });
  static const _tints = [
    Color(0xFF4A2B3A),
    Color(0xFF1F4257),
    Color(0xFF4B3A22),
    Color(0xFF2E2D5C),
  ];

  @override
  Widget build(BuildContext context) {
    final m = movie;
    final tint = _tints[seed % _tints.length];
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 600;
        final pad = compact ? 22.0 : 36.0;
        final chips = m == null
            ? <String>[]
            : [
                sid(m['genre']),
                if (m['duration'] != null) '${m['duration']} phút',
                sid(m['ageRating']),
              ].where((t) => t.trim().isNotEmpty).toList();
        final synopsis = m == null ? '' : sid(m['synopsis']).trim();
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [night, tint],
                  ),
                ),
              ),
            ),
            Positioned(right: -80, top: -100, child: _Glow(coral, 360)),
            Positioned(left: -100, bottom: -140, child: _Glow(_gold, 320)),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 84),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _gold.withValues(alpha: .45),
                                ),
                              ),
                              child: Text(
                                m != null ? 'Đang chiếu' : info!.eyebrow,
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              m != null ? sid(m['title']) : info!.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 28 : 44,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -.8,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (m != null) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [for (final t in chips) _Pill(t)],
                              ),
                              if (synopsis.isNotEmpty && !compact) ...[
                                const SizedBox(height: 12),
                                Text(
                                  synopsis,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFDEE5EB),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ] else
                              Text(
                                info!.text,
                                style: const TextStyle(
                                  color: Color(0xFFDEE5EB),
                                  height: 1.5,
                                ),
                              ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: onAction,
                              icon: Icon(
                                m != null
                                    ? Icons.local_movies_outlined
                                    : info!.icon,
                              ),
                              label: Text(
                                m != null ? 'Xem phim & lịch chiếu' : info!.cta,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: ink,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[const SizedBox(width: 32), _visual()],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _visual() {
    final m = movie;
    if (m != null) {
      return Transform.rotate(
        angle: .035,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Poster(m, width: 172, height: 258),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Container(
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [coral, _gold],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Icon(info!.icon, size: 80, color: Colors.white),
      ),
    );
  }
}

/// Nhãn nhỏ dạng viên thuốc (thể loại, thời lượng, độ tuổi).
class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Quầng sáng mờ trang trí phía sau nội dung.
class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow(this.color, this.size);
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .32), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}
