import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import 'common.dart';

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
  final controller = PageController();
  Timer? timer;
  int index = 0;
  bool paused = false, hover = false, focused = false, touching = false;
  List<Json> get movies =>
      widget.movies.where((m) => m['status'] == 'now').take(4).toList();
  int get count => movies.length + 2;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted ||
          paused ||
          hover ||
          focused ||
          touching ||
          !controller.hasClients ||
          !TickerMode.of(context) ||
          MediaQuery.disableAnimationsOf(context))
        return;
      move(index + 1);
    });
  }

  void move(int next) {
    if (!controller.hasClients) return;
    final target = (next + count) % count;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(target);
    } else {
      controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void didUpdateWidget(covariant HomeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (index >= count) {
      index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(0);
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
    return Focus(
      onFocusChange: (v) => focused = v,
      child: MouseRegion(
        onEnter: (_) => hover = true,
        onExit: (_) => hover = false,
        child: Listener(
          onPointerDown: (_) => touching = true,
          onPointerUp: (_) => touching = false,
          onPointerCancel: (_) => touching = false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: ink,
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).width < 600 ? 360 : 330,
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: PageView.builder(
                        controller: controller,
                        itemCount: count,
                        onPageChanged: (v) => setState(() => index = v),
                        itemBuilder: (context, i) {
                          final movie = i < films.length ? films[i] : null;
                          final cinema = i == films.length;
                          final title =
                              movie?['title'] as String? ??
                              (cinema
                                  ? 'Hẹn nhau ở rạp.'
                                  : 'Chọn ghế đẹp.\nTrọn cảm xúc.');
                          final subtitle = movie == null
                              ? (cinema
                                    ? 'Tìm rạp gần bạn và lên kế hoạch cho buổi xem phim tiếp theo.'
                                    : 'Khám phá lịch chiếu, chọn ghế yêu thích và nhận vé điện tử trên CineGo.')
                              : '${movie['genre']} • ${movie['duration']} phút • ${movie['ageRating']}';
                          return LayoutBuilder(
                            builder: (context, c) {
                              final compact = c.maxWidth < 600;
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      ink,
                                      i.isEven
                                          ? const Color(0xFF354857)
                                          : const Color(0xFF663D45),
                                    ],
                                  ),
                                ),
                                padding: EdgeInsets.all(compact ? 22 : 32),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              movie != null
                                                  ? 'TIÊU ĐIỂM ĐIỆN ẢNH'
                                                  : 'KHÁM PHÁ CINEGO',
                                              style: const TextStyle(
                                                color: Color(0xFFE6C891),
                                                letterSpacing: 2,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: compact ? 27 : 37,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                height: 1.15,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                color: Color(0xFFDEE5EB),
                                                height: 1.5,
                                              ),
                                            ),
                                            const SizedBox(height: 22),
                                            FilledButton.icon(
                                              onPressed: () => go(
                                                context,
                                                movie != null
                                                    ? widget.moviePath(movie)
                                                    : '/cinemas',
                                              ),
                                              icon: Icon(
                                                movie != null
                                                    ? Icons
                                                          .local_movies_outlined
                                                    : Icons
                                                          .location_on_outlined,
                                              ),
                                              label: Text(
                                                movie != null
                                                    ? 'Xem phim & lịch chiếu'
                                                    : 'Tìm rạp gần bạn',
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFE6C891,
                                                ),
                                                foregroundColor: ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!compact) ...[
                                      const SizedBox(width: 28),
                                      if (movie != null)
                                        Poster(movie, width: 175, height: 263)
                                      else
                                        const Icon(
                                          Icons.local_activity_outlined,
                                          size: 150,
                                          color: Color(0xFFE6C891),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Slide trước',
                          onPressed: () => move(index - 1),
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: List.generate(
                              count,
                              (i) => Semantics(
                                selected: i == index,
                                child: IconButton(
                                  tooltip: 'Slide ${i + 1}',
                                  onPressed: () => move(i),
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 44,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    i == index
                                        ? Icons.circle
                                        : Icons.circle_outlined,
                                    size: 10,
                                    color: const Color(0xFFE6C891),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: paused ? 'Tự chuyển slide' : 'Tạm dừng',
                          onPressed: () => setState(() => paused = !paused),
                          icon: Icon(
                            paused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Slide sau',
                          onPressed: () => move(index + 1),
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
