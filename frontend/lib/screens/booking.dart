import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class BookingScreen extends StatefulWidget {
  final String id;
  final String? exchangeId;
  const BookingScreen({super.key, required this.id, this.exchangeId});
  @override
  State<BookingScreen> createState() => _BookingState();
}

class _BookingState extends State<BookingScreen> {
  Future<Json>? future;
  Json? data;
  Timer? timer;
  final Set<String> selected = {};
  bool busy = false, polling = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (future == null) {
      future = load();
      timer = Timer.periodic(const Duration(seconds: 8), (_) => poll());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<Json> load() async {
    final api = AppScope.of(context).api;
    final d = asMap(await api.request('/showtimes/${widget.id}/seats'));
    final a = await Future.wait([
      api.request('/movies/${d['showtime']['movieId']}'),
      api.request('/cinemas'),
    ]);
    d['movie'] = a[0];
    d['cinema'] = byId(asList(a[1]), d['showtime']['cinemaId']);
    data = d;
    return d;
  }

  Future<void> poll() async {
    if (!mounted || polling || busy) return;
    polling = true;
    try {
      final d = asMap(
        await AppScope.of(context).api.request('/showtimes/${widget.id}/seats'),
      );
      if (mounted && data != null) setState(() => data!['seats'] = d['seats']);
    } catch (_) {
      /* The next user action is still checked by the server. */
    } finally {
      polling = false;
    }
  }

  void toggle(Json seat) {
    final id = sid(seat['id']);
    setState(() {
      error = null;
      if (selected.contains(id)) {
        selected.remove(id);
      } else if (widget.exchangeId != null) {
        selected
          ..clear()
          ..add(id);
      } else if (selected.length < 8) {
        selected.add(id);
      } else {
        error = 'Mỗi đơn tối đa 8 ghế.';
      }
    });
  }

  Future<void> book() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final order = asMap(
        await api.request(
          widget.exchangeId == null
              ? '/orders'
              : '/tickets/${widget.exchangeId}/exchange',
          method: 'POST',
          body: widget.exchangeId == null
              ? {
                  'showtimeId': widget.id,
                  'seatIds': selected.toList(),
                  'idempotencyKey': const Uuid().v4(),
                }
              : {'seatId': selected.first, 'idempotencyKey': const Uuid().v4()},
        ),
      );
      if (mounted) go(context, '/checkout/${order['_id']}');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Steps(1),
      DataView<Json>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (initial) {
          final d = data ?? initial,
              seats = asList(d['seats']),
              movie = asMap(d['movie']),
              show = asMap(d['showtime']),
              cinema = d['cinema'] == null
                  ? <String, dynamic>{}
                  : asMap(d['cinema']);
          final chosen = seats
              .where((s) => selected.contains(sid(s['id'])))
              .toList();
          final total = chosen.fold<num>(0, (n, s) => n + (s['price'] as num));
          final rows =
              seats
                  .map((s) => sid(s['label']).replaceAll(RegExp(r'\d'), ''))
                  .toSet()
                  .toList()
                ..sort();
          return ResponsiveSplit(
            left: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heading(
                    'Chọn ghế ngồi',
                    eyebrow: widget.exchangeId == null
                        ? 'VỊ TRÍ YÊU THÍCH CỦA BẠN'
                        : 'ĐỔI VÉ · CHỌN GHẾ MỚI',
                  ),
                  Tag(sid(d['room']['name'])),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFB2C9CE), width: 4),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE7F0F0), Colors.white],
                        ),
                      ),
                      child: const Text(
                        'M À N   H Ì N H',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: rows.map((row) {
                          final list =
                              seats
                                  .where(
                                    (s) =>
                                        sid(
                                          s['label'],
                                        ).replaceAll(RegExp(r'\d'), '') ==
                                        row,
                                  )
                                  .toList()
                                ..sort(
                                  (a, b) =>
                                      int.parse(
                                        sid(
                                          a['label'],
                                        ).replaceAll(RegExp(r'\D'), ''),
                                      ).compareTo(
                                        int.parse(
                                          sid(
                                            b['label'],
                                          ).replaceAll(RegExp(r'\D'), ''),
                                        ),
                                      ),
                                );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    row,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ),
                                ...list.map((s) {
                                  final active = selected.contains(
                                        sid(s['id']),
                                      ),
                                      available = s['status'] == 'available',
                                      vip = s['type'] == 'vip';
                                  final bg = !available
                                      ? const Color(0xFFE2E4E5)
                                      : active
                                      ? coral
                                      : vip
                                      ? const Color(0xFFFFF1D2)
                                      : const Color(0xFFEEF6F0);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Semantics(
                                      label:
                                          'Ghế ${s['label']}, ${money(s['price'])}, ${status(s['status'])}',
                                      selected: active,
                                      button: true,
                                      child: Tooltip(
                                        message:
                                            '${s['label']} · ${money(s['price'])}',
                                        child: SizedBox(
                                          width: 40,
                                          height: 38,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              backgroundColor: bg,
                                              foregroundColor:
                                                  active && available
                                                  ? Colors.white
                                                  : ink,
                                              side: BorderSide(
                                                color: active
                                                    ? coral
                                                    : const Color(0xFFD6DEDA),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(7),
                                              ),
                                            ),
                                            onPressed: available && !busy
                                                ? () => toggle(s)
                                                : null,
                                            child: Text(
                                              sid(s['label']),
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Vuốt ngang để xem toàn bộ sơ đồ ghế.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Tag('Thường', color: Color(0xFF427D5A)),
                      Tag('VIP', color: Color(0xFF9D7827)),
                      Tag('Đang chọn', color: coral),
                      Tag('Đã đặt/giữ', color: muted),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Ghế được giữ ${AppScope.of(context).policy['holdMinutes'] ?? 10} phút sau khi bấm Tiếp tục. Trước đó người khác vẫn có thể đặt.',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            right: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Poster(movie, width: 75, height: 112),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tag('${movie['ageRating']} · 2D'),
                            const SizedBox(height: 12),
                            Text(
                              sid(movie['title']),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  InfoLine('Rạp', sid(cinema['name'])),
                  InfoLine('Suất chiếu', dateTime(show['startAt'])),
                  InfoLine(
                    'Ghế đã chọn',
                    chosen.isEmpty
                        ? 'Chưa chọn'
                        : chosen.map((s) => s['label']).join(', '),
                  ),
                  const Divider(),
                  ...chosen.map(
                    (s) => InfoLine(
                      '${s['label']} · ${s['type'] == 'vip' ? 'VIP' : 'Thường'}',
                      money(s['price']),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.exchangeId == null ? 'Tổng tiền' : 'Giá ghế mới',
                    style: const TextStyle(color: muted),
                  ),
                  Text(
                    money(total),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: coral,
                    ),
                  ),
                  if (widget.exchangeId != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Khoản chênh lệch sẽ được tính ở bước tiếp theo.',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ),
                  ErrorNote(error),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          busy ||
                              chosen.isEmpty ||
                              chosen.any((s) => s['status'] != 'available')
                          ? null
                          : book,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(busy ? 'Đang giữ ghế…' : 'Tiếp tục'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => go(context, '/movies/${movie['_id']}'),
                    child: const Text('Chọn suất khác'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

class CheckoutScreen extends StatefulWidget {
  final String id;
  const CheckoutScreen({super.key, required this.id});
  @override
  State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> {
  Future<Json>? future;
  Timer? timer;
  bool busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (future == null) {
      future = load();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<Json> load() async =>
      asMap(await AppScope.of(context).api.request('/orders/${widget.id}'));
  Future<void> pay(String outcome) async {
    setState(() {
      busy = true;
      error = null;
    });
    final s = AppScope.of(context);
    try {
      final order = asMap(
        await s.api.request(
          '/orders/${widget.id}/pay-demo',
          method: 'POST',
          body: {'outcome': outcome},
        ),
      );
      if (order['status'] == 'paid') {
        await s.refresh();
        if (mounted) {
          notice(
            context,
            'Thanh toán mô phỏng thành công. Vé đã được phát hành.',
          );
          go(context, '/tickets');
        }
      } else if (mounted) {
        setState(() {
          error =
              'Thanh toán thử thất bại. Vé chưa được phát hành; bạn có thể thử lại khi ghế còn được giữ.';
          future = load();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    if (!await confirm(context, 'Hủy đơn?', 'Ghế đang giữ sẽ được trả lại.')) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(
        context,
      ).api.request('/orders/${widget.id}/cancel', method: 'POST');
      if (mounted) go(context, '/tickets');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Steps(2),
      DataView<Json>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (d) {
          final o = asMap(d['order']),
              movie = asMap(d['movie']),
              seats = asList(d['seats']);
          final seconds = DateTime.parse(
            sid(o['expiresAt']),
          ).difference(DateTime.now()).inSeconds.clamp(0, 36000);
          final pending = o['status'] == 'pending' && seconds > 0;
          return ResponsiveSplit(
            left: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Heading(
                  o['kind'] == 'exchange'
                      ? 'Xác nhận đổi vé'
                      : 'Thanh toán & nhận vé',
                  eyebrow: 'KIỂM TRA LẠI MỘT CHÚT',
                ),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sid(movie['title']),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InfoLine('Rạp', sid(d['cinema']['name'])),
                      InfoLine('Suất chiếu', dateTime(d['show']['startAt'])),
                      InfoLine('Ghế', seats.map((s) => s['label']).join(', ')),
                      InfoLine('Trạng thái', status(o['status'])),
                      InfoLine('Mã đơn', widget.id),
                      if (o['status'] == 'pending')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Tag(
                            seconds > 0
                                ? 'Giữ ghế còn ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
                                : 'Hết thời gian giữ ghế',
                            color: coral,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phương thức thanh toán',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (AppScope.of(context).isDemo) ...[
                        const Tag(
                          'Thanh toán thử nghiệm · Không thu tiền thật',
                          color: coral,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Không nhập thông tin thẻ hoặc chuyển tiền thật. Chế độ này dùng để thử luồng thành công và thất bại.',
                        ),
                      ] else
                        const Text('Dịch vụ thanh toán chưa được cấu hình.'),
                    ],
                  ),
                ),
              ],
            ),
            right: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi tiết thanh toán',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 22),
                  const Text('Cần thanh toán', style: TextStyle(color: muted)),
                  Text(
                    money(o['total']),
                    style: const TextStyle(
                      color: coral,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (o['kind'] == 'exchange') ...[
                    InfoLine('Giá vé mới', money(o['newValue'])),
                    InfoLine('Hoàn chênh', money(o['refundAmount'])),
                    const Text(
                      'Vé cũ giữ nguyên đến khi đổi thành công. Mã QR sẽ được thay mới.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Chính sách đề xuất: hủy/đổi trước ${o['policy']['changeCutoffHours']} giờ; hoàn ${o['policy']['refundPercent']}% khi hủy.',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  ErrorNote(error),
                  const SizedBox(height: 22),
                  if (pending) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy || !AppScope.of(context).isDemo
                            ? null
                            : () => pay('success'),
                        child: Text(
                          busy ? 'Đang xử lý…' : 'Xác nhận thanh toán mô phỏng',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (AppScope.of(context).isDemo)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: busy ? null : () => pay('failed'),
                          child: const Text('Thử thanh toán thất bại'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: busy ? null : cancel,
                      child: const Text('Hủy đơn và trả ghế'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => go(
                        context,
                        o['status'] == 'paid'
                            ? '/tickets'
                            : '/movies/${movie['_id']}',
                      ),
                      child: Text(
                        o['status'] == 'paid'
                            ? 'Xem vé của tôi'
                            : 'Chọn lại suất chiếu',
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}
