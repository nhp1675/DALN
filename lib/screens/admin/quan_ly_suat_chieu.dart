import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets/common.dart';
import '../../models/phim.dart';
import '../../models/rap.dart';
import '../../models/suat_chieu.dart';
import '../../services/phim_service.dart';
import '../../services/rap_service.dart';
import '../../services/suat_chieu_service.dart';

/// UC-QLSC-08
class QuanLySuatChieuTab extends StatelessWidget {
  const QuanLySuatChieuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SuatChieuService();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(context: context, builder: (c) => const _FormSuatChieu()),
        icon: const Icon(Icons.add),
        label: const Text('Thêm suất chiếu'),
      ),
      body: StreamBuilder<List<SuatChieu>>(
        stream: service.tatCa(),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final ds = snap.data!;
          if (ds.isEmpty) return const Rong('Chưa có suất chiếu nào.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final s = ds[i];
              return ListTile(
                title: Text('${s.tenPhim} — ${dinhDangNgayGio(s.gioBatDau)}'),
                subtitle: Text('${s.tenRap} · ${s.tenPhong} · ${dinhDangTien(s.giaVeCoBan)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (s.trangThai != TrangThaiSuat.daHuy)
                    TextButton(
                      onPressed: () => service.doiTrangThai(s.suatId, TrangThaiSuat.daHuy),
                      child: const Text('Hủy suất'),
                    )
                  else
                    const Text('Đã hủy', style: TextStyle(color: Colors.redAccent)),
                  IconButton(
                    onPressed: () async {
                      try {
                        await service.xoa(s.suatId);
                        if (context.mounted) thongBao(context, 'Đã xóa suất chiếu.');
                      } catch (e) {
                        if (context.mounted) {
                          thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _FormSuatChieu extends StatefulWidget {
  const _FormSuatChieu();
  @override
  State<_FormSuatChieu> createState() => _FormSuatChieuState();
}

class _FormSuatChieuState extends State<_FormSuatChieu> {
  final _phimService = PhimService();
  final _rapService = RapService();
  final _suatService = SuatChieuService();
  final _gia = TextEditingController(text: '75000');

  Phim? _phim;
  Rap? _rap;
  PhongChieu? _phong;
  DateTime _ngay = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _gio = const TimeOfDay(hour: 19, minute: 0);
  bool _dangLuu = false;

  Future<void> _luu() async {
    if (_phim == null || _rap == null || _phong == null) {
      thongBao(context, 'Vui lòng chọn đủ phim, rạp và phòng chiếu.', loi: true);
      return;
    }
    setState(() => _dangLuu = true);
    try {
      final batDau = DateTime(_ngay.year, _ngay.month, _ngay.day, _gio.hour, _gio.minute);
      final suat = SuatChieu(
        suatId: '',
        phimId: _phim!.phimId,
        phongId: _phong!.phongId,
        rapId: _rap!.rapId,
        tenPhim: _phim!.tenPhim,
        tenRap: _rap!.tenRap,
        tenPhong: _phong!.tenPhong,
        gioBatDau: batDau,
        gioKetThuc: batDau.add(Duration(minutes: _phim!.thoiLuong + 15)),
        giaVeCoBan: num.tryParse(_gia.text) ?? 0,
      );
      await _suatService.them(suat);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) thongBao(context, '$e'.replaceFirst('Exception: ', ''), loi: true);
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm suất chiếu'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            StreamBuilder<List<Phim>>(
              stream: _phimService.danhSach(),
              builder: (c, s) => DropdownButtonFormField<Phim>(
                initialValue: _phim,
                decoration: const InputDecoration(labelText: 'Phim'),
                items: (s.data ?? [])
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.tenPhim)))
                    .toList(),
                onChanged: (v) => setState(() => _phim = v),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Rap>>(
              stream: _rapService.danhSachRap(),
              builder: (c, s) => DropdownButtonFormField<Rap>(
                initialValue: _rap,
                decoration: const InputDecoration(labelText: 'Rạp'),
                items: (s.data ?? [])
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.tenRap)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _rap = v;
                  _phong = null;
                }),
              ),
            ),
            const SizedBox(height: 8),
            if (_rap != null)
              StreamBuilder<List<PhongChieu>>(
                stream: _rapService.danhSachPhong(_rap!.rapId),
                builder: (c, s) => DropdownButtonFormField<PhongChieu>(
                  initialValue: _phong,
                  decoration: const InputDecoration(labelText: 'Phòng chiếu'),
                  items: (s.data ?? [])
                      .map((p) => DropdownMenuItem(
                          value: p, child: Text('${p.tenPhong} (${p.loaiPhong})')))
                      .toList(),
                  onChanged: (v) => setState(() => _phong = v),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _ngay,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setState(() => _ngay = d);
                  },
                  child: Text(dinhDangNgay(_ngay)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _gio);
                    if (t != null) setState(() => _gio = t);
                  },
                  child: Text(_gio.format(context)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _gia,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá vé cơ bản (VNĐ)'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        FilledButton(onPressed: _dangLuu ? null : _luu, child: const Text('Lưu')),
      ],
    );
  }
}
