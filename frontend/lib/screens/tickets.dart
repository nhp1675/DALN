import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import '../platform/browser.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override
  State<TicketsScreen> createState() => _TicketsState();
}

class _TicketsState extends State<TicketsScreen> {
  Future<Json>? future;
  bool busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Json> load() async {
    final api = AppScope.of(context).api;
    final r = await Future.wait([
      api.request('/tickets'),
      api.request('/orders'),
    ]);
    return {...asMap(r[0]), 'orders': r[1]};
  }

  void refresh() => setState(() => future = load());
  Future<void> cancel(Json t) async {
    final refund =
        ((t['currentValue'] as num) *
                (t['policy']['refundPercent'] as num) /
                100)
            .floor();
    if (!await confirm(
      context,
      'Hủy vé này?',
      'Vé sẽ mất hiệu lực. Khoản hoàn mô phỏng: ${money(refund)}.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    final s = AppScope.of(context);
    try {
      await s.api.request('/tickets/${t['_id']}/cancel', method: 'POST');
      await s.refresh();
      if (mounted) {
        refresh();
        notice(context, 'Đã hủy vé.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exchange(Json t, Json show) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final r = await Future.wait([
        api.request('/showtimes?movieId=${show['movieId']}'),
        api.request('/cinemas'),
      ]);
      if (!mounted) return;
      final shows = asList(r[0]), cinemas = asList(r[1]);
      final id = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Chọn suất chiếu mới'),
          content: SizedBox(
            width: 520,
            height: 380,
            child: shows.isEmpty
                ? const Empty('Chưa có suất để đổi.')
                : ListView.separated(
                    itemCount: shows.length,
                    separatorBuilder: (c, i) => const Divider(),
                    itemBuilder: (c, i) {
                      final s = shows[i];
                      return ListTile(
                        title: Text(dateTime(s['startAt'])),
                        subtitle: Text(
                          '${byId(cinemas, s['cinemaId'])?['name'] ?? 'Rạp'} · Từ ${money(s['standardPrice'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(c, sid(s['_id'])),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (id != null && mounted) {
        go(context, '/booking/$id?exchange=${t['_id']}');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> join(Json t) async {
    if (!await confirm(
      context,
      'Tham gia phòng chat?',
      'Trò chuyện với những khách hàng cùng suất chiếu.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(
        context,
      ).api.request('/chat/${t['showtimeId']}/join', method: 'POST');
      if (mounted) go(context, '/chat/${t['showtimeId']}');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        'Vé của tôi',
        eyebrow: 'CÂU CHUYỆN TIẾP THEO CỦA BẠN',
        action: OutlinedButton.icon(
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Làm mới'),
        ),
      ),
      ErrorNote(error),
      DataView<Json>(
        future: future!,
        retry: refresh,
        builder: (d) {
          final tickets = asList(d['tickets']),
              orders = asList(d['orders']),
              shows = asList(d['shows']),
              movies = asList(d['movies']),
              cinemas = asList(d['cinemas']),
              seats = asList(d['seats']),
              refunds = asList(d['refunds']);
          final pending = orders
              .where((o) => o['status'] == 'pending')
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pending.isNotEmpty) ...[
                const Text(
                  'Đơn chờ thanh toán',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...pending.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      color: const Color(0xFFFFF5E4),
                      padding: const EdgeInsets.all(16),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '#${sid(o['_id']).substring(16)} · ${status(o['kind'])}',
                        ),
                        subtitle: Text('Giữ đến ${dateTime(o['expiresAt'])}'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => go(context, '/checkout/${o['_id']}'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (tickets.isEmpty)
                const Empty(
                  'Bạn chưa có vé. Khám phá phim đang chiếu để bắt đầu.',
                )
              else
                ...tickets.map((t) {
                  final show = byId(shows, t['showtimeId']) ?? {},
                      movie = byId(movies, show['movieId']) ?? {},
                      cinema = byId(cinemas, show['cinemaId']) ?? {},
                      seat = byId(seats, t['showtimeSeatId']) ?? {};
                  final eligible =
                      t['status'] == 'valid' &&
                      DateTime.parse(
                            sid(show['startAt']),
                          ).difference(DateTime.now()).inMinutes >=
                          (t['policy']['changeCutoffHours'] as num) * 60;
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag(
                        status(t['status']),
                        color: t['status'] == 'valid'
                            ? const Color(0xFF28784B)
                            : muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        sid(movie['title']),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        sid(cinema['name']),
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 8),
                      Text(dateTime(show['startAt'])),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Ghế ${seat['label']}',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            money(t['currentValue']),
                            style: const TextStyle(
                              color: coral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Mã vé: ${sid(t['_id']).substring(12)}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (eligible) ...[
                            OutlinedButton(
                              onPressed: busy ? null : () => exchange(t, show),
                              child: const Text('Đổi vé'),
                            ),
                            OutlinedButton(
                              onPressed: busy ? null : () => cancel(t),
                              child: const Text('Hủy vé'),
                            ),
                          ],
                          if (t['status'] == 'valid' &&
                              DateTime.parse(
                                sid(show['endAt']),
                              ).isAfter(DateTime.now()))
                            OutlinedButton.icon(
                              onPressed: busy ? null : () => join(t),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 17,
                              ),
                              label: const Text('Tham gia chat'),
                            ),
                        ],
                      ),
                      ...refunds
                          .where((r) => r['ticketId'] == t['_id'])
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Hoàn mô phỏng: ${money(r['amount'])} · ${status(r['status'])}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Panel(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final qr = t['status'] == 'valid'
                              ? TicketQr(value: sid(t['qr']))
                              : Tag(status(t['status']));
                          if (c.maxWidth < 650) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Poster(movie, width: 65, height: 98),
                                    const SizedBox(width: 14),
                                    Expanded(child: details),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Divider(),
                                Center(child: qr),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Poster(movie, width: 135, height: 203),
                              const SizedBox(width: 26),
                              Expanded(child: details),
                              const SizedBox(width: 22),
                              qr,
                            ],
                          );
                        },
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử đơn',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Mã đơn')),
                          DataColumn(label: Text('Thời gian')),
                          DataColumn(label: Text('Loại')),
                          DataColumn(label: Text('Số tiền')),
                          DataColumn(label: Text('Trạng thái')),
                        ],
                        rows: orders
                            .map(
                              (o) => DataRow(
                                cells: [
                                  DataCell(
                                    TextButton(
                                      onPressed: () =>
                                          go(context, '/checkout/${o['_id']}'),
                                      child: Text(
                                        '#${sid(o['_id']).substring(16)}',
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(dateTime(o['createdAt']))),
                                  DataCell(Text(status(o['kind']))),
                                  DataCell(Text(money(o['total']))),
                                  DataCell(Text(status(o['status']))),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class TicketQr extends StatelessWidget {
  final String value;
  const TicketQr({super.key, required this.value});
  Future<void> download(BuildContext context) async {
    try {
      final data = await QrPainter(
        data: value,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
      ).toImageData(600);
      if (data != null) {
        downloadData(
          'cinego-ticket-qr.png',
          'data:image/png;base64,${base64Encode(data.buffer.asUint8List())}',
        );
      }
    } catch (e) {
      if (context.mounted) notice(context, 'Không tải được QR: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: 'Mã QR vé điện tử',
        image: true,
        child: QrImageView(
          data: value,
          size: 170,
          backgroundColor: Colors.white,
        ),
      ),
      TextButton.icon(
        onPressed: () => download(context),
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Tải mã QR'),
      ),
    ],
  );
}
