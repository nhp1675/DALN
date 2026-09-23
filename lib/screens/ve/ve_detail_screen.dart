import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/dat_ve.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/suat_chieu_service.dart';
import '../../services/ve_service.dart';

/// Vé điện tử (UC-PHV) + lối vào Hủy vé (UC-HDV) và Phòng chat (UC-PC)
class VeDetailScreen extends StatefulWidget {
  final Ve ve;
  const VeDetailScreen({super.key, required this.ve});
  @override
  State<VeDetailScreen> createState() => _VeDetailScreenState();
}

class _VeDetailScreenState extends State<VeDetailScreen> {
  final _veService = VeService();
  final _chat = ChatService();
  bool _dangXuLy = false;

  Future<void> _huyVe() async {
    final uid = context.read<AuthProvider>().uid;
    final lyDo = await showDialog<String>(
      context: context,
      builder: (c) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Xác nhận hủy vé'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'Bạn sẽ được hoàn ${dinhDangTien((widget.ve.giaVe * (1 - QuyDinh.phiHuyVe)).round())} '
                '(đã trừ ${(QuyDinh.phiHuyVe * 100).round()}% phí hủy).'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Lý do (không bắt buộc)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
            FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Hủy vé'),
            ),
          ],
        );
      },
    );
    if (lyDo == null) return;
    if (!mounted) return;
    setState(() => _dangXuLy = true);
    try {
      final hoan = await _veService.huyVe(ve: widget.ve, uid: uid, lyDo: lyDo);
      if (mounted) {
        thongBao(context, 'Hủy vé thành công. Hoàn ${dinhDangTien(hoan)}.');
        context.pop();
      }
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _vaoPhongChat() async {
    setState(() => _dangXuLy = true);
    try {
      final uid = context.read<AuthProvider>().uid;
      final suat = await SuatChieuService().chiTiet(widget.ve.suatId);
      if (suat == null) throw Exception('Không tìm thấy suất chiếu.');
      await _chat.vaoPhong(uid: uid, suat: suat);
      if (mounted) context.push('/chat/${suat.suatId}', extra: suat);
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.ve;
    return Scaffold(
      appBar: AppBar(title: const Text('Vé điện tử')),
      body: KhungWeb(
        max: 460,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: QrImageView(data: v.maQR, size: 180),
                ),
                const SizedBox(height: 12),
                SelectableText(v.maQR,
                    style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                _dong('Phim', v.tenPhim),
                _dong('Rạp', v.tenRap),
                _dong('Phòng', v.tenPhong),
                _dong('Ghế', v.tenGhe),
                _dong('Suất chiếu', v.gioChieu == null ? '—' : dinhDangNgayGio(v.gioChieu!)),
                _dong('Giá vé', dinhDangTien(v.giaVe)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (v.trangThai == TrangThaiVe.hopLe) ...[
            FilledButton.icon(
              onPressed: _dangXuLy ? null : _vaoPhongChat,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Vào phòng chat của suất chiếu'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _dangXuLy || !v.coTheHuyDoi ? null : () => context.push('/ve/doi', extra: v),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Đổi vé'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _dangXuLy || !v.coTheHuyDoi ? null : _huyVe,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Hủy vé'),
            ),
            if (!v.coTheHuyDoi)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Vé chỉ được hủy/đổi trước giờ chiếu ít nhất 2 giờ.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _dong(String n, String g) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(n, style: const TextStyle(color: Colors.white54))),
          Flexible(child: Text(g, textAlign: TextAlign.right)),
        ]),
      );
}
