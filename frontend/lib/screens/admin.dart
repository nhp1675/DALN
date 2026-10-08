import 'moderation.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

const adminNames = {
  'movies': 'Phim',
  'cinemas': 'Rạp',
  'rooms': 'Phòng chiếu',
  'seats': 'Ghế',
  'showtimes': 'Suất chiếu & giá',
  'orders': 'Đơn đặt vé',
  'users': 'Khách hàng',
  'payments': 'Thanh toán',
  'refunds': 'Hoàn tiền',
  'audits': 'Nhật ký',
  'checkin': 'Soát vé QR',
  'chat': 'Phòng chat',
};
const defaults = <String, Json>{
  'movies': {
    'title': '',
    'genre': '',
    'duration': 120,
    'synopsis': '',
    'director': '',
    'cast': '',
    'ageRating': 'P',
    'status': 'now',
    'poster': '',
  },
  'cinemas': {
    'name': '',
    'address': '',
    'city': 'Hà Nội',
    'latitude': 21.0285,
    'longitude': 105.8542,
    'active': true,
  },
  'rooms': {'name': '', 'cinemaId': '', 'rows': 7, 'columns': 10},
  'showtimes': {
    'movieId': '',
    'roomId': '',
    'startAt': '',
    'standardPrice': 80000,
    'vipPrice': 110000,
  },
  'seats': {'type': 'standard', 'active': true},
};
const fields = <String, List<List<String>>>{
  'movies': [
    ['title', 'Tên phim'],
    ['genre', 'Thể loại'],
    ['duration', 'Thời lượng (phút)', 'number'],
    ['synopsis', 'Nội dung', 'textarea'],
    ['director', 'Đạo diễn'],
    ['cast', 'Diễn viên'],
    ['ageRating', 'Độ tuổi', 'select', 'P,K,T13,T16,T18'],
    ['status', 'Trạng thái', 'select', 'now,soon,archived'],
    ['poster', 'Poster (HTTPS hoặc /posters/...)'],
  ],
  'cinemas': [
    ['name', 'Tên rạp'],
    ['address', 'Địa chỉ'],
    ['city', 'Thành phố'],
    ['latitude', 'Vĩ độ', 'number'],
    ['longitude', 'Kinh độ', 'number'],
    ['active', 'Hoạt động', 'bool'],
  ],
  'rooms': [
    ['name', 'Tên phòng'],
    ['cinemaId', 'Rạp', 'relation', 'cinemas'],
    ['rows', 'Số hàng ghế', 'number'],
    ['columns', 'Ghế mỗi hàng', 'number'],
  ],
  'showtimes': [
    ['movieId', 'Phim', 'relation', 'movies'],
    ['roomId', 'Phòng', 'relation', 'rooms'],
    ['startAt', 'Ngày giờ (giờ trên máy của bạn)', 'date'],
    ['standardPrice', 'Giá thường (VND)', 'number'],
    ['vipPrice', 'Giá VIP (VND)', 'number'],
  ],
  'seats': [
    ['type', 'Loại ghế', 'select', 'standard,vip'],
    ['active', 'Hoạt động', 'bool'],
  ],
};

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminState();
}

