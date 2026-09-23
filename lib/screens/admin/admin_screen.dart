import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import 'quan_ly_don.dart';
import 'quan_ly_phim.dart';
import 'quan_ly_rap.dart';
import 'quan_ly_suat_chieu.dart';

/// Khu vực quản trị: UC-QLP, UC-QLRPC, UC-QLG, UC-QLSC, UC-QLGV, UC-QLDDV, UC-QLKH
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản trị hệ thống'),
          leading: IconButton(
              onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back)),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Phim'),
            Tab(text: 'Suất chiếu'),
            Tab(text: 'Rạp & phòng'),
            Tab(text: 'Giá vé'),
            Tab(text: 'Đơn & khách hàng'),
          ]),
        ),
        body: const KhungWeb(
          child: TabBarView(children: [
            QuanLyPhimTab(),
            QuanLySuatChieuTab(),
            QuanLyRapTab(),
            QuanLyGiaVeTab(),
            QuanLyDonTab(),
          ]),
        ),
      ),
    );
  }
}
