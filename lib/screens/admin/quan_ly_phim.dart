import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../models/phim.dart';
import '../../services/phim_service.dart';

/// UC-QLP-07
class QuanLyPhimTab extends StatelessWidget {
  const QuanLyPhimTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PhimService();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moForm(context, service, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm phim'),
      ),
      body: StreamBuilder<List<Phim>>(
        stream: service.danhSach(),
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final ds = snap.data!;
          if (ds.isEmpty) return const Rong('Chưa có phim nào.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final p = ds[i];
              return ListTile(
                title: Text(p.tenPhim),
                subtitle: Text(
                    '${p.theLoai.join(', ')} · ${p.thoiLuong} phút · ${TrangThaiPhim.nhan(p.trangThai)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      onPressed: () => _moForm(context, service, p),
                      icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Xóa phim'),
                          content: Text('Xóa "${p.tenPhim}" khỏi hệ thống?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      try {
                        await service.xoa(p.phimId);
                        if (context.mounted) thongBao(context, 'Đã xóa phim.');
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

  void _moForm(BuildContext context, PhimService service, Phim? phim) {
    final ten = TextEditingController(text: phim?.tenPhim);
    final theLoai = TextEditingController(text: phim?.theLoai.join(', '));
    final thoiLuong = TextEditingController(text: phim?.thoiLuong.toString());
    final daoDien = TextEditingController(text: phim?.daoDien);
    final dienVien = TextEditingController(text: phim?.dienVien.join(', '));
    final doTuoi = TextEditingController(text: phim?.doTuoi);
    final poster = TextEditingController(text: phim?.poster);
    final noiDung = TextEditingController(text: phim?.noiDung);
    var trangThai = phim?.trangThai ?? TrangThaiPhim.dangChieu;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(phim == null ? 'Thêm phim' : 'Sửa phim'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (c, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: ten, decoration: const InputDecoration(labelText: 'Tên phim *')),
                const SizedBox(height: 8),
                TextField(controller: theLoai, decoration: const InputDecoration(labelText: 'Thể loại (cách nhau bởi dấu phẩy)')),
                const SizedBox(height: 8),
                TextField(controller: thoiLuong, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Thời lượng (phút)')),
                const SizedBox(height: 8),
                TextField(controller: daoDien, decoration: const InputDecoration(labelText: 'Đạo diễn')),
                const SizedBox(height: 8),
                TextField(controller: dienVien, decoration: const InputDecoration(labelText: 'Diễn viên (cách nhau bởi dấu phẩy)')),
                const SizedBox(height: 8),
                TextField(controller: doTuoi, decoration: const InputDecoration(labelText: 'Giới hạn độ tuổi (VD: T16)')),
                const SizedBox(height: 8),
                TextField(controller: poster, decoration: const InputDecoration(labelText: 'URL poster')),
                const SizedBox(height: 8),
                TextField(controller: noiDung, maxLines: 3, decoration: const InputDecoration(labelText: 'Nội dung')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: trangThai,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: [TrangThaiPhim.dangChieu, TrangThaiPhim.sapChieu, TrangThaiPhim.ngungChieu]
                      .map((e) => DropdownMenuItem(value: e, child: Text(TrangThaiPhim.nhan(e))))
                      .toList(),
                  onChanged: (v) => setS(() => trangThai = v!),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng')),
          FilledButton(
            onPressed: () async {
              if (ten.text.trim().isEmpty) {
                thongBao(c, 'Tên phim không được để trống.', loi: true);
                return;
              }
              final moi = Phim(
                phimId: phim?.phimId ?? '',
                tenPhim: ten.text.trim(),
                theLoai: theLoai.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                thoiLuong: int.tryParse(thoiLuong.text) ?? 0,
                noiDung: noiDung.text.trim(),
                daoDien: daoDien.text.trim(),
                dienVien: dienVien.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                doTuoi: doTuoi.text.trim(),
                poster: poster.text.trim(),
                trangThai: trangThai,
              );
              try {
                phim == null ? await service.them(moi) : await service.capNhat(moi);
                if (c.mounted) Navigator.pop(c);
              } catch (e) {
                if (c.mounted) thongBao(c, '$e', loi: true);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