class _AdminState extends State<AdminScreen> {
  String tab = 'movies';
  int page = 1;
  Future<Json>? future;
  Future<Json>? overview;
  Json lookups = {};
  String? error;
  bool busy = false;
  final qr = TextEditingController();
  String checkResult = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (future == null) {
      future = load();
      overview = loadOverview();
      loadLookups();
    }
  }

  @override
  void dispose() {
    qr.dispose();
    super.dispose();
  }

  Future<Json> load() async {
    if (tab == 'checkin' || tab == 'chat') {
      return {'items': [], 'pages': 1, 'total': 0};
    }
    return asMap(
      await AppScope.of(context).api.request('/admin/data/$tab?page=$page'),
    );
  }

  Future<Json> loadOverview() async =>
      asMap(await AppScope.of(context).api.request('/admin/overview'));
  Future<List<Json>> all(String entity) async {
    final api = AppScope.of(context).api;
    final items = <Json>[];
    for (var p = 1; ; p++) {
      final r = asMap(await api.request('/admin/data/$entity?page=$p'));
      items.addAll(asList(r['items']));
      if (p >= (r['pages'] as num)) break;
    }
    return items;
  }

  Future<void> loadLookups() async {
    try {
      final r = await Future.wait([
        all('movies'),
        all('cinemas'),
        all('rooms'),
      ]);
      if (mounted) {
        setState(
          () => lookups = {'movies': r[0], 'cinemas': r[1], 'rooms': r[2]},
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void refresh() {
    setState(() {
      future = load();
      overview = loadOverview();
    });
    loadLookups();
  }

  String lookup(String type, dynamic id) => sid(
    byId(
          lookups[type] is List ? asList(lookups[type]) : [],
          id,
        )?[type == 'movies' ? 'title' : 'name'] ??
        id,
  );
  Future<void> edit([Json? item]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AdminEditor(
        entity: tab,
        item: item,
        lookups: lookups,
        api: AppScope.of(context).api,
      ),
    );
    if (result == true && mounted) refresh();
  }

  Future<void> remove(Json item) async {
    if (!await confirm(
      context,
      'Xác nhận thay đổi?',
      ['movies', 'cinemas'].contains(tab)
          ? 'Mục này sẽ được ẩn, lịch sử vẫn được giữ lại.'
          : 'Không thể xóa nếu đã có dữ liệu đặt vé liên quan.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(
        context,
      ).api.request('/admin/$tab/${item['_id']}', method: 'DELETE');
      if (mounted) refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleUser(Json item) async {
    if (!await confirm(
      context,
      item['active'] == true ? 'Khóa khách hàng?' : 'Mở khóa khách hàng?',
      item['active'] == true
          ? 'Các phiên đăng nhập sẽ bị thu hồi.'
          : 'Khách có thể đăng nhập trở lại.',
    )) {
      return;
    }
    if (!mounted) return;
    try {
      await AppScope.of(context).api.request(
        '/admin/users/${item['_id']}',
        method: 'PATCH',
        body: {'active': item['active'] != true},
      );
      if (mounted) refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> checkIn() async {
    setState(() {
      busy = true;
      error = null;
      checkResult = '';
    });
    try {
      final r = asMap(
        await AppScope.of(context).api.request(
          '/admin/check-in',
          method: 'POST',
          body: {'qr': qr.text.trim()},
        ),
      );
      if (mounted) {
        setState(
          () => checkResult =
              'Soát vé thành công · Ghế ${r['seat']} · ${dateTime(r['showtime'])}',
        );
        qr.clear();
        refresh();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<String> get headers =>
      {
        'movies': ['Tên phim', 'Thể loại', 'Phút', 'Trạng thái'],
        'cinemas': ['Tên rạp', 'Thành phố', 'Địa chỉ', 'Hoạt động'],
        'rooms': ['Phòng', 'Rạp'],
        'seats': ['Ghế', 'Phòng', 'Loại', 'Hoạt động'],
        'showtimes': [
          'Phim',
          'Phòng',
          'Bắt đầu',
          'Giá thường / VIP',
          'Trạng thái',
        ],
        'orders': [
          'Mã đơn',
          'Khách',
          'Số tiền',
          'Loại',
          'Trạng thái',
          'Thời gian',
        ],
        'users': ['Họ tên', 'Email', 'Vai trò', 'Hoạt động'],
        'payments': ['Giao dịch', 'Đơn', 'Số tiền', 'Trạng thái', 'Cổng'],
        'refunds': ['Vé', 'Giao dịch gốc', 'Số tiền', 'Trạng thái'],
        'audits': ['Hành động', 'Đối tượng', 'Người thực hiện', 'Thời gian'],
      }[tab] ??
      [];
  String short(dynamic id) {
    final s = sid(id);
    return s.length > 8 ? s.substring(s.length - 8) : s;
  }

  List<String> row(Json x) {
    switch (tab) {
      case 'movies':
        return [
          sid(x['title']),
          sid(x['genre']),
          sid(x['duration']),
          status(x['status']),
        ];
      case 'cinemas':
        return [
          sid(x['name']),
          sid(x['city']),
          sid(x['address']),
          x['active'] == true ? 'Có' : 'Không',
        ];
      case 'rooms':
        return [sid(x['name']), lookup('cinemas', x['cinemaId'])];
      case 'seats':
        return [
          sid(x['label']),
          lookup('rooms', x['roomId']),
          sid(x['type']),
          x['active'] == true ? 'Có' : 'Không',
        ];
      case 'showtimes':
        return [
          lookup('movies', x['movieId']),
          lookup('rooms', x['roomId']),
          dateTime(x['startAt']),
          '${money(x['standardPrice'])} / ${money(x['vipPrice'])}',
          status(x['status']),
        ];
      case 'orders':
        return [
          short(x['_id']),
          short(x['userId']),
          money(x['total']),
          status(x['kind']),
          status(x['status']),
          dateTime(x['createdAt']),
        ];
      case 'users':
        return [
          sid(x['name']),
          sid(x['email']),
          status(x['role']),
          x['active'] == true ? 'Có' : 'Không',
        ];
      case 'payments':
        return [
          short(x['_id']),
          short(x['orderId']),
          money(x['amount']),
          status(x['status']),
          sid(x['provider']),
        ];
      case 'refunds':
        return [
          short(x['ticketId']),
          short(x['paymentId']),
          money(x['amount']),
          status(x['status']),
        ];
      case 'audits':
        return [
          sid(x['action']),
          short(x['entityId']),
          short(x['userId']),
          dateTime(x['createdAt']),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    width: 1340,
    children: [
      const Heading('Quản trị rạp phim', eyebrow: 'CINEGO MANAGEMENT'),
      DataView<Json>(
        future: overview!,
        builder: (v) => LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth < 700 ? 2 : 4;
            final w = (c.maxWidth - 16 * (cols - 1)) / cols;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children:
                  [
                        ['Khách hàng', sid(v['users'])],
                        ['Vé còn hiệu lực', sid(v['tickets'])],
                        ['Doanh thu ròng', money(v['net'])],
                        ['Đơn chờ', sid(v['pending'])],
                      ]
                      .map(
                        (x) => SizedBox(
                          width: w,
                          child: Panel(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  x[0],
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  child: Text(
                                    x[1],
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 8,
        runSpacing: 10,
        children: adminNames.entries
            .map(
              (e) => ChoiceChip(
                label: Text(e.value),
                selected: tab == e.key,
                onSelected: busy
                    ? null
                    : (_) => setState(() {
                        tab = e.key;
                        page = 1;
                        error = null;
                        future = load();
                      }),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 24),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  adminNames[tab]!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (fields.containsKey(tab) && tab != 'seats')
                  FilledButton.icon(
                    onPressed: busy ? null : () => edit(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm mới'),
                  ),
                if (tab != 'checkin' && tab != 'chat')
                  OutlinedButton.icon(
                    onPressed: busy ? null : refresh,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Làm mới'),
                  ),
              ],
            ),
            ErrorNote(error),
            const SizedBox(height: 20),
            if (tab == 'chat')
              const ModerationPanel()
            else if (tab == 'checkin')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dùng máy quét QR nhập mã vào ô dưới. Chỉ soát từ 60 phút trước giờ chiếu đến hết phim.',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: qr,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung mã QR',
                    ),
                    onSubmitted: (_) => busy ? null : checkIn(),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : checkIn,
                    child: const Text('Kiểm tra và sử dụng vé'),
                  ),
                  if (checkResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        checkResult,
                        style: const TextStyle(color: Color(0xFF28784B)),
                      ),
                    ),
                ],
              )
            else
              DataView<Json>(
                future: future!,
                retry: refresh,
                builder: (d) {
                  final items = asList(d['items']),
                      pages = (d['pages'] as num).toInt();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items.isEmpty)
                        const Empty('Chưa có dữ liệu.')
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF5F4EF),
                            ),
                            columns: [
                              ...headers.map((h) => DataColumn(label: Text(h))),
                              const DataColumn(label: Text('Thao tác')),
                            ],
                            rows: items
                                .map(
                                  (x) => DataRow(
                                    cells: [
                                      ...row(x).map(
                                        (value) => DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 250,
                                            ),
                                            child: Text(
                                              value,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (fields.containsKey(tab))
                                              IconButton(
                                                tooltip: 'Sửa',
                                                onPressed: busy
                                                    ? null
                                                    : () => edit(x),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                ),
                                              ),
                                            if ([
                                              'movies',
                                              'cinemas',
                                              'rooms',
                                              'showtimes',
                                            ].contains(tab))
                                              IconButton(
                                                tooltip: 'Xóa hoặc ẩn',
                                                onPressed: busy
                                                    ? null
                                                    : () => remove(x),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: coral,
                                                ),
                                              ),
                                            if (tab == 'users' &&
                                                x['role'] == 'customer')
                                              TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () => toggleUser(x),
                                                child: Text(
                                                  x['active'] == true
                                                      ? 'Khóa'
                                                      : 'Mở khóa',
                                                ),
                                              ),
                                            if (!fields.containsKey(tab) &&
                                                tab != 'users')
                                              const Text('—'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: page <= 1
                                ? null
                                : () => setState(() {
                                    page--;
                                    future = load();
                                  }),
                            child: const Text('Trước'),
                          ),
                          Text(
                            'Trang $page/${pages < 1 ? 1 : pages} · ${d['total']} bản ghi',
                          ),
                          OutlinedButton(
                            onPressed: page >= pages
                                ? null
                                : () => setState(() {
                                    page++;
                                    future = load();
                                  }),
                            child: const Text('Sau'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    ],
  );
}

class AdminEditor extends StatefulWidget {
  final String entity;
  final Json? item;
  final Json lookups;
  final Api api;
  const AdminEditor({
    super.key,
    required this.entity,
    required this.lookups,
    required this.api,
    this.item,
  });
  @override
  State<AdminEditor> createState() => _EditorState();
}

class _EditorState extends State<AdminEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  late Json values;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    values = {...defaults[widget.entity]!};
    for (final field in fields[widget.entity]!) {
      final key = field[0];
      if (widget.item?[key] != null) values[key] = widget.item![key];
      final type = field.length > 2 ? field[2] : '';
      if (!['relation', 'select', 'bool'].contains(type)) {
        controllers[key] = TextEditingController(
          text: type == 'date' && sid(values[key]).isNotEmpty
              ? DateTime.parse(
                  sid(values[key]),
                ).toLocal().toString().substring(0, 16)
              : sid(values[key]),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> chooseDate(String key) async {
    final existing =
        DateTime.tryParse(controllers[key]!.text) ??
        DateTime.now().add(const Duration(days: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime.now().subtract(const Duration(days: 366)),
      lastDate: DateTime.now().add(const Duration(days: 1000)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (t != null && mounted) {
      setState(
        () => controllers[key]!.text = DateTime(
          d.year,
          d.month,
          d.day,
          t.hour,
          t.minute,
        ).toString().substring(0, 16),
      );
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{};
      for (final f in fields[widget.entity]!) {
        final key = f[0], type = f.length > 2 ? f[2] : '';
        if (type == 'number') {
          body[key] = num.parse(controllers[key]!.text);
        } else if (type == 'date') {
          body[key] = DateTime.parse(
            controllers[key]!.text,
          ).toUtc().toIso8601String();
        } else {
          body[key] = controllers.containsKey(key)
              ? controllers[key]!.text.trim()
              : values[key];
        }
      }
      await widget.api.request(
        '/admin/${widget.entity}${widget.item == null ? '' : '/${widget.item!['_id']}'}',
        method: widget.entity == 'seats'
            ? 'PATCH'
            : widget.item == null
            ? 'POST'
            : 'PUT',
        body: body,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.item == null ? 'Thêm' : 'Chỉnh sửa'} ${adminNames[widget.entity]!.toLowerCase()}',
    ),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.entity == 'rooms')
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Nửa sau phòng là VIP. Có thể sửa từng ghế trước khi lên lịch.',
                  ),
                ),
              ErrorNote(error),
              ...fields[widget.entity]!.map((f) {
                final key = f[0], label = f[1], type = f.length > 2 ? f[2] : '';
                Widget input;
                if (type == 'bool') {
                  input = SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    value: values[key] == true,
                    onChanged: (v) => setState(() => values[key] = v),
                  );
                } else if (type == 'relation' || type == 'select') {
                  final items = type == 'relation'
                      ? (widget.lookups[f[3]] is List
                                ? asList(widget.lookups[f[3]])
                                : <Json>[])
                            .map(
                              (x) => DropdownMenuItem<String>(
                                value: sid(x['_id']),
                                child: Text(
                                  sid(x['title'] ?? x['name']),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList()
                      : f[3]
                            .split(',')
                            .map(
                              (x) => DropdownMenuItem(
                                value: x,
                                child: Text(status(x)),
                              ),
                            )
                            .toList();
                  final valid = items.any((i) => i.value == sid(values[key]));
                  input = DropdownButtonFormField<String>(
                    initialValue: valid ? sid(values[key]) : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: label),
                    items: items,
                    onChanged: (v) => setState(() => values[key] = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Vui lòng chọn' : null,
                  );
                } else {
                  input = TextFormField(
                    controller: controllers[key],
                    decoration: InputDecoration(
                      labelText: label,
                      suffixIcon: type == 'date'
                          ? const Icon(Icons.calendar_today)
                          : null,
                    ),
                    maxLines: type == 'textarea' ? 4 : 1,
                    readOnly: type == 'date',
                    onTap: type == 'date' ? () => chooseDate(key) : null,
                    keyboardType: type == 'number'
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    validator: (v) {
                      if (['cast', 'director', 'poster'].contains(key)) {
                        return null;
                      }
                      if ((v ?? '').trim().isEmpty) {
                        return 'Vui lòng nhập thông tin';
                      }
                      if (type == 'number' && num.tryParse(v!) == null) {
                        return 'Nhập số hợp lệ';
                      }
                      return null;
                    },
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: input,
                );
              }),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Đang lưu…' : 'Lưu dữ liệu'),
      ),
    ],
  );
}
