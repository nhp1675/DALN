import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/rap.dart';
import '../models/suat_chieu.dart';

/// UC-QLGV — bảng giá vé và quy tắc tính giá
class GiaVeService {
  final _c = FirebaseFirestore.instance.collection(Col.giaVe);
  List<GiaVe>? _cache;

  Stream<List<GiaVe>> danhSach() =>
      _c.snapshots().map((s) => s.docs.map(GiaVe.fromDoc).toList());

  Future<List<GiaVe>> _tatCa() async {
    _cache ??= (await _c.get()).docs.map(GiaVe.fromDoc).toList();
    return _cache!;
  }

  void xoaCache() => _cache = null;

  /// Giá 1 ghế = bản ghi giaVe khớp (loại ghế, loại ngày, khung giờ);
  /// nếu không có thì lấy giá cơ bản của suất chiếu nhân hệ số loại ghế.
  Future<num> giaMotGhe(SuatChieu suat, Ghe ghe) async {
    final bang = await _tatCa();
    final ln = loaiNgay(suat.gioBatDau);
    final kg = khungGio(suat.gioBatDau);
    final khop = bang.where((g) =>
        g.loaiGhe == ghe.loaiGhe &&
        g.loaiNgay == ln &&
        g.khungGio == kg &&
        (g.ngayApDung == null || !g.ngayApDung!.isAfter(suat.gioBatDau)));
    if (khop.isNotEmpty) {
      final ds = khop.toList()
        ..sort((a, b) => (b.ngayApDung ?? DateTime(1970))
            .compareTo(a.ngayApDung ?? DateTime(1970)));
      return ds.first.giaTien;
    }
    return (suat.giaVeCoBan * LoaiGhe.heSo(ghe.loaiGhe)).round();
  }

  /// Tổng tiền các ghế đã chọn (UC-DV bước 11)
  Future<num> tinhTong(SuatChieu suat, List<Ghe> ghes, {double giamGia = 0}) async {
    num tong = 0;
    for (final g in ghes) {
      tong += await giaMotGhe(suat, g);
    }
    return (tong * (1 - giamGia)).round();
  }

  Future<String> them(GiaVe g) async {
    xoaCache();
    return (await _c.add(g.toMap())).id;
  }

  Future<void> capNhat(GiaVe g) async {
    xoaCache();
    await _c.doc(g.giaVeId).update(g.toMap());
  }

  Future<void> xoa(String id) async {
    xoaCache();
    await _c.doc(id).delete();
  }
}
