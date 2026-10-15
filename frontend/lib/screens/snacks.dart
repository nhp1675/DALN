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
                  (p) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        SnackImage(
                          url: sid(p['image']),
                          name: sid(p['name']),
                          width: 76,
                          height: 76,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: quantity(
                            '${p['name']} · ${money(p['price'])}\nCó thể chọn ${available(p)}',
                            picked[sid(p['_id'])] ?? 0,
                            available(p),
                            (n) => setState(() => picked[sid(p['_id'])] = n),
                          ),
                        ),
                      ],
                    ),
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
  // 'success' khi vừa thanh toán xong và được chuyển từ cổng thanh toán về.
  final String? paymentResult;
  const SnacksScreen({super.key, this.paymentResult});
  @override
  State<SnacksScreen> createState() => _SnacksState();
}

class _SnacksState extends State<SnacksScreen> {
  Future<Json>? future;
  Future<List<Json>>? menu;
  bool announced = false;
  String? cinema;
  DateTime date = DateTime.now();
  final Map<String, int> picked = {};
  bool busy = false;
  String? error;
  String get dateText =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String get dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
    if (!announced && widget.paymentResult == 'success') {
      announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          notice(
            context,
            'Thanh toán thành công! Mã nhận bỏng nước nằm ở mục "Đơn bỏng nước của tôi".',
          );
        }
      });
    }
  }

  // Xem thực đơn không cần đăng nhập; đơn của tôi chỉ tải khi đã đăng nhập.
  Future<Json> load() async {
    final s = AppScope.of(context);
    final cinemas = await s.api.request('/cinemas');
    final mine = s.user == null
        ? <String, dynamic>{'lines': <Json>[]}
        : asMap(await s.api.request('/snack-orders'));
    return {...mine, 'cinemas': cinemas};
  }

  Future<List<Json>> loadMenu(String id) async =>
      asList(await AppScope.of(context).api.request('/snacks?cinemaId=$id'));

  void chooseCinema(String? id) => setState(() {
    cinema = id;
    picked.clear();
    menu = id == null ? null : loadMenu(id);
  });

  Future<void> buy() async {
    final s = AppScope.of(context);
    if (s.user == null) {
      notice(context, 'Hãy đăng nhập để đặt bỏng nước.');
      go(context, '/login');
      return;
    }
    final snacks = [
      for (final e in picked.entries)
        if (e.value > 0) {'snackId': e.key, 'quantity': e.value},
    ];
    if (cinema == null || snacks.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final order = asMap(
        await s.api.request(
          '/snack-orders',
          method: 'POST',
          body: {
            'cinemaId': cinema,
            'pickupDate': dateText,
            'snacks': snacks,
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
      'Hủy ${line['remaining']} phần chưa nhận và hoàn tiền.',
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

  Widget picker(Json d) => Panel(
    child: Wrap(
      spacing: 16,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 340,
          child: DropdownButtonFormField<String>(
            initialValue: cinema,
            decoration: const InputDecoration(labelText: 'Rạp nhận hàng'),
            items: asList(d['cinemas'])
                .map(
                  (c) => DropdownMenuItem(
                    value: sid(c['_id']),
                    child: Text(sid(c['name'])),
                  ),
                )
                .toList(),
            onChanged: busy ? null : chooseCinema,
          ),
        ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final n = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (n != null && mounted) setState(() => date = n);
                },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text('Ngày nhận: $dateLabel'),
        ),
      ],
    ),
  );

  Widget menuView() {
    if (menu == null) {
      return const Empty('Chọn rạp nhận hàng để xem thực đơn.');
    }
    return DataView<List<Json>>(
      future: menu!,
      retry: () => setState(() => menu = loadMenu(cinema!)),
      builder: (items) {
        if (items.isEmpty) return const Empty('Rạp này chưa bán bỏng nước.');
        final count = picked.values.fold<int>(0, (n, q) => n + q);
        final total = items.fold<num>(
          0,
          (n, p) => n + (p['price'] as num) * (picked[sid(p['_id'])] ?? 0),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900
                    ? 4
                    : c.maxWidth > 640
                    ? 3
                    : 2;
                const gap = 16.0;
                final width = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final p in items)
                      _ProductCard(
                        key: ValueKey(sid(p['_id'])),
                        product: p,
                        width: width,
                        quantity: picked[sid(p['_id'])] ?? 0,
                        onChange: (n) => setState(() {
                          if (n <= 0) {
                            picked.remove(sid(p['_id']));
                          } else {
                            picked[sid(p['_id'])] = n;
                          }
                        }),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count == 0
                              ? 'Chưa chọn món nào'
                              : '$count phần đã chọn',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(total),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || count == 0 ? null : buy,
                    child: const Text('Đặt & thanh toán'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget orderCard(Json l, Json d) {
    final remaining = (l['remaining'] as num).toInt();
    final collected = l['collected'] == true;
    final status = collected
        ? 'Đã nhận hàng'
        : remaining == 0
        ? 'Đã hủy / chuyển sang đơn đổi'
        : 'Chưa nhận';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SnackImage(
              url: sid(l['image']),
              name: sid(l['name']),
              width: 88,
              height: 88,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sid(l['name']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${money(l['price'])}/phần · Đã mua ${l['quantity']} · Còn hiệu lực $remaining',
                    style: const TextStyle(color: muted),
                  ),
                  Text(
                    'Rạp: ${byId(asList(d['cinemas']), l['cinemaId'])?['name'] ?? ''} · Ngày nhận: ${l['pickupDate']}',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Tag(
                    status,
                    color: collected ? const Color(0xFF2E7D32) : coral,
                  ),
                  if (!collected && remaining > 0) ...[
                    const SizedBox(height: 8),
                    SelectableText('Mã nhận: ${l['pickupCode']}'),
                    TextButton(
                      onPressed: busy ? null : () => cancel(l),
                      child: const Text('Hủy & hoàn tiền'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const Heading('Bỏng nước', eyebrow: 'Đặt trước, nhận tại rạp'),
      ErrorNote(error),
      DataView<Json>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            picker(d),
            const SizedBox(height: 20),
            menuView(),
            const SizedBox(height: 40),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Đơn bỏng nước của tôi',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: busy
                      ? null
                      : () => setState(() => future = load()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (asList(d['lines']).isEmpty)
              const Empty('Bạn chưa có đơn bỏng nước nào.')
            else
              ...asList(d['lines']).map((l) => orderCard(l, d)),
          ],
        ),
      ),
    ],
  );
}

class _ProductCard extends StatelessWidget {
  final Json product;
  final double width;
  final int quantity;
  final ValueChanged<int> onChange;
  const _ProductCard({
    super.key,
    required this.product,
    required this.width,
    required this.quantity,
    required this.onChange,
  });
  @override
  Widget build(BuildContext context) {
    final max = ((product['available'] as num?) ?? 0).toInt().clamp(0, 50);
    final soldOut = max == 0;
    return SizedBox(
      width: width,
      child: Panel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SnackImage(
                      url: sid(product['image']),
                      name: sid(product['name']),
                      radius: 0,
                    ),
                    if (soldOut)
                      const ColoredBox(
                        color: Color(0x99000000),
                        child: Center(
                          child: Text(
                            'Hết hàng',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 42,
                      child: Text(
                        sid(product['name']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(product['price']),
                      style: const TextStyle(
                        color: coral,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (quantity == 0)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: soldOut ? null : () => onChange(1),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Thêm'),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton.outlined(
                            tooltip: 'Bớt',
                            onPressed: () => onChange(quantity - 1),
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton.outlined(
                            tooltip: 'Thêm',
                            onPressed: quantity >= max
                                ? null
                                : () => onChange(quantity + 1),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    if (!soldOut && max <= 5) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Chỉ còn $max phần',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
