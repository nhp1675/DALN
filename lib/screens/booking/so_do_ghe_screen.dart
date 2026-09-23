import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/rap.dart';
import '../../models/suat_chieu.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/dat_ve_service.dart';
import '../../services/rap_service.dart';
import '../../services/suat_chieu_service.dart';
import '../../services/thanh_vien_service.dart';

/// UC-CC (chọn ghế) + UC-DV bước 8→14
class SoDoGheScreen extends StatefulWidget {
  final String suatId;
  const SoDoGheScreen({super.key, required this.suatId});
  @override
  State<SoDoGheScreen> createState() => _SoDoGheScreenState();
}

class _SoDoGheScreenState extends State<SoDoGheScreen> {
  final _suatService = SuatChieuService();
  final _rapService = RapService();
  final _datVe = DatVeService();
  final _thanhVien = ThanhVienService();

  SuatChieu? _suat;
  List<Ghe> _ghes = [];
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  Future<void> _taiDuLieu() async {
    final uid = context.read<AuthProvider>().uid;
    try {
      final suat = await _suatService.chiTiet(widget.suatId);
      if (suat == null) throw Exception('Không tìm thấy suất chiếu.');
      final ghes = await _rapService.layGheCuaPhong(suat.rapId, suat.phongId);
      final the = await _thanhVien.layThe(uid);
      if (!mounted) return;
      context.read<BookingProvider>().batDauSuat(suat, giamGiaThanhVien: the.phanTramGiam);
      setState(() {
        _suat = suat;
        _ghes = ghes;
        _dangTai = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loi = '$e'.replaceFirst('Exception: ', ''); _dangTai = false; });
    }
  }

  Future<void> _xacNhan() async {
    final booking = context.read<BookingProvider>();
    final uid = context.read<AuthProvider>().uid;
    if (booking.dangChon.isEmpty) {
      thongBao(context, 'Bạn cần chọn ít nhất 1 ghế.', loi: true);
      return;
    }
    if (booking.conLai == Duration.zero) {
      thongBao(context, 'Đã hết thời gian giữ ghế, vui lòng chọn lại.', loi: true);
      await booking.huyBo(uid);
      return;
    }
    try {
      final donId = await _datVe.taoDon(
        uid: uid,
        suat: _suat!,
        ghes: booking.dangChon,
        tongTien: booking.tongTien,
      );
      booking.donId = donId;
      if (mounted) context.push('/thanh-toan/$donId');
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final uid = context.read<AuthProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_suat == null ? 'Chọn ghế' : _suat!.tenPhim),
        actions: [
          if (booking.dangGiuGhe)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(
                      '${booking.conLai.inMinutes}:${(booking.conLai.inSeconds % 60).toString().padLeft(2, '0')}'),
                ),
              ),
            ),
        ],
      ),
      body: _dangTai
          ? const Loading()
          : _loi != null
              ? Rong(_loi!, icon: Icons.error_outline)
              : StreamBuilder<Map<String, GheSuatChieu>>(
                  stream: _datVe.trangThaiGheTheoSuat(widget.suatId),
                  builder: (context, snap) {
                    final trangThai = snap.data ?? {};
                    return KhungWeb(
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '${_suat!.tenRap} · ${_suat!.tenPhong} · ${dinhDangNgayGio(_suat!.gioBatDau)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        _ManHinh(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: _SoDo(
                              ghes: _ghes,
                              trangThai: trangThai,
                              uid: uid,
                              daChon: booking.daChon,
                              onChon: (g) async {
                                try {
                                  await booking.chonGhe(g, uid);
                                } catch (e) {
                                  if (context.mounted) {
                                    thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                        const _ChuThich(),
                        _ThanhTong(onXacNhan: _xacNhan),
                      ]),
                    );
                  },
                ),
    );
  }
}

class _ManHinh extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.02),
          ]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        alignment: Alignment.center,
        child: const Text('MÀN HÌNH', style: TextStyle(fontSize: 11, letterSpacing: 4)),
      );
}

class _SoDo extends StatelessWidget {
  final List<Ghe> ghes;
  final Map<String, GheSuatChieu> trangThai;
  final String uid;
  final bool Function(String) daChon;
  final Future<void> Function(Ghe) onChon;

  const _SoDo({
    required this.ghes,
    required this.trangThai,
    required this.uid,
    required this.daChon,
    required this.onChon,
  });

  @override
  Widget build(BuildContext context) {
    final theoHang = <String, List<Ghe>>{};
    for (final g in ghes) {
      theoHang.putIfAbsent(g.hang, () => []).add(g);
    }
    return Column(
      children: theoHang.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 24, child: Text(e.key, style: const TextStyle(color: Colors.white54))),
            ...e.value.map((g) {
              final tt = trangThai[g.gheId];
              final daDat = tt != null && tt.trangThaiGhe == TrangThaiGhe.daDat;
              final nguoiKhacGiu = tt != null &&
                  tt.trangThaiGhe == TrangThaiGhe.dangGiu &&
                  tt.uidGiu != uid &&
                  !tt.hetHanGiu;
              final chon = daChon(g.gheId);
              final khoa = daDat || nguoiKhacGiu;

              Color mau() {
                if (chon) return const Color(0xFFE31C25);
                if (daDat) return const Color(0xFF3A3F4B);
                if (nguoiKhacGiu) return const Color(0xFF6B5B00);
                return g.loaiGhe == LoaiGhe.vip
                    ? const Color(0xFF2B4A5C)
                    : const Color(0xFF23262F);
              }

              return Padding(
                padding: const EdgeInsets.all(3),
                child: Tooltip(
                  message: '${g.ten} · ${LoaiGhe.nhan(g.loaiGhe)}'
                      '${daDat ? ' · đã đặt' : nguoiKhacGiu ? ' · đang được giữ' : ''}',
                  child: InkWell(
                    onTap: khoa ? null : () => onChon(g),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: mau(),
                        borderRadius: BorderRadius.circular(6),
                        border: chon ? Border.all(color: Colors.white, width: 1.5) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('${g.so}',
                          style: TextStyle(
                              fontSize: 11,
                              color: khoa ? Colors.white38 : Colors.white)),
                    ),
                  ),
                ),
              );
            }),
          ]),
        );
      }).toList(),
    );
  }
}

class _ChuThich extends StatelessWidget {
  const _ChuThich();
  Widget _o(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ]);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(spacing: 16, runSpacing: 8, alignment: WrapAlignment.center, children: [
          _o(const Color(0xFF23262F), 'Ghế trống'),
          _o(const Color(0xFF2B4A5C), 'Ghế VIP'),
          _o(const Color(0xFFE31C25), 'Đang chọn'),
          _o(const Color(0xFF6B5B00), 'Người khác giữ'),
          _o(const Color(0xFF3A3F4B), 'Đã đặt'),
        ]),
      );
}

class _ThanhTong extends StatelessWidget {
  final VoidCallback onXacNhan;
  const _ThanhTong({required this.onXacNhan});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BookingProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFF14161C)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              b.dangChon.isEmpty
                  ? 'Chưa chọn ghế'
                  : 'Ghế: ${b.dangChon.map((e) => e.ten).join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              Text(dinhDangTien(b.tongTien),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (b.tienGiam > 0) ...[
                const SizedBox(width: 8),
                Text('-${dinhDangTien(b.tienGiam)} (thành viên)',
                    style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 200,
          child: FilledButton(onPressed: onXacNhan, child: const Text('Tiếp tục thanh toán')),
        ),
      ]),
    );
  }
}
