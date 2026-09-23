import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/chat.dart';
import '../../models/suat_chieu.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/suat_chieu_service.dart';

/// UC-PC — Phòng chat của suất chiếu
class PhongChatScreen extends StatefulWidget {
  final String suatId;
  final SuatChieu? suat;
  const PhongChatScreen({super.key, required this.suatId, this.suat});
  @override
  State<PhongChatScreen> createState() => _PhongChatScreenState();
}

class _PhongChatScreenState extends State<PhongChatScreen> {
  final _chat = ChatService();
  final _ctrl = TextEditingController();
  SuatChieu? _suat;
  bool _dangKiemTra = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _vaoPhong();
  }

  Future<void> _vaoPhong() async {
    try {
      final auth = context.read<AuthProvider>();
      _suat = widget.suat ?? await SuatChieuService().chiTiet(widget.suatId);
      if (_suat == null) throw Exception('Không tìm thấy suất chiếu.');
      await _chat.vaoPhong(uid: auth.uid, suat: _suat!);
      if (mounted) setState(() => _dangKiemTra = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loi = '$e'.replaceFirst('Exception: ', '');
          _dangKiemTra = false;
        });
      }
    }
  }

  Future<void> _gui() async {
    final auth = context.read<AuthProvider>();
    final text = _ctrl.text;
    _ctrl.clear();
    await _chat.guiTinNhan(
        suatId: widget.suatId, uid: auth.uid, hoTen: auth.hoTen, noiDung: text);
  }

  Future<void> _roiPhong() async {
    final auth = context.read<AuthProvider>();
    await _chat.roiPhong(auth.uid, widget.suatId);
    if (mounted) {
      thongBao(context, 'Bạn đã rời phòng chat.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_suat?.tenPhim ?? 'Phòng chat', style: const TextStyle(fontSize: 16)),
          if (_suat != null)
            Text('${_suat!.tenRap} · ${dinhDangNgayGio(_suat!.gioBatDau)}',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
        actions: [
          StreamBuilder<PhongChat?>(
            stream: _chat.thongTinPhong(widget.suatId),
            builder: (c, s) => Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  avatar: const Icon(Icons.group_outlined, size: 16),
                  label: Text('${s.data?.danhSachThanhVien.length ?? 0}'),
                ),
              ),
            ),
          ),
          IconButton(
              tooltip: 'Rời phòng', onPressed: _roiPhong, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _dangKiemTra
          ? const Loading()
          : _loi != null
              ? Rong(_loi!, icon: Icons.lock_outline)
              : KhungWeb(
                  max: 760,
                  child: Column(children: [
                    Expanded(
                      child: StreamBuilder<List<TinNhan>>(
                        stream: _chat.tinNhan(widget.suatId),
                        builder: (context, snap) {
                          final ds = snap.data ?? [];
                          if (ds.isEmpty) {
                            return const Rong('Chưa có tin nhắn nào. Hãy chào mọi người!',
                                icon: Icons.forum_outlined);
                          }
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: ds.length,
                            itemBuilder: (c, i) => _BongTin(tin: ds[i], cuaToi: ds[i].uid == uid),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onSubmitted: (_) => _gui(),
                            decoration: const InputDecoration(hintText: 'Nhập tin nhắn...'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(onPressed: _gui, icon: const Icon(Icons.send)),
                      ]),
                    ),
                  ]),
                ),
    );
  }
}

class _BongTin extends StatelessWidget {
  final TinNhan tin;
  final bool cuaToi;
  const _BongTin({required this.tin, required this.cuaToi});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: cuaToi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: cuaToi ? const Color(0xFFE31C25) : const Color(0xFF23262F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!cuaToi)
            Text(tin.hoTen,
                style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
          Text(tin.noiDung),
          if (tin.thoiGian != null)
            Text(dinhDangGio(tin.thoiGian!),
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ]),
      ),
    );
  }
}
