import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/dat_ve.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/dat_ve_service.dart';
import '../../services/thanh_toan_service.dart';

/// UC-TT (thanh toán) + UC-PHV (phát hành vé điện tử)
class ThanhToanScreen extends StatefulWidget {
  final String donId;
  const ThanhToanScreen({super.key, required this.donId});
  @override
  State<ThanhToanScreen> createState() => _ThanhToanScreenState();
}

class _ThanhToanScreenState extends State<ThanhToanScreen> {
  final _datVe = DatVeService();
  final _cong = ThanhToanService();
  String _phuongThuc = PhuongThucThanhToan.momo;
  bool _dangXuLy = false;
  List<Ve>? _veDaPhatHanh;

  Future<void> _thanhToan() async {
    final booking = context.read<BookingProvider>();
    final uid = context.read<AuthProvider>().uid;
    if (booking.suat == null || booking.dangChon.isEmpty) {
      thongBao(context, 'Phiên đặt vé đã hết hạn, vui lòng đặt lại.', loi: true);
      return;
    }
    setState(() => _dangXuLy = true);
    try {
      // Bước 16→18: gọi cổng thanh toán
      final kq = await _cong.thanhToan(
          donId: widget.donId, soTien: booking.tongTien, phuongThuc: _phuongThuc);

      if (!kq.thanhCong) {
        await _datVe.ghiNhanThanhToanThatBai(
          donId: widget.donId,
          soTien: booking.tongTien,
          phuongThuc: _phuongThuc,
          maGiaoDich: kq.maGiaoDich,
        );
        throw Exception('${kq.thongBaoLoi} Bạn có thể thử thanh toán lại.');
      }

      // Bước 19→23: chốt ghế + phát hành vé
      final ve = await _datVe.xacNhanThanhToan(
        donId: widget.donId,
        uid: uid,
        suat: booking.suat!,
        ghes: booking.dangChon,
        giaTheoGhe: booking.giaTheoGhe,
        phuongThuc: _phuongThuc,
        maGiaoDich: kq.maGiaoDich,
      );
      booking.xoaHet();
      if (mounted) setState(() => _veDaPhatHanh = ve);
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _huyDon() async {
    final uid = context.read<AuthProvider>().uid;
    await _datVe.huyDonChuaThanhToan(donId: widget.donId, uid: uid);
    if (mounted) {
      context.read<BookingProvider>().xoaHet();
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_veDaPhatHanh != null) return _ThanhCong(ve: _veDaPhatHanh!);

    final b = context.watch<BookingProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: KhungWeb(
        max: 720,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Thông tin đặt vé', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _dong('Phim', b.suat?.tenPhim ?? '—'),
                _dong('Rạp / phòng', '${b.suat?.tenRap ?? ''} · ${b.suat?.tenPhong ?? ''}'),
                _dong('Suất chiếu',
                    b.suat == null ? '—' : dinhDangNgayGio(b.suat!.gioBatDau)),
                _dong('Ghế', b.dangChon.map((e) => e.ten).join(', ')),
                const Divider(height: 24),
                _dong('Tạm tính', dinhDangTien(b.tamTinh)),
                if (b.tienGiam > 0)
                  _dong('Ưu đãi thành viên (${(b.phanTramGiam * 100).round()}%)',
                      '-${dinhDangTien(b.tienGiam)}'),
                _dong('Tổng thanh toán', dinhDangTien(b.tongTien), dam: true),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Chọn phương thức thanh toán',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _phuongThuc,
            onChanged: (v) => setState(() => _phuongThuc = v!),
            child: Column(
              children: PhuongThucThanhToan.all
                  .map((p) => RadioListTile<String>(
                        value: p,
                        title: Text(PhuongThucThanhToan.nhan(p)),
                        secondary: Icon(switch (p) {
                          PhuongThucThanhToan.the => Icons.credit_card,
                          PhuongThucThanhToan.momo => Icons.account_balance_wallet_outlined,
                          _ => Icons.qr_code_2,
                        }),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _dangXuLy ? null : _thanhToan,
            child: _dangXuLy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Thanh toán ${dinhDangTien(b.tongTien)}'),
          ),
          TextButton(
            onPressed: _dangXuLy ? null : _huyDon,
            child: const Text('Hủy đặt vé'),
          ),
        ]),
      ),
    );
  }

  Widget _dong(String nhan, String giaTri, {bool dam = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(nhan, style: const TextStyle(color: Colors.white60))),
          Text(giaTri,
              style: TextStyle(
                  fontWeight: dam ? FontWeight.bold : FontWeight.normal,
                  fontSize: dam ? 16 : 14)),
        ]),
      );
}

class _ThanhCong extends StatelessWidget {
  final List<Ve> ve;
  const _ThanhCong({required this.ve});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KhungWeb(
        max: 520,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 72),
              const SizedBox(height: 16),
              const Text('Đặt vé thành công!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Hệ thống đã phát hành ${ve.length} vé điện tử.',
                  style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/ve'),
                child: const Text('Xem vé của tôi'),
              ),
              TextButton(onPressed: () => context.go('/'), child: const Text('Về trang chủ')),
            ]),
          ),
        ),
      ),
    );
  }
}
