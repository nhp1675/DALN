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
      Heading('Màn ảnh lớn. Cảm xúc trọn vẹn.', eyebrow: 'HÔM NAY, XEM GÌ?'),
      FutureBuilder<List<Json>>(
        future: future!,
        builder: (context, snapshot) =>
            HomeCarousel(movies: snapshot.data ?? const [], moviePath: detail),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 22,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'now', label: Text('Đang chiếu')),
              ButtonSegment(value: 'soon', label: Text('Sắp chiếu')),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          SizedBox(
            width: 300,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm phim, thể loại…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (s) => setState(() => query = s),
            ),
          ),
        ],
      ),
      const SizedBox(height: 26),
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
              final columns = c.maxWidth > 900
                  ? 4
                  : c.maxWidth > 650
                  ? 3
                  : 2;
              final gap = c.maxWidth < 600 ? 14.0 : 24.0;
              final width = (c.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 28,
                children: movies
                    .map(
                      (m) => SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => go(context, detail(m)),
                              child: Stack(
                                children: [
                                  Poster(m),
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Tag(sid(m['ageRating'])),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              sid(m['genre']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${m['duration']} phút',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: Text(
                                sid(m['title']),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: width < 200 ? 16 : 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => go(context, detail(m)),
                                child: Text(
                                  tab == 'now' ? 'Đặt vé' : 'Xem chi tiết',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
      const SizedBox(height: 36),
      const Divider(),
      const SizedBox(height: 22),
      const Text(
        'CineGo · Hẹn nhau ở rạp.',
        style: TextStyle(fontWeight: FontWeight.bold, color: ink),
      ),
      const SizedBox(height: 7),
      const Text(
        'Khám phá phim yêu thích và chọn suất chiếu phù hợp với bạn.',
        style: TextStyle(color: muted, fontSize: 13),
      ),
    ],
  );
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
  String cinema = '', day = '';
  @override
  void initState() {
    super.initState();
    cinema = widget.initialCinema ?? '';
  }

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
    await AppScope.of(context).api.request(
      '/showtimes?movieId=${widget.id}${cinema.isEmpty ? '' : '&cinemaId=$cinema'}${day.isEmpty ? '' : '&date=$day'}',
    ),
  );
  Future<void> chooseDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      setState(() {
        day =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        shows = loadShows();
      });
    }
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
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Poster(
                        movie,
                        width: small ? 95 : 240,
                        height: small ? 142 : 360,
                      ),
                      SizedBox(width: small ? 18 : 36),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tag('${status(movie['status'])} · 2D'),
                            const SizedBox(height: 14),
                            Text(
                              sid(movie['title']),
                              style: TextStyle(
                                fontSize: small ? 25 : 40,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Tag(sid(movie['ageRating'])),
                                Text(
                                  '${movie['duration']} phút',
                                  style: const TextStyle(color: muted),
                                ),
                                Text(
                                  sid(movie['genre']),
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                            if (!small) ...[
                              const SizedBox(height: 20),
                              Text(
                                sid(movie['synopsis']),
                                style: const TextStyle(height: 1.8),
                              ),
                              const SizedBox(height: 14),
                              InfoLine('Đạo diễn', sid(movie['director'])),
                              InfoLine('Diễn viên', sid(movie['cast'])),
                            ],
                          ],
                        ),
                      ),
                    ],
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
              const Heading('Lịch chiếu', eyebrow: 'GIỜ VIỆT NAM · UTC+7'),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: cinema,
                      decoration: const InputDecoration(labelText: 'Rạp chiếu'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tất cả rạp'),
                        ),
                        ...cinemas.map(
                          (c) => DropdownMenuItem(
                            value: sid(c['_id']),
                            child: Text(sid(c['name'])),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        cinema = v ?? '';
                        shows = loadShows();
                      }),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: chooseDay,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(day.isEmpty ? 'Chọn ngày' : day),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      day = '';
                      shows = loadShows();
                    }),
                    child: const Text('Tất cả ngày'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DataView<List<Json>>(
                future: shows!,
                retry: () => setState(() => shows = loadShows()),
                builder: (list) {
                  if (list.isEmpty) {
                    return const Empty(
                      'Chưa có lịch chiếu phù hợp. Vui lòng chọn ngày hoặc rạp khác.',
                    );
                  }
                  return Column(
                    children: cinemas
                        .where(
                          (c) => list.any((s) => s['cinemaId'] == c['_id']),
                        )
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sid(c['name']),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    sid(c['address']),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: list
                                        .where((s) => s['cinemaId'] == c['_id'])
                                        .map(
                                          (s) => OutlinedButton(
                                            onPressed: () => go(
                                              context,
                                              '/booking/${s['_id']}',
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  time(s['startAt']),
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  shortDate(s['startAt']),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'Từ ${money(s['standardPrice'])}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: muted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    ],
  );
}
