import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class ModerationPanel extends StatefulWidget {
  const ModerationPanel({super.key});
  @override
  State<ModerationPanel> createState() => _ModerationState();
}

class _ModerationState extends State<ModerationPanel> {
  int page = 1;
  Json? selected;
  Future<Json>? future;
  bool busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<Json> load() async => asMap(
    await AppScope.of(context).api.request(
      selected == null
          ? '/admin/chat/rooms?page=$page'
          : '/admin/chat/rooms/${selected!['_id']}/messages?page=$page',
    ),
  );
  void refresh() => setState(() => future = load());
  Future<void> moderate(
    String path,
    bool value,
    String title, {
    bool delete = false,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _ReasonDialog(title: title, destructive: delete),
    );
    if (!mounted || reason == null) return;
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.request(
        '/admin/chat/rooms/${selected!['_id']}/$path',
        method: delete ? 'DELETE' : 'PATCH',
        body: delete ? {'reason': reason} : {'value': value, 'reason': reason},
      );
      if (mounted) {
        notice(context, delete ? 'Đã xóa tin nhắn.' : 'Đã cập nhật.');
        if (delete) page = 1;
        refresh();
      }
    } catch (e) {
      if (mounted) notice(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Kiểm duyệt nội dung và quản lý quyền tham gia từng phòng chat.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        children: [
          if (selected != null)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        selected = null;
                        page = 1;
                        future = load();
                      });
                    },
              child: const Text('Danh sách phòng'),
            ),
          OutlinedButton.icon(
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật phòng chat'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (future != null)
        DataView<Json>(
          future: future!,
          retry: refresh,
          builder: (data) {
            final items = asList(data['items']);
            final room = selected == null ? null : asMap(data['room']);
            final bans = room == null ? <Json>[] : asList(data['bans']);
            final banned = bans.map((b) => sid(b['userId'])).toSet();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room != null) ...[
                  Text(
                    room['locked'] == true
                        ? 'Phòng đang khóa gửi tin'
                        : 'Phòng đang mở gửi tin',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => moderate(
                            'lock',
                            room['locked'] != true,
                            room['locked'] == true
                                ? 'Mở phòng chat'
                                : 'Khóa phòng chat',
                          ),
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      room['locked'] == true ? 'Mở phòng' : 'Khóa phòng',
                    ),
                  ),
                  if (bans.isNotEmpty)
                    const Text(
                      'Thành viên bị chặn',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ...bans.map(
                    (b) => Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text('${b['name'] ?? b['userId']} · ${b['reason']}'),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => moderate(
                                  'users/${b['userId']}/ban',
                                  false,
                                  'Bỏ chặn thành viên',
                                ),
                          child: const Text('Bỏ chặn'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Chưa có dữ liệu.'),
                  ),
                ...items.map((item) {
                  if (room == null) {
                    final show = byId(
                      asList(data['shows']),
                      item['showtimeId'],
                    );
                    final movie = byId(
                      asList(data['movies']),
                      show?['movieId'],
                    );
                    final cinema = byId(
                      asList(data['cinemas']),
                      show?['cinemaId'],
                    );
                    return Card(
                      child: ListTile(
                        title: Text(
                          sid(movie?['title']).isEmpty
                              ? 'Phòng chat'
                              : sid(movie?['title']),
                        ),
                        subtitle: Text(
                          '${cinema?['name'] ?? ''} · ${dateTime(show?['startAt'])}\n${item['locked'] == true ? 'Đang khóa' : 'Đang mở'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: busy
                            ? null
                            : () {
                                setState(() {
                                  selected = item;
                                  page = 1;
                                  future = load();
                                });
                              },
                      ),
                    );
                  }
                  final hidden = item['hidden'] == true;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['name']} · ${dateTime(item['createdAt'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (hidden)
                            const Text(
                              'Đã ẩn khỏi phòng chat',
                              style: TextStyle(color: coral),
                            ),
                          const SizedBox(height: 8),
                          SelectableText(sid(item['body'])),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => moderate(
                                        'messages/${item['_id']}',
                                        !hidden,
                                        hidden
                                            ? 'Khôi phục tin nhắn'
                                            : 'Ẩn tin nhắn',
                                      ),
                                child: Text(
                                  hidden ? 'Khôi phục' : 'Ẩn tin nhắn',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => moderate(
                                        'messages/${item['_id']}',
                                        false,
                                        'Xóa vĩnh viễn tin nhắn?',
                                        delete: true,
                                      ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('Xóa tin nhắn'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => moderate(
                                        'users/${item['userId']}/ban',
                                        !banned.contains(sid(item['userId'])),
                                        'Quản lý thành viên',
                                      ),
                                child: Text(
                                  banned.contains(sid(item['userId']))
                                      ? 'Bỏ chặn'
                                      : 'Chặn thành viên',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: busy || page <= 1
                          ? null
                          : () {
                              page--;
                              refresh();
                            },
                      child: const Text('Trước'),
                    ),
                    Text('Trang $page/${data['pages']}'),
                    TextButton(
                      onPressed: busy || page >= (data['pages'] as num)
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

class _ReasonDialog extends StatefulWidget {
  final String title;
  final bool destructive;
  const _ReasonDialog({required this.title, this.destructive = false});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: form,
      child: TextFormField(
        controller: input,
        maxLength: 500,
        minLines: 2,
        maxLines: 4,
        validator: (v) =>
            (v?.trim().length ?? 0) < 3 ? 'Nhập lý do ít nhất 3 ký tự.' : null,
        decoration: InputDecoration(
          labelText: 'Lý do',
          helperText: widget.destructive
              ? 'Không thể khôi phục tin đã xóa. Thao tác được ghi nhật ký.'
              : 'Thao tác được ghi vào nhật ký quản trị.',
          helperMaxLines: 3,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, input.text.trim());
          }
        },
        child: Text(widget.destructive ? 'Xóa vĩnh viễn' : 'Xác nhận'),
      ),
    ],
  );
}
