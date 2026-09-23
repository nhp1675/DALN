import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/dat_ve.dart';
import '../../models/nguoi_dung.dart';
import '../../services/auth_service.dart';
import '../../services/dat_ve_service.dart';

/// UC-QLDDV + UC-QLKH
class QuanLyDonTab extends StatelessWidget {
  const QuanLyDonTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Đơn đặt vé'), Tab(text: 'Khách hàng')]),
        Expanded(
          child: TabBarView(children: [
            _Don(),
            _KhachHang(),
          ]),
        ),
      ]),
    );
  }
}

class _Don extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DonDatVe>>(
      stream: DatVeService().tatCaDon(),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final ds = snap.data!;
        if (ds.isEmpty) return const Rong('Chưa có đơn đặt vé nào.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: ds.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (c, i) {
            final d = ds[i];
            return ListTile(
              title: Text('${d.tenPhim} · ${d.danhSachGheId.join(', ')}'),
              subtitle: Text(
                  '${d.tenRap} · ${d.ngayDat == null ? '' : dinhDangNgayGio(d.ngayDat!)} · ${d.uid}'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(dinhDangTien(d.tongTien), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            );
          },
        );
      },
    );
  }
}

class _KhachHang extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = AuthService();
    return StreamBuilder<List<NguoiDung>>(
      stream: service.danhSachKhachHang(),
      builder: (context, snap) {
        if (!snap.hasData) return const Loading();
        final ds = snap.data!;
        if (ds.isEmpty) return const Rong('Chưa có khách hàng nào.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: ds.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (c, i) {
            final u = ds[i];
            return ListTile(
              title: Text(u.hoTen),
              subtitle: Text('${u.email} · ${u.soDienThoai}'),
              trailing: Switch(
                value: !u.biKhoa,
                onChanged: (v) => service.doiTrangThaiTaiKhoan(
                    u.uid, v ? TrangThaiTaiKhoan.active : TrangThaiTaiKhoan.locked),
              ),
            );
          },
        );
      },
    );
  }
}
