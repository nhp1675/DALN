import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../platform/browser.dart';
import '../widgets/common.dart';

class CommerceAdminScreen extends StatefulWidget {
  const CommerceAdminScreen({super.key});
  @override
  State<CommerceAdminScreen> createState() => _CommerceAdminState();
}

class _CommerceAdminState extends State<CommerceAdminScreen> {
  Future<Json>? future;
  String? error, cinema;
  bool busy = false;
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1),
      to = DateTime.now();
  String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Json> load() async {
    final api = AppScope.of(context).api;
    final r = await Future.wait([
      api.request('/cinemas'),
      api.request('/admin/snacks'),
      api.request('/admin/snack-pickups'),
      api.request(
        '/admin/revenue?from=${day(from)}&to=${day(to)}${cinema == null ? '' : '&cinemaId=$cinema'}',
      ),
    ]);
    return {'cinemas': r[0], 'products': r[1], 'pickups': r[2], 'report': r[3]};
  }

  void reload() {
    final nextFuture = load();
    setState(() {
      future = nextFuture;
      error = null;
    });
  }

  Future<void> edit(List<Json> cinemas, [Json? product]) async {
    final result = await showDialog<Json>(
      context: context,
      builder: (c) => _ProductForm(cinemas: cinemas, product: product),
    );
    if (result == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.request(
        '/admin/snacks${product == null ? '' : '/${product['_id']}'}',
        method: product == null ? 'POST' : 'PUT',
        body: result,
      );
      if (mounted) reload();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> collect(Json l) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận giao hàng'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nhập mã nhận do khách cung cấp',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Đã giao'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.request(
        '/admin/snack-pickups/${l['_id']}/collect',
        method: 'POST',
        body: {'code': code},
      );
      if (mounted) reload();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void export(Json report) {
    String cell(dynamic x) {
      var s = '$x';
      if (RegExp(r'^[=+@-]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    final rows = [
      [
        'Thời gian',
        'Nội dung',
        'Tiền thu',
        'Hoàn mô phỏng',
        'Doanh thu vé',
        'Doanh thu bỏng nước',
      ],
      ...asList(report['entries']).map(
        (r) => [
          r['createdAt'],
          r['description'],
          r['received'] ?? 0,
          r['returned'] ?? 0,
          r['ticketNet'] ?? 0,
          r['snackNet'] ?? 0,
        ],
      ),
    ];
    downloadData(
      'cinego-doanh-thu.csv',
      'data:text/csv;charset=utf-8;base64,${base64Encode(utf8.encode('\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}'))}',
    );
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        'Kho & doanh thu',
        action: IconButton(
          onPressed: busy ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
      ),
      ErrorNote(error),
      DataView<Json>(
        future: future!,
        retry: reload,
        builder: (d) {
          final cinemas = asList(d['cinemas']),
              report = asMap(d['report']),
              totals = asMap(report['totals']),
              days = asList(report['days']);
          final peak = days.fold<num>(
            1,
            (m, x) => (x['received'] as num) > m ? x['received'] as num : m,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Báo cáo thanh toán thử nghiệm',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Tiền hoàn là mô phỏng. Giao dịch trùng/chưa phát hành vé được tách riêng.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(start: from, end: to),
                      );
                      if (r != null && mounted) {
                        from = r.start;
                        to = r.end;
                        reload();
                      }
                    },
                    child: Text('${day(from)} → ${day(to)}'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      from = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        1,
                      );
                      to = DateTime.now();
                      reload();
                    },
                    child: const Text('Tháng này'),
                  ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: cinema,
                      decoration: const InputDecoration(labelText: 'Lọc rạp'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tất cả rạp'),
                        ),
                        ...cinemas.map(
                          (c) => DropdownMenuItem(
                            value: sid(c['_id']),
                            child: Text(
                              sid(c['name']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        cinema = v == '' ? null : v;
                        reload();
                      },
                    ),
                  ),
                  FilledButton(
                    onPressed: () => export(report),
                    child: const Text('Xuất CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Panel(
                child: Wrap(
                  spacing: 28,
                  runSpacing: 16,
                  children: [
                    for (final e in {
                      'received': 'Tiền thu',
                      'returned': 'Hoàn mô phỏng',
                      'ticketNet': 'Doanh thu vé',
                      'snackNet': 'Doanh thu bỏng nước',
                    }.entries)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value),
                          Text(
                            money(totals[e.key]),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    Text(
                      'Sau hoàn: ${money((totals['received'] as num) - (totals['returned'] as num))}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Tiền thu theo ngày'),
              for (final x in days)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 100, child: Text(sid(x['day']))),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (x['received'] as num) / peak,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 130, child: Text(money(x['received']))),
                    ],
                  ),
                ),
              if (days.isEmpty)
                const Text('Chưa có giao dịch trong khoảng đã chọn.'),
              Text(
                'Cần đối soát: ${asList(report['reconciliation']).length} giao dịch',
              ),
              for (final payment in asList(report['reconciliation']))
                ListTile(
                  title: Text(
                    '${money(payment['amount'])} · ${payment['provider']}',
                  ),
                  subtitle: SelectableText(
                    'Đơn ${payment['orderId']} · ${payment['purpose']}\nMã giao dịch: ${payment['reference']}',
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Ngày')),
                    DataColumn(label: Text('Nội dung')),
                    DataColumn(label: Text('Thu')),
                    DataColumn(label: Text('Hoàn')),
                  ],
                  rows: asList(report['entries'])
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text(dateTime(r['createdAt']))),
                            DataCell(Text(sid(r['description']))),
                            DataCell(Text(money(r['received']))),
                            DataCell(Text(money(r['returned']))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 28),
              Heading(
                'Sản phẩm & tồn kho',
                action: FilledButton(
                  onPressed: busy ? null : () => edit(cinemas),
                  child: const Text('Thêm món / combo'),
                ),
              ),
              const Text(
                'Tồn kho là hàng chưa giao, gồm hàng đang giữ cho đơn chờ. Combo được quản lý như một sản phẩm tồn kho riêng.',
              ),
              ...asList(d['products']).map(
                (p) => ListTile(
                  title: Text('${p['name']} · ${money(p['price'])}'),
                  subtitle: Text(
                    '${byId(cinemas, p['cinemaId'])?['name']} · Tồn ${p['stock']} · Đang giữ ${p['held']} · ${p['active'] == true ? 'Đang bán' : 'Ngừng bán'}',
                  ),
                  trailing: IconButton(
                    onPressed: busy ? null : () => edit(cinemas, p),
                    icon: const Icon(Icons.edit),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Heading('Đơn chờ nhận hàng'),
              ...asList(d['pickups']).map(
                (l) => ListTile(
                  title: Text('${l['name']} × ${l['remaining']}'),
                  subtitle: Text(
                    '${byId(cinemas, l['cinemaId'])?['name']} · ${l['pickupDate']} · ${sid(l['orderId'])}',
                  ),
                  trailing: TextButton(
                    onPressed: busy ? null : () => collect(l),
                    child: const Text('Giao hàng'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ProductForm extends StatefulWidget {
  final List<Json> cinemas;
  final Json? product;
  const _ProductForm({required this.cinemas, this.product});
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, image, price, stock;
  String? cinema;
  bool active = true;
  @override
  void initState() {
    super.initState();
    final p = widget.product ?? {};
    name = TextEditingController(text: sid(p['name']));
    image = TextEditingController(text: sid(p['image']));
    price = TextEditingController(text: '${p['price'] ?? 50000}');
    stock = TextEditingController(text: '${p['stock'] ?? 0}');
    cinema = p['cinemaId'] as String?;
    active = p['active'] != false;
  }

  @override
  void dispose() {
    for (final c in [name, image, price, stock]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Thêm món / combo' : 'Sửa sản phẩm'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: cinema,
                decoration: const InputDecoration(labelText: 'Rạp'),
                items: widget.cinemas
                    .map(
                      (c) => DropdownMenuItem(
                        value: sid(c['_id']),
                        child: Text(sid(c['name'])),
                      ),
                    )
                    .toList(),
                onChanged: widget.product != null
                    ? null
                    : (v) => setState(() => cinema = v),
                validator: (v) => v == null ? 'Chọn rạp' : null,
              ),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên món / combo'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập tên' : null,
              ),
              TextFormField(
                controller: image,
                decoration: const InputDecoration(
                  labelText: 'Ảnh HTTPS (không bắt buộc)',
                ),
              ),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá (đồng)'),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1000
                    ? 'Giá từ 1.000đ'
                    : null,
              ),
              TextFormField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số lượng tồn thực tế',
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                    ? 'Nhập số nguyên không âm'
                    : null,
              ),
              SwitchListTile(
                title: const Text('Đang bán'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              'cinemaId': cinema,
              'name': name.text.trim(),
              'image': image.text.trim(),
              'price': int.parse(price.text),
              'stock': int.parse(stock.text),
              'active': active,
            });
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
