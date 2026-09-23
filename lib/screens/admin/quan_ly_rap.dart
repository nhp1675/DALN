import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/rap.dart';
import '../../models/suat_chieu.dart';
import '../../services/gia_ve_service.dart';
import '../../services/rap_service.dart';

/// UC-QLRPC + UC-QLG
class QuanLyRapTab extends StatelessWidget {
  const QuanLyRapTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = RapService();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formRap(context, service, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm rạp'),
      ),
      body: StreamBuilder<List<Rap>>(
        stream: service.danhSachRap(),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final ds = snap.data!;
          if (ds.isEmpty) return const Rong('Chưa có rạp nào.');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: ds
                .map((r) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(r.tenRap),
                        subtitle: Text('${r.diaChi} · ${r.dangHoatDong ? 'Đang hoạt động' : 'Tạm ngưng'}'),
                        trailing: IconButton(
                          onPressed: () => _formRap(context, service, r),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        children: [
                          StreamBuilder<List<PhongChieu>>(
                            stream: service.danhSachPhong(r.rapId),
                            builder: (c, s) {
                              final phongs = s.data ?? [];
                              return Column(children: [
                                ...phongs.map((p) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.meeting_room_outlined),
                                      title: Text('${p.tenPhong} (${p.loaiPhong})'),
                                      subtitle: Text('${p.soLuongGhe} ghế'),
                                    )),
                                TextButton.icon(
                                  onPressed: () => _formPhong(context, service, r),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm phòng chiếu (tự sinh sơ đồ ghế)'),
                                ),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  void _formRap(BuildContext context, RapService service, Rap? rap) {
    final ten = TextEditingController(text: rap?.tenRap);
    final diaChi = TextEditingController(text: rap?.diaChi);
    final sdt = TextEditingController(text: rap?.soDienThoai);
    final lat = TextEditingController(text: rap?.viTri?.latitude.toString());
    final lng = TextEditingController(text: rap?.viTri?.longitude.toString());
    var hoatDong = rap?.dangHoatDong ?? true;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(rap == null ? 'Thêm rạp' : 'Sửa rạp'),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (c, setS) => SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: ten, decoration: const InputDecoration(labelText: 'Tên rạp *')),
                const SizedBox(height: 8),
                TextField(controller: diaChi, decoration: const InputDecoration(labelText: 'Địa chỉ')),
                const SizedBox(height: 8),
                TextField(controller: sdt, decoration: const InputDecoration(labelText: 'Số điện thoại')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: lat, decoration: const InputDecoration(labelText: 'Vĩ độ'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: lng, decoration: const InputDecoration(labelText: 'Kinh độ'))),
                ]),
                SwitchListTile(
                  value: hoatDong,
                  onChanged: (v) => setS(() => hoatDong = v),
                  title: const Text('Đang hoạt động'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
          FilledButton(
            onPressed: () async {
              final la = double.tryParse(lat.text), ln = double.tryParse(lng.text);
              final moi = Rap(
                rapId: rap?.rapId ?? '',
                tenRap: ten.text.trim(),
                diaChi: diaChi.text.trim(),
                soDienThoai: sdt.text.trim(),
                viTri: (la != null && ln != null) ? GeoPoint(la, ln) : null,
                trangThai: hoatDong ? 'hoatDong' : 'tamNgung',
              );
              rap == null ? await service.themRap(moi) : await service.capNhatRap(moi);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _formPhong(BuildContext context, RapService service, Rap rap) {
    final ten = TextEditingController(text: 'Phòng 1');
    final hang = TextEditingController(text: '8');
    final cot = TextEditingController(text: '10');
    var loai = '2D';

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Thêm phòng chiếu — ${rap.tenRap}'),
        content: SizedBox(
          width: 380,
          child: StatefulBuilder(
            builder: (c, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ten, decoration: const InputDecoration(labelText: 'Tên phòng')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: loai,
                decoration: const InputDecoration(labelText: 'Loại phòng'),
                items: const ['2D', '3D', 'IMAX']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setS(() => loai = v!),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: hang, decoration: const InputDecoration(labelText: 'Số hàng'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: cot, decoration: const InputDecoration(labelText: 'Ghế / hàng'))),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
          FilledButton(
            onPressed: () async {
              await service.themPhong(
                PhongChieu(phongId: '', rapId: rap.rapId, tenPhong: ten.text.trim(), loaiPhong: loai),
                soHang: int.tryParse(hang.text) ?? 8,
                soGheMoiHang: int.tryParse(cot.text) ?? 10,
              );
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Tạo phòng'),
          ),
        ],
      ),
    );
  }
}

/// UC-QLGV
class QuanLyGiaVeTab extends StatelessWidget {
  const QuanLyGiaVeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = GiaVeService();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, service),
        icon: const Icon(Icons.add),
        label: const Text('Thêm mức giá'),
      ),
      body: StreamBuilder<List<GiaVe>>(
        stream: service.danhSach(),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final ds = snap.data!;
          if (ds.isEmpty) {
            return const Rong(
                'Chưa cấu hình bảng giá. Hệ thống sẽ dùng giá cơ bản của suất chiếu nhân hệ số loại ghế.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: ds
                .map((g) => ListTile(
                      title: Text('${LoaiGhe.nhan(g.loaiGhe)} · '
                          '${g.loaiNgay == 'CuoiTuan' ? 'Cuối tuần' : 'Ngày thường'} · '
                          '${g.khungGio == 'Sang' ? 'Suất sáng' : 'Suất tối'}'),
                      subtitle: Text(dinhDangTien(g.giaTien)),
                      trailing: IconButton(
                        onPressed: () => service.xoa(g.giaVeId),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  void _form(BuildContext context, GiaVeService service) {
    final gia = TextEditingController(text: '75000');
    var loaiGhe = LoaiGhe.thuong;
    var ln = 'NgayThuong';
    var kg = 'Sang';

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Thêm mức giá'),
        content: SizedBox(
          width: 380,
          child: StatefulBuilder(
            builder: (c, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField(
                initialValue: loaiGhe,
                decoration: const InputDecoration(labelText: 'Loại ghế'),
                items: LoaiGhe.all.map((e) => DropdownMenuItem(value: e, child: Text(LoaiGhe.nhan(e)))).toList(),
                onChanged: (v) => setS(() => loaiGhe = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField(
                initialValue: ln,
                decoration: const InputDecoration(labelText: 'Loại ngày'),
                items: const [
                  DropdownMenuItem(value: 'NgayThuong', child: Text('Ngày thường')),
                  DropdownMenuItem(value: 'CuoiTuan', child: Text('Cuối tuần')),
                ],
                onChanged: (v) => setS(() => ln = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField(
                initialValue: kg,
                decoration: const InputDecoration(labelText: 'Khung giờ'),
                items: const [
                  DropdownMenuItem(value: 'Sang', child: Text('Trước 17h')),
                  DropdownMenuItem(value: 'Toi', child: Text('Từ 17h')),
                ],
                onChanged: (v) => setS(() => kg = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá tiền (VNĐ)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
          FilledButton(
            onPressed: () async {
              await service.them(GiaVe(
                giaVeId: '',
                loaiGhe: loaiGhe,
                loaiNgay: ln,
                khungGio: kg,
                giaTien: num.tryParse(gia.text) ?? 0,
                ngayApDung: DateTime.now(),
              ));
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
