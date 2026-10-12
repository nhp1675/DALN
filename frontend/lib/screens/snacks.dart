import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

Future<Json?> chooseSnacks(
  BuildContext context, {
  String? cinemaId,
  String? ticketId,
  bool cancelOnly = false,
}) async {
  final api = AppScope.of(context).api;
  final products = cinemaId == null
      ? <Json>[]
      : asList(await api.request('/snacks?cinemaId=$cinemaId'));
  final linked = ticketId == null
      ? <String, dynamic>{'lines': <Json>[]}
      : asMap(await api.request('/tickets/$ticketId/snacks'));
  if (!context.mounted) return null;
  final old = asList(linked['lines']);
  if (cancelOnly && old.isEmpty) {
    return {'snacks': <Json>[], 'snackChanges': <Json>[]};
  }
  return showDialog<Json>(
    context: context,
    builder: (context) => _SnackPicker(
      products: products,
      old: old,
      allRequired: linked['allRequired'] == true,
      cancelOnly: cancelOnly,
    ),
  );
}

class _SnackPicker extends StatefulWidget {
  final List<Json> products, old;
  final bool allRequired, cancelOnly;
  const _SnackPicker({
    required this.products,
    required this.old,
    required this.allRequired,
    required this.cancelOnly,
  });
  @override
  State<_SnackPicker> createState() => _SnackPickerState();
}

class _SnackPickerState extends State<_SnackPicker> {
  final Map<String, int> picked = {}, removed = {};
  @override
  void initState() {
    super.initState();
    for (final l in widget.old) {
      removed[sid(l['_id'])] = widget.allRequired
          ? (l['remaining'] as num).toInt()
          : 0;
    }
    if (widget.allRequired && !widget.cancelOnly) {
      for (final p in widget.products) {
        picked[sid(p['_id'])] = widget.old
            .where((l) => l['snackId'] == p['_id'])
            .fold<int>(0, (n, l) => n + (l['remaining'] as num).toInt())
            .clamp(0, 50);
      }
    }
  }

  int available(Json p) =>
      ((p["available"] as num).toInt() +
              widget.old
                  .where((l) => l["snackId"] == p["_id"])
                  .fold<int>(0, (n, l) => n + (removed[sid(l["_id"])] ?? 0)))
          .clamp(0, 50);

