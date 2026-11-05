import '../core/cinema_groups.dart';
import '../widgets/movie_reviews.dart';
import '../widgets/trailer.dart';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import '../widgets/home_carousel.dart';

class CatalogScreen extends StatefulWidget {
  final String? cinema;
  const CatalogScreen({super.key, this.cinema});
  @override
  State<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends State<CatalogScreen> {
  Future<List<Json>>? future;
  String query = '', tab = 'now';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<List<Json>> load() async =>
      asList(await AppScope.of(context).api.request('/movies'));
  String detail(Json m) =>
      '/movies/${m['_id']}${widget.cinema != null ? '?cinema=${Uri.encodeComponent(widget.cinema!)}' : ''}';
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      FutureBuilder<List<Json>>(
        future: future!,
        builder: (context, snapshot) =>
            HomeCarousel(movies: snapshot.data ?? const [], moviePath: detail),
      ),
      const SizedBox(height: 44),
      Heading(
        'Chọn phim',
        action: Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'now', label: Text('Đang chiếu')),
                ButtonSegment(value: 'soon', label: Text('Sắp chiếu')),
              ],
              selected: {tab},
              onSelectionChanged: (s) => setState(() => tab = s.first),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm phim, thể loại…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (s) => setState(() => query = s),
              ),
            ),
          ],
        ),
      ),
      DataView<List<Json>>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (all) {
          final movies = all
              .where(
                (m) =>
                    m['status'] == tab &&
                    '${m['title']} ${m['genre']}'.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
          if (movies.isEmpty) {
            return const Empty('Chưa có phim phù hợp. Thử từ khóa khác.');
          }
          return LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth > 1000
                  ? 5
                  : c.maxWidth > 820
                  ? 4
                  : c.maxWidth > 600
                  ? 3
                  : 2;
              final gap = c.maxWidth < 600 ? 14.0 : 24.0;
              final width = (c.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 32,
                children: [
                  for (final m in movies)
                    _MovieCard(
                      key: ValueKey(sid(m['_id'])),
                      movie: m,
                      width: width,
                      showing: tab == 'now',
                      onOpen: () => go(context, detail(m)),
                    ),
                ],
              );
            },
          );
        },
      ),
      const SizedBox(height: 40),
    ],
  );
}

