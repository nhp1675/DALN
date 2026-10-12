import 'snacks.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../platform/browser.dart';
import '../widgets/common.dart';

const _methodLabels = {'vnpay': 'VNPay', 'atm': 'Thẻ ATM', 'momo': 'MoMo'};
const _methodIcons = {
  'vnpay': Icons.qr_code_2,
  'atm': Icons.credit_card,
  'momo': Icons.account_balance_wallet,
};

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
      if (mounted && data != null) {
        setState(() {
          data!['seats'] = d['seats'];
          dropTaken();
        });
      }
    } catch (_) {
      /* The next user action is still checked by the server. */
    } finally {
      polling = false;
    }
  }

  // Bỏ khỏi lựa chọn những ghế vừa bị người khác giữ/đặt và báo cho người dùng.
  void dropTaken() {
    final taken = asList(data?['seats'])
        .where(
          (s) => selected.contains(sid(s['id'])) && s['status'] != 'available',
        )
        .toList();
    if (taken.isEmpty) return;
    selected.removeAll(taken.map((s) => sid(s['id'])));
    error =
        'Ghế ${taken.map((s) => s['label']).join(', ')} vừa có người khác chọn nên đã được bỏ khỏi lựa chọn của bạn. Vui lòng chọn ghế khác.';
  }

  Future<void> refreshSeats() async {
    try {
      final d = asMap(
        await AppScope.of(context).api.request('/showtimes/${widget.id}/seats'),
      );
      if (mounted && data != null) {
        setState(() {
          data!['seats'] = d['seats'];
          dropTaken();
        });
      }
    } catch (_) {
      /* Lần thao tác sau vẫn được server kiểm tra. */
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
      final basket = await chooseSnacks(
        context,
        cinemaId: sid(data!['showtime']['cinemaId']),
        ticketId: widget.exchangeId,
      );
      if (basket == null || !mounted) return;
      final api = AppScope.of(context).api;
      final order = asMap(
        await api.request(
          widget.exchangeId == null
              ? '/orders'
              : '/tickets/${widget.exchangeId}/exchange',
          method: 'POST',
          body: widget.exchangeId == null
              ? {
                  'snacks': basket['snacks'],
                  'showtimeId': widget.id,
                  'seatIds': selected.toList(),
                  'idempotencyKey': const Uuid().v4(),
                }
              : {
                  'seatId': selected.first,
                  'idempotencyKey': const Uuid().v4(),
                  ...basket,
                },
        ),
      );
      if (mounted) go(context, '/checkout/${order['_id']}');
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
        // Ghế có thể vừa bị người khác lấy: tải lại sơ đồ và bỏ ghế đó khỏi lựa chọn.
        await refreshSeats();
      }
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
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFB2C9CE), width: 4),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            Theme.of(context).colorScheme.surface,
                          ],
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
                                      ? (active
                                            ? const Color(0xFFF6D3CE)
                                            : const Color(0xFFE2E4E5))
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
                                            onPressed:
                                                (available || active) && !busy
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
  // Kết quả khi VNPay chuyển khách quay lại: success | failed | invalid.
  final String? result;
  const CheckoutScreen({super.key, required this.id, this.result});
  @override
  State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> with RouteAware {
  Future<Json>? future;
  Timer? timer;
  bool busy = false;
  String? error;
  String method = 'vnpay';
  bool polling = false;
  bool checking = false;
  int ticks = 0;
  Api? api;
  bool subscribed = false,
      released = false,
      redirecting = false,
      confirming = false;
  String orderStatus = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    api = AppScope.of(context).api;
    final route = ModalRoute.of(context);
    if (!subscribed && route != null) {
      routeObserver.subscribe(this, route);
      subscribed = true;
    }
    if (future == null) {
      future = load();
      final ms = AppScope.of(context).paymentMethods;
      if (ms.isNotEmpty && !ms.contains(method)) method = ms.first;
      polling = widget.result == 'success';
      if (widget.result == 'failed') {
        error =
            'Thanh toán chưa thành công hoặc đã bị hủy. Bạn có thể thử lại khi ghế còn được giữ.';
      } else if (widget.result == 'invalid') {
        error = 'Không xác minh được kết quả thanh toán. Vui lòng thử lại.';
      }
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        ticks++;
        if (polling && ticks % 2 == 0) checkPaid();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    releaseSeats();
    timer?.cancel();
    super.dispose();
  }

  // Rời trang thanh toán khi chưa trả tiền (về trang chủ, quay lại...): trả ghế
  // ngay thay vì giữ khóa đến hết hạn.
  bool creatingPayment = false;

  bool get canRelease =>
      !creatingPayment &&
      !released &&
      !redirecting &&
      !confirming &&
      !polling &&
      widget.result != 'success' &&
      orderStatus == 'pending';
  void releaseSeats() {
    if (!canRelease) return;
    released = true;
    api
        ?.request('/orders/${widget.id}/cancel', method: 'POST')
        .catchError((_) => null);
  }

  @override
  void didPushNext() => releaseSeats();
  @override
  void didPop() => releaseSeats();
  @override
  void didPopNext() {
    if (released && mounted) setState(() => future = load());
  }

  Future<Json> load() async {
    final d = asMap(
      await AppScope.of(context).api.request('/orders/${widget.id}'),
    );
    orderStatus = sid(asMap(d['order'])['status']);
    return d;
  }

  // Sau khi VNPay chuyển về, đợi server xác nhận (qua IPN hoặc return URL).
  Future<void> checkPaid() async {
    if (checking) return;
    checking = true;
    final s = AppScope.of(context);
    try {
      final d = await load();
      final status = asMap(d['order'])['status'];
      if (!mounted) return;
      if (status == 'paid') {
        polling = false;
        await s.refresh();
        if (mounted) {
          go(
            context,
            asMap(d['order'])['kind'] == 'snack'
                ? '/snacks'
                : '/tickets?payment=success',
          );
        }
      } else if (status != 'pending' || ticks > 30) {
        polling = false;
        setState(() {
          future = Future.value(d);
          error =
              'Chưa xác nhận được thanh toán cho đơn này. Nếu tài khoản đã bị trừ tiền, hãy liên hệ quản trị viên kèm mã đơn ${widget.id}.';
        });
      }
    } catch (_) {
      // Lỗi mạng tạm thời: thử lại ở lần kiểm tra sau.
    } finally {
      checking = false;
    }
  }

  Future<void> startPayment() async {
    if (busy || released) return;
    final route = ModalRoute.of(context);
    creatingPayment = true;
    setState(() {
      busy = true;
      error = null;
    });
    final s = AppScope.of(context);
    try {
      final r = asMap(
        await s.api.request(
          '/orders/${widget.id}/pay',
          method: 'POST',
          body: {'method': method},
        ),
      );
      if (r['paid'] == true) {
        orderStatus = 'paid';
        await s.refresh();
        if (mounted && route?.isCurrent == true) {
          notice(
            context,
            'Đơn không phát sinh thêm tiền. Vé đã được cập nhật.',
          );
          go(context, '/tickets');
        }
      } else if (r['paymentUrl'] != null) {
        if (!mounted || route?.isCurrent != true || released) return;
        redirecting = true; // sang cổng thanh toán: chưa nhả ghế
        redirectTo(sid(r['paymentUrl']));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      busy = false;
      creatingPayment = false;
      if (!mounted || route?.isCurrent != true) releaseSeats();
      if (mounted) setState(() {});
    }
  }

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
        orderStatus = 'paid';
        await s.refresh();
        if (mounted) {
          notice(context, 'Thanh toán mô phỏng thành công.');
          go(context, order['kind'] == 'snack' ? '/snacks' : '/tickets');
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
    confirming = true;
    final ok = await confirm(
      context,
      'Hủy đơn?',
      'Ghế đang giữ sẽ được trả lại.',
    );
    confirming = false;
    if (!ok || !mounted) return;
    released = true;
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
                      : o['kind'] == 'snack'
                      ? 'Thanh toán bỏng nước'
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
                      InfoLine(
                        o['kind'] == 'snack' ? 'Ngày nhận' : 'Suất chiếu',
                        o['kind'] == 'snack'
                            ? sid(o['pickupDate'])
                            : dateTime(d['show']['startAt']),
                      ),
                      if (o['kind'] != 'snack')
                        InfoLine(
                          'Ghế',
                          seats.map((s) => s['label']).join(', '),
                        ),
                      for (final line in asList(o['snacks'] ?? []))
                        InfoLine(
                          sid(line['name']),
                          '${line['quantity']} × ${money(line['price'])}',
                        ),
                      if ((o['oldSnackTotal'] as num? ?? 0) > 0)
                        InfoLine(
                          'Bỏng nước cũ chuyển đổi',
                          money(o['oldSnackTotal']),
                        ),
                      TextButton(
                        onPressed: () => go(context, '/snacks'),
                        child: const Text('Xem đơn & mã nhận bỏng nước'),
                      ),
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
                      ] else if (AppScope.of(context).isGateway) ...[
                        SegmentedButton<String>(
                          segments: [
                            for (final m in AppScope.of(context).paymentMethods)
                              ButtonSegment(
                                value: m,
                                label: Text(_methodLabels[m] ?? m),
                                icon: Icon(_methodIcons[m] ?? Icons.payment),
                              ),
                          ],
                          selected: {method},
                          onSelectionChanged: busy || polling
                              ? null
                              : (v) => setState(() => method = v.first),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          method == 'momo'
                              ? 'Bạn sẽ được chuyển sang MoMo để quét mã QR hoặc mở ứng dụng MoMo.'
                              : 'Bạn sẽ được chuyển sang cổng VNPay để chọn cách thanh toán (quét QR, thẻ ATM...).',
                        ),
                        if (polling)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Tag(
                              'Đang xác nhận thanh toán…',
                              color: coral,
                            ),
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
                        onPressed: busy || polling
                            ? null
                            : AppScope.of(context).isGateway
                            ? startPayment
                            : AppScope.of(context).isDemo
                            ? () => pay('success')
                            : null,
                        child: Text(
                          busy || polling
                              ? 'Đang xử lý…'
                              : AppScope.of(context).isGateway
                              ? 'Thanh toán qua ${method == 'atm'
                                    ? 'thẻ ATM'
                                    : method == 'momo'
                                    ? 'MoMo'
                                    : 'VNPay'}'
                              : 'Xác nhận thanh toán mô phỏng',
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