  Widget quantity(
    String name,
    int n,
    int max,
    void Function(int) change, {
    bool fixed = false,
  }) => Row(
    children: [
      Expanded(child: Text(name)),
      IconButton(
        onPressed: fixed || n == 0 ? null : () => change(n - 1),
        icon: const Icon(Icons.remove),
      ),
      Text('$n'),
      IconButton(
        onPressed: fixed || n >= max ? null : () => change(n + 1),
        icon: const Icon(Icons.add),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final cost = widget.products.fold<num>(
      0,
      (n, p) => n + (p['price'] as num) * (picked[sid(p['_id'])] ?? 0),
    );
    final credit = widget.old.fold<num>(
      0,
      (n, p) => n + (p['price'] as num) * (removed[sid(p['_id'])] ?? 0),
    );
    return AlertDialog(
      title: Text(widget.cancelOnly ? 'Bỏng nước cần hủy' : 'Chọn bỏng nước'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.old.isNotEmpty) ...[
                Text(
                  widget.allRequired
                      ? 'Đây là vé cuối của suất cũ: chuyển/hủy toàn bộ bỏng nước chưa nhận.'
                      : 'Chọn số lượng bỏng nước cũ đi kèm vé này:',
                ),
                ...widget.old.map(
                  (p) => quantity(
                    '${p['name']} · ${money(p['price'])}',
                    removed[sid(p['_id'])] ?? 0,
                    (p['remaining'] as num).toInt(),
                    (n) => setState(() => removed[sid(p['_id'])] = n),
                    fixed: widget.allRequired,
                  ),
                ),
                Text('Giá trị bỏng nước cũ: ${money(credit)}'),
                const Divider(),
              ],
              if (!widget.cancelOnly) ...[
                const Text(
                  'Chọn lại món tại rạp mới, hoặc để số lượng 0 nếu không mua. Giữ món cũ bằng cách chọn lại món và số lượng tương ứng.',
                ),
                if (widget.products.isEmpty)
                  const Text('Rạp chưa có sản phẩm đang bán.'),
                ...widget.products.map(
                  (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sid(p['image']).isNotEmpty)
                        Image.network(
                          sid(p['image']),
                          height: 70,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (a, b, c) => const SizedBox.shrink(),
                        ),
                      quantity(
                        '${p['name']} · ${money(p['price'])}\nCó thể chọn ${available(p)}',
                        picked[sid(p['_id'])] ?? 0,
                        available(p),
                        (n) => setState(() => picked[sid(p['_id'])] = n),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Bỏng nước mới: ${money(cost)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'snacks': [
              for (final p in picked.entries)
                if (p.value > 0) {'snackId': p.key, 'quantity': p.value},
            ],
            'snackChanges': [
              for (final p in removed.entries)
                if (p.value > 0) {'lineId': p.key, 'quantity': p.value},
            ],
          }),
          child: Text(widget.cancelOnly ? 'Tiếp tục hủy' : 'Tiếp tục'),
        ),
      ],
    );
  }
}

class SnacksScreen extends StatefulWidget {
  const SnacksScreen({super.key});
  @override
  State<SnacksScreen> createState() => _SnacksState();
}

class _SnacksState extends State<SnacksScreen> {
  Future<Json>? future;
  String? cinema;
  DateTime date = DateTime.now();
  bool busy = false;
  String? error;
  String get dateText =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Json> load() async {
    final api = AppScope.of(context).api;
    final r = await Future.wait([
      api.request('/cinemas'),
      api.request('/snack-orders'),
    ]);
    return {...asMap(r[1]), 'cinemas': r[0]};
  }

  Future<void> buy() async {
    if (cinema == null) {
      notice(context, 'Hãy chọn rạp.');
      return;
    }
    setState(() => busy = true);
    try {
      final basket = await chooseSnacks(context, cinemaId: cinema);
      if (basket == null || asList(basket['snacks']).isEmpty) return;
      if (!mounted) return;
      final order = asMap(
        await AppScope.of(context).api.request(
          '/snack-orders',
          method: 'POST',
          body: {
            'cinemaId': cinema,
            'pickupDate': dateText,
            'snacks': basket['snacks'],
            'idempotencyKey': const Uuid().v4(),
          },
        ),
      );
      if (mounted) go(context, '/checkout/${order['_id']}');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel(Json line) async {
    if (!await confirm(
      context,
      'Hủy bỏng nước?',
      'Hủy ${line['remaining']} phần chưa nhận và hoàn tiền mô phỏng.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.request(
        '/snack-orders/cancel',
        method: 'POST',
        body: {
          'items': [
            {'lineId': line['_id'], 'quantity': line['remaining']},
          ],
        },
      );
      if (mounted) setState(() => future = load());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Heading('Bỏng nước'),
      ErrorNote(error),
      DataView<Json>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Panel(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: cinema,
                    decoration: const InputDecoration(
                      labelText: 'Rạp nhận hàng',
                    ),
                    items: asList(d['cinemas'])
                        .map(
                          (c) => DropdownMenuItem(
                            value: sid(c['_id']),
                            child: Text(sid(c['name'])),
                          ),
                        )
                        .toList(),
                    onChanged: busy ? null : (v) => setState(() => cinema = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Ngày nhận: $dateText')),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final n = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                );
                                if (n != null && mounted) {
                                  setState(() => date = n);
                                }
                              },
                        child: const Text('Chọn ngày'),
                      ),
                    ],
                  ),
                  FilledButton(
                    onPressed: busy ? null : buy,
                    child: const Text('Chọn món & đặt riêng'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Đơn bỏng nước của tôi',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => future = load()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            ...asList(d['lines']).map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l['name']} · ${money(l['price'])}/phần',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Rạp: ${byId(asList(d['cinemas']), l['cinemaId'])?['name'] ?? ''} · Ngày nhận: ${l['pickupDate']}',
                      ),
                      Text(
                        'Đã mua: ${l['quantity']} · Còn hiệu lực: ${l['remaining']}',
                      ),
                      Text(
                        l['collected'] == true
                            ? 'Đã nhận hàng'
                            : (l['remaining'] as num) == 0
                            ? 'Đã hủy / chuyển sang đơn đổi'
                            : 'Chưa nhận',
                      ),
                      if (l['collected'] != true &&
                          (l['remaining'] as num) > 0) ...[
                        SelectableText('Mã nhận: ${l['pickupCode']}'),
                        TextButton(
                          onPressed: busy ? null : () => cancel(l),
                          child: const Text('Hủy & hoàn mô phỏng'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