/// Thẻ phim: poster, tên, thể loại và nút đặt vé. Nhấc nhẹ khi rê chuột.
class _MovieCard extends StatefulWidget {
  final Json movie;
  final double width;
  final bool showing;
  final VoidCallback onOpen;
  const _MovieCard({
    super.key,
    required this.movie,
    required this.width,
    required this.showing,
    required this.onOpen,
  });
  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final lifted = hover && !reduce;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: SizedBox(
        width: widget.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onOpen,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, lifted ? -4 : 0, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(lifted ? 0x40000000 : 0x14000000),
                      blurRadius: lifted ? 24 : 10,
                      offset: Offset(0, lifted ? 12 : 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Poster(m),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _AgeBadge(
                        m['ageRating'] == 'NO'
                            ? 'Chưa PL'
                            : sid(m['ageRating']),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: Text(
                sid(m['title']),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.width < 200 ? 16 : 17.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${sid(m['genre'])} · ${m['duration'] == null ? 'Chưa có thời lượng' : '${m['duration']} phút'}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onOpen,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(widget.showing ? 'Đặt vé' : 'Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgeBadge extends StatelessWidget {
  final String text;
  const _AgeBadge(this.text);
  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xD90C1117),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
}

// Chỉ mở trailer khi là liên kết HTTPS hợp lệ.
String? _trailerUrl(Json movie) {
  final u = Uri.tryParse(sid(movie['trailerUrl']).trim());
  return u != null && u.scheme == 'https' && u.host.isNotEmpty
      ? u.toString()
      : null;
}

class MovieScreen extends StatefulWidget {
  final String id;
  final String? initialCinema;
  const MovieScreen({super.key, required this.id, this.initialCinema});
  @override
  State<MovieScreen> createState() => _MovieState();
}

class _MovieState extends State<MovieScreen> {
  Future<Json>? future;
  Future<List<Json>>? shows;
  String city = '', day = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
    shows ??= loadShows();
  }

  Future<Json> load() async {
    final api = AppScope.of(context).api;
    final results = await Future.wait([
      api.request('/movies/${widget.id}'),
      api.request('/cinemas'),
    ]);
    return {'movie': results[0], 'cinemas': results[1]};
  }

  Future<List<Json>> loadShows() async => asList(
    await AppScope.of(context).api.request('/showtimes?movieId=${widget.id}'),
  );

  Widget schedule(List<Json> cinemas, List<Json> list) {
    final cities = groupCinemasByCity(cinemas);
    final dates = groupShowtimesByDate(list)..remove('');
    if (dates.isEmpty || cities.isEmpty) {
      return const Empty('Chưa có lịch chiếu.');
    }
    final initialCinema = byId(cinemas, widget.initialCinema);
    final initialCity = initialCinema == null ? '' : cinemaCity(initialCinema);
    final preferredDates = dates.entries.where(
      (entry) => entry.value.any(
        (show) =>
            widget.initialCinema != null &&
            show['cinemaId'] == widget.initialCinema,
      ),
    );
    final selectedDay = dates.containsKey(day)
        ? day
        : preferredDates.isNotEmpty
        ? preferredDates.first.key
        : dates.keys.first;
    final dayShows = dates[selectedDay]!;
    final availableCities = cities.entries.where(
      (entry) => entry.value.any(
        (cinema) => dayShows.any((show) => show['cinemaId'] == cinema['_id']),
      ),
    );
    final selectedCity = cities.containsKey(city)
        ? city
        : cities.containsKey(initialCity)
        ? initialCity
        : availableCities.isNotEmpty
        ? availableCities.first.key
        : cities.keys.first;
    final cinemaIds = dayShows.map((show) => show['cinemaId']).toSet();
    final venues = cities[selectedCity]!
        .where((cinema) => cinemaIds.contains(cinema['_id']))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final buttons = [
              for (final date in dates.keys)
                _ShowDateTile(
                  date: date,
                  selected: date == selectedDay,
                  onTap: () => setState(() {
                    day = date;
                    city = selectedCity;
                  }),
                ),
            ];
            if (box.maxWidth < 600) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final button in buttons)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: button,
                      ),
                  ],
                ),
              );
            }
            return Wrap(spacing: 6, runSpacing: 6, children: buttons);
          },
        ),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in cities.keys)
              ChoiceChip(
                label: Text(name),
                selected: name == selectedCity,
                onSelected: (_) => setState(() {
                  city = name;
                  day = selectedDay;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(),
        if (venues.isEmpty)
          const Empty('Không có suất chiếu.')
        else ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Tag('2D', color: coral),
          ),
          const Divider(),
          for (final cinema in venues) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sid(cinema['name']),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sid(cinema['address']),
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final show in dayShows.where(
                        (show) => show['cinemaId'] == cinema['_id'],
                      ))
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () =>
                              go(context, '/booking/${show['_id']}'),
                          child: Text(time(show['startAt'])),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      TextButton.icon(
        onPressed: () => go(context, '/'),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Danh sách phim'),
      ),
      const SizedBox(height: 20),
      DataView<Json>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (data) {
          final movie = asMap(data['movie']), cinemas = asList(data['cinemas']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final small = c.maxWidth < 650;
                  final threeCols = c.maxWidth >= 1080;
                  final trailer = _trailerUrl(movie);
                  const soft = Color(0xFFB8C2CC);
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag('${status(movie['status'])} · 2D', color: gold),
                      const SizedBox(height: 14),
                      Text(
                        sid(movie['title']),
                        style: TextStyle(
                          fontSize: small ? 25 : 40,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Tag(
                            movie['ageRating'] == 'NO'
                                ? 'Chưa phân loại'
                                : sid(movie['ageRating']),
                            color: Colors.white,
                          ),
                          Text(
                            movie['duration'] == null
                                ? 'Chưa có thời lượng'
                                : '${movie['duration']} phút',
                            style: const TextStyle(color: soft),
                          ),
                          Text(
                            sid(movie['genre']),
                            style: const TextStyle(color: soft),
                          ),
                        ],
                      ),
                      if (trailer != null && !threeCols) ...[
                        const SizedBox(height: 18),
                        Trailer(url: trailer, maxWidth: 360),
                      ],
                      if (!small) ...[
                        const SizedBox(height: 20),
                        Text(
                          sid(movie['synopsis']),
                          style: const TextStyle(
                            height: 1.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _HeroFact('Đạo diễn', sid(movie['director'])),
                        _HeroFact('Diễn viên', sid(movie['cast'])),
                      ],
                    ],
                  );
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [night, Color(0xFF1F2B38)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(small ? 18 : 32),
                      child: Flex(
                        direction: small ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Poster(
                            movie,
                            width: small ? 120 : 240,
                            height: small ? 180 : 360,
                          ),
                          SizedBox(
                            width: small ? 0 : 36,
                            height: small ? 16 : 0,
                          ),
                          if (small) info else Expanded(child: info),
                          if (trailer != null && threeCols) ...[
                            const SizedBox(width: 32),
                            SizedBox(
                              width: 340,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Trailer',
                                    style: TextStyle(
                                      color: soft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Trailer(url: trailer, maxWidth: 340),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (MediaQuery.sizeOf(context).width < 720) ...[
                const SizedBox(height: 22),
                Text(
                  sid(movie['synopsis']),
                  style: const TextStyle(height: 1.7),
                ),
                InfoLine('Đạo diễn', sid(movie['director'])),
                InfoLine('Diễn viên', sid(movie['cast'])),
              ],
              const SizedBox(height: 40),
              const Heading('Lịch chiếu', eyebrow: 'Giờ Việt Nam (UTC+7)'),
              DataView<List<Json>>(
                future: shows!,
                retry: () => setState(() => shows = loadShows()),
                builder: (list) => schedule(cinemas, list),
              ),
              MovieReviews(
                key: ValueKey('reviews-${widget.id}'),
                movieId: widget.id,
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ShowDateTile extends StatelessWidget {
  final String date;
  final bool selected;
  final VoidCallback onTap;
  const _ShowDateTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(date);
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    return Semantics(
      label: showDateLabel(date),
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.month.toString().padLeft(2, '0'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        weekdays[d.weekday - 1],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w600,
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

class _HeroFact extends StatelessWidget {
  final String label, value;
  const _HeroFact(this.label, this.value);
  @override
  Widget build(BuildContext context) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(color: Color(0xFF8C99A6)),
                ),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
}
