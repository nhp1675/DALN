import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import '../platform/browser.dart';

double distanceKm(double a, double b, double c, double d) {
  double rad(double x) => x * pi / 180;
  final x =
      pow(sin(rad(c - a) / 2), 2) +
      cos(rad(a)) * cos(rad(c)) * pow(sin(rad(d - b) / 2), 2);
  return 6371 * 2 * atan2(sqrt(x.clamp(0, 1)), sqrt((1 - x).clamp(0, 1)));
}

class CinemasScreen extends StatefulWidget {
  const CinemasScreen({super.key});
  @override
  State<CinemasScreen> createState() => _CinemasState();
}

class _CinemasState extends State<CinemasScreen> {
  Future<List<Json>>? future;
  (double, double)? position;
  String city = '';
  int radius = 50;
  bool locating = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<List<Json>> load() async =>
      asList(await AppScope.of(context).api.request('/cinemas'));
  Future<void> findNear() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      final p = await locate();
      if (mounted) setState(() => position = p);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      Heading(
        'Hệ thống rạp',
        eyebrow: 'HẸN NHAU GẦN HƠN',
        action: FilledButton.icon(
          onPressed: locating ? null : findNear,
          icon: const Icon(Icons.my_location, size: 18),
          label: Text(locating ? 'Đang định vị…' : 'Tìm rạp gần tôi'),
        ),
      ),
      const Text(
        'Vị trí chỉ được tính trên thiết bị, không gửi lên máy chủ CineGo.',
        style: TextStyle(color: muted),
      ),
      ErrorNote(error),
      const SizedBox(height: 22),
      DataView<List<Json>>(
        future: future!,
        retry: () => setState(() => future = load()),
        builder: (all) {
          final cities = all.map((c) => sid(c['city'])).toSet();
          final list =
              all
                  .map(
                    (c) => {
                      ...c,
                      'distance': position == null
                          ? null
                          : distanceKm(
                              position!.$1,
                              position!.$2,
                              (c['latitude'] as num).toDouble(),
                              (c['longitude'] as num).toDouble(),
                            ),
                    },
                  )
                  .where(
                    (c) =>
                        (city.isEmpty || c['city'] == city) &&
                        (position == null ||
                            (c['distance'] as double) <= radius),
                  )
                  .toList()
                ..sort(
                  (a, b) => ((a['distance'] ?? 0) as num).compareTo(
                    (b['distance'] ?? 0) as num,
                  ),
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: city,
                      decoration: const InputDecoration(labelText: 'Thành phố'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tất cả'),
                        ),
                        ...cities.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (s) => setState(() => city = s ?? ''),
                    ),
                  ),
                  if (position != null) ...[
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<int>(
                        initialValue: radius,
                        decoration: const InputDecoration(
                          labelText: 'Bán kính',
                        ),
                        items: [10, 25, 50, 100, 2000]
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n km'),
                              ),
                            )
                            .toList(),
                        onChanged: (n) => setState(() => radius = n ?? 50),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => position = null),
                      child: const Text('Bỏ vị trí'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 26),
              if (list.isEmpty)
                const Empty('Không tìm thấy rạp trong phạm vi đã chọn.')
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final count = c.maxWidth > 900
                        ? 3
                        : c.maxWidth > 600
                        ? 2
                        : 1;
                    final width = (c.maxWidth - 22 * (count - 1)) / count;
                    return Wrap(
                      spacing: 22,
                      runSpacing: 22,
                      children: list
                          .map(
                            (r) => SizedBox(
                              width: width,
                              child: Panel(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 160,
                                      width: double.infinity,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE9E3D6),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.theaters_outlined,
                                          size: 80,
                                          color: Color(0xFF7C887A),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            position == null
                                                ? sid(r['city'])
                                                : '${(r['distance'] as double).toStringAsFixed(1)} KM TỪ BẠN',
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 12,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            sid(r['name']),
                                            style: const TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            sid(r['address']),
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 22),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 10,
                                            children: [
                                              FilledButton(
                                                onPressed: () => go(
                                                  context,
                                                  '/?cinema=${r['_id']}',
                                                ),
                                                child: const Text('Chọn phim'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => openExternal(
                                                  'https://www.google.com/maps/dir/?api=1&destination=${r['latitude']},${r['longitude']}',
                                                ),
                                                icon: const Icon(
                                                  Icons.directions,
                                                  size: 16,
                                                ),
                                                label: const Text('Chỉ đường'),
                                              ),
                                            ],
                                          ),
                                        ],
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
            ],
          );
        },
      ),
    ],
  );
}

