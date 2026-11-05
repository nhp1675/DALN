import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import 'common.dart';

class MovieReviews extends StatefulWidget {
  final String movieId;
  const MovieReviews({super.key, required this.movieId});
  @override
  State<MovieReviews> createState() => _MovieReviewsState();
}

class _MovieReviewsState extends State<MovieReviews> {
  final comment = TextEditingController();
  Future<Json>? future;
  int page = 1, rating = 0;
  bool busy = false, draftLoaded = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Json> load() async => asMap(
    await AppScope.of(context).api
        .request('/movies/${widget.movieId}/reviews?page=$page'),
  );
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  void refresh() => setState(() {
    future = load();
  });
  Future<void> save({bool remove = false}) async {
    if (busy) return;
    if (!remove && rating == 0) {
      setState(() => error = 'Vui lòng chọn từ 1 đến 5 sao.');
      return;
    }
    if (remove &&
        !await confirm(
          context,
          'Xóa đánh giá?',
          'Đánh giá và bình luận của bạn sẽ bị xóa.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.of(context).api.request(
        '/movies/${widget.movieId}/reviews/mine',
        method: remove ? 'DELETE' : 'PUT',
        body: remove ? null : {'rating': rating, 'comment': comment.text},
      );
      if (mounted) {
        if (remove) {
          rating = 0;
          comment.clear();
        }
        page = 1;
        refresh();
        notice(context, remove ? 'Đã xóa đánh giá.' : 'Đã lưu đánh giá.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 32),
      const Heading('Đánh giá & bình luận'),
      ErrorNote(error),
      DataView<Json>(
        future: future!,
        retry: refresh,
        builder: (data) {
          final mine = data['mine'] is Map ? asMap(data['mine']) : null;
          if (!draftLoaded) {
            rating = (mine?['rating'] as num?)?.toInt() ?? 0;
            comment.text = sid(mine?['comment']);
            draftLoaded = true;
          }
          final items = asList(data['items']);
          final total = (data['total'] as num).toInt();
          final pages = (data['pages'] as num).toInt();
          final counts = asMap(data['counts']);
          final eligible = data['canReview'] == true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? 'Chưa có đánh giá'
                          : '${(data['average'] as num).toStringAsFixed(1)}/5 ★ · $total đánh giá',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var stars = 5; stars >= 1; stars--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('$stars ★'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: total == 0
                                    ? 0
                                    : ((counts['$stars'] as num?) ?? 0) / total,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${counts['$stars'] ?? 0}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (AppScope.of(context).user == null)
                TextButton(
                  onPressed: () => go(
                    context,
                    '/login?next=${Uri.encodeComponent('/movies/${widget.movieId}')}',
                  ),
                  child: const Text('Đăng nhập để đánh giá'),
                )
              else if (eligible || mine != null)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đánh giá của bạn',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (mine?['hidden'] == true)
                        const Text(
                          'Đánh giá đã ẩn.',
                          style: TextStyle(color: muted),
                        ),
                      if (eligible) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          children: List.generate(
                            5,
                            (i) => IconButton(
                              tooltip: '${i + 1} sao',
                              onPressed: busy
                                  ? null
                                  : () => setState(() => rating = i + 1),
                              icon: Icon(
                                i < rating ? Icons.star : Icons.star_border,
                                color: coral,
                              ),
                            ),
                          ),
                        ),
                        TextField(
                          controller: comment,
                          maxLength: 1000,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Bình luận (không bắt buộc)',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (eligible)
                            FilledButton(
                              onPressed: busy ? null : () => save(),
                              child: Text(
                                mine == null ? 'Gửi đánh giá' : 'Lưu thay đổi',
                              ),
                            ),
                          if (mine != null)
                            OutlinedButton(
                              onPressed: busy ? null : () => save(remove: true),
                              child: const Text('Xóa đánh giá'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (AppScope.of(context).user == null || eligible || mine != null)
                const SizedBox(height: 20),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sid(item['name']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item['rating']}/5 ★ · ${dateTime(item['createdAt'])}',
                          style: const TextStyle(color: coral),
                        ),
                        if (sid(item['comment']).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(sid(item['comment'])),
                        ],
                      ],
                    ),
                  ),
                ),
              if (pages > 1)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: page <= 1 || busy
                          ? null
                          : () {
                              page--;
                              refresh();
                            },
                      child: const Text('Trước'),
                    ),
                    Text('Trang $page/$pages'),
                    OutlinedButton(
                      onPressed: page >= pages || busy
                          ? null
                          : () {
                              page++;
                              refresh();
                            },
                      child: const Text('Sau'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ],
  );
}

class ReviewModerationPanel extends StatefulWidget {
  const ReviewModerationPanel({super.key});
  @override
  State<ReviewModerationPanel> createState() => _ReviewModerationState();
}

class _ReviewModerationState extends State<ReviewModerationPanel> {
  Future<Json>? future;
  int page = 1;
  bool busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Json> load() async => asMap(
    await AppScope.of(context).api.request('/admin/reviews?page=$page'),
  );
  void refresh() => setState(() => future = load());
  Future<void> toggle(Json item) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.of(context).api.request(
        '/admin/reviews/${item['_id']}',
        method: 'PATCH',
        body: {'hidden': item['hidden'] != true},
      );
      if (mounted) refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ErrorNote(error),
      OutlinedButton.icon(
        onPressed: busy ? null : refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Làm mới đánh giá'),
      ),
      const SizedBox(height: 12),
      DataView<Json>(
        future: future!,
        retry: refresh,
        builder: (data) {
          final items = asList(data['items']), movies = asList(data['movies']);
          final pages = (data['pages'] as num).toInt();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty) const Empty('Chưa có đánh giá.'),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sid(byId(movies, item['movieId'])?['title']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${item['name']} · ${item['rating']}/5 ★ · ${dateTime(item['createdAt'])}',
                      ),
                      Text(sid(item['comment'])),
                      Text(
                        item['hidden'] == true ? 'Đang ẩn' : 'Đang hiển thị',
                        style: const TextStyle(color: muted),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => toggle(item),
                        child: Text(
                          item['hidden'] == true ? 'Khôi phục' : 'Ẩn đánh giá',
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: page <= 1 || busy
                        ? null
                        : () {
                            page--;
                            refresh();
                          },
                    child: const Text('Trước'),
                  ),
                  Text('Trang $page/$pages'),
                  OutlinedButton(
                    onPressed: page >= pages || busy
                        ? null
                        : () {
                            page++;
                            refresh();
                          },
                    child: const Text('Sau'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}
