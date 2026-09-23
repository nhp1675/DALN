import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/dat_ve.dart';
import '../../providers/auth_provider.dart';
import '../../services/dat_ve_service.dart';
import '../../services/thanh_vien_service.dart';
import '../../services/ve_service.dart';
import '../../models/nguoi_dung.dart';

/// UC-XLSDV (lịch sử đặt vé) + UC-TV (thẻ thành viên)
class VeCuaToiScreen extends StatelessWidget {
  const VeCuaToiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vé của tôi'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Vé điện tử'),
            Tab(text: 'Đơn đặt vé'),
            Tab(text: 'Thẻ thành viên'),
          ]),
        ),
        body: KhungWeb(
          max: 760,
          child: TabBarView(children: [
            _DanhSachVe(uid: uid),
            _DanhSachDon(uid: uid),
            _TheThanhVienTab(uid: uid),
          ]),
        ),
      ),
    );
  }
}

class _DanhSachVe extends StatelessWidget {
  final String uid;
  const _DanhSachVe({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ve>>(
      stream: VeService().veCuaToi(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Loading();
        if (snap.hasError) {
          return Rong('Không tải được vé: ${snap.error}', icon: Icons.error_outline);
        }
        final ds = snap.data ?? [];
        if (ds.isEmpty) return const Rong('Bạn chưa có vé nào.', icon: Icons.confirmation_num_outlined);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: ds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (c, i) {
            final v = ds[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const Icon(Icons.qr_code_2, size: 36),
                title: Text(v.tenPhim, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${v.tenRap} · ${v.tenPhong} · Ghế ${v.tenGhe}\n'
                    '${v.gioChieu == null ? '' : dinhDangNgayGio(v.gioChieu!)}'),
                isThreeLine: true,
                trailing: _NhanTrangThai(v.trangThai),
                onTap: () => context.push('/ve/chi-tiet', extra: v),
              ),
            );
          },
        );
      },
    );
  }
}

class _NhanTrangThai extends StatelessWidget {
  final String tt;
  const _NhanTrangThai(this.tt);
  @override
  Widget build(BuildContext context) {
    final (nhan, mau) = switch (tt) {
      TrangThaiVe.hopLe => ('Hợp lệ', Colors.greenAccent),
      TrangThaiVe.daDung => ('Đã dùng', Colors.white38),
      TrangThaiVe.daHuy => ('Đã hủy', Colors.redAccent),
      _ => ('Đã đổi', Colors.orangeAccent),
    };
    return Text(nhan, style: TextStyle(color: mau, fontSize: 12));
  }
}

class _DanhSachDon extends StatelessWidget {
  final String uid;
  const _DanhSachDon({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DonDatVe>>(
      stream: DatVeService().lichSuDon(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Loading();
        final ds = snap.data ?? [];
        if (ds.isEmpty) return const Rong('Chưa có đơn đặt vé nào.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: ds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (c, i) {
            final d = ds[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Text('${d.tenPhim} · ${d.danhSachGheId.length} ghế'),
                subtitle: Text(
                    '${d.tenRap}\n${d.ngayDat == null ? '' : 'Đặt lúc ${dinhDangNgayGio(d.ngayDat!)}'}'),
                isThreeLine: true,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(dinhDangTien(d.tongTien),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    switch (d.trangThai) {
                      TrangThaiDon.daThanhToan => 'Đã thanh toán',
                      TrangThaiDon.choThanhToan => 'Chờ thanh toán',
                      TrangThaiDon.daHuy => 'Đã hủy',
                      _ => 'Đã đổi',
                    },
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _TheThanhVienTab extends StatelessWidget {
  final String uid;
  const _TheThanhVienTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TheThanhVien?>(
      stream: ThanhVienService().the(uid),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final t = snap.data!;
        final mau = switch (t.hangThanhVien) {
          HangThanhVien.gold => const Color(0xFFD4AF37),
          HangThanhVien.silver => const Color(0xFFB0B7C3),
          _ => const Color(0xFFB07A4B),
        };
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [mau.withValues(alpha: 0.85), mau.withValues(alpha: 0.35)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HẠNG ${t.hangThanhVien.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                Text('${t.diemTichLuy} điểm',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Ưu đãi hiện tại: giảm ${(t.phanTramGiam * 100).round()}% mỗi đơn'),
              ]),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Quy tắc tích điểm', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• 1.000đ chi tiêu = 1 điểm'),
                  Text('• Từ 2.000 điểm: hạng Silver, giảm 5%'),
                  Text('• Từ 5.000 điểm: hạng Gold, giảm 10%'),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