class ChatScreen extends StatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});
  @override
  State<ChatScreen> createState() => _ChatState();
}

class _ChatState extends State<ChatScreen> {
  final text = TextEditingController(), scroll = ScrollController();
  Timer? timer;
  List<Json> messages = [];
  bool busy = false, loading = true, polling = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (timer == null) {
      load();
      timer = Timer.periodic(const Duration(seconds: 4), (_) => load());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (polling) return;
    polling = true;
    try {
      final r = asList(
        await AppScope.of(context).api.request('/chat/${widget.id}/messages'),
      );
      if (mounted) {
        setState(() {
          messages = r;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          if (e is ApiException && e.status == 403) messages = [];
          loading = false;
        });
      }
    } finally {
      polling = false;
    }
  }

  Future<void> send() async {
    if (busy || text.text.trim().isEmpty) return;
    final draft = text.text;
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.request(
        '/chat/${widget.id}/messages',
        method: 'POST',
        body: {'body': draft.trim()},
      );
      if (!mounted) return;
      if (text.text == draft) text.clear();
      await load();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.animateTo(
              scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    try {
      await AppScope.of(
        context,
      ).api.request('/chat/${widget.id}/membership', method: 'DELETE');
      if (mounted) go(context, '/tickets');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user!;
    return PageBody(
      width: 900,
      children: [
        Heading(
          'Phòng trò chuyện',
          eyebrow: 'CÙNG SUẤT CHIẾU · CÙNG ĐAM MÊ',
          action: OutlinedButton(
            onPressed: leave,
            child: const Text('Rời phòng'),
          ),
        ),
        const Text(
          'Trò chuyện lịch sự, tránh tiết lộ nội dung phim và thông tin cá nhân. Phòng đóng khi suất chiếu kết thúc. Quản trị viên có thể xem và kiểm duyệt nội dung.',
          style: TextStyle(color: muted, fontSize: 14),
        ),
        ErrorNote(error),
        const SizedBox(height: 16),
        Container(
          height: 420,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EFE8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? const Empty('Hãy bắt đầu cuộc trò chuyện.')
              : ListView.separated(
                  controller: scroll,
                  itemCount: messages.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 14),
                  itemBuilder: (c, i) {
                    final m = messages[i], mine = m['userId'] == user['id'];
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFFFFE3D8)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sid(m['name']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(sid(m['body'])),
                              const SizedBox(height: 6),
                              Text(
                                time(m['createdAt']),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  final enter =
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter;
                  if (!enter ||
                      HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isAltPressed ||
                      HardwareKeyboard.instance.isMetaPressed ||
                      !text.value.composing.isCollapsed) {
                    return KeyEventResult.ignored;
                  }
                  // Handle repeat/up too so a held Enter cannot send twice.
                  if (event is KeyDownEvent) {
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      final old = text.value;
                      final selection = old.selection.isValid
                          ? old.selection
                          : TextSelection.collapsed(offset: old.text.length);
                      final next = TextEditingValue(
                        text: old.text.replaceRange(
                          selection.start,
                          selection.end,
                          '\n',
                        ),
                        selection: TextSelection.collapsed(
                          offset: selection.start + 1,
                        ),
                      );
                      text.value = LengthLimitingTextInputFormatter(
                        1000,
                      ).formatEditUpdate(old, next);
                    } else {
                      send();
                    }
                  }
                  return KeyEventResult.handled;
                },
                child: TextField(
                  controller: text,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Chia sẻ cảm nhận của bạn…',
                    labelText: 'Nội dung tin nhắn',
                    helperText: 'Enter để gửi · Shift+Enter để xuống dòng',
                    helperMaxLines: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: busy ? null : send,
              child: const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
