import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/phim.dart';

/// UC-XDSP, UC-XTTP, UC-TK, UC-QLP
class PhimService {
  final _c = FirebaseFirestore.instance.collection(Col.phim);

  Stream<List<Phim>> danhSach({String? trangThai}) {
    Query<Map<String, dynamic>> q = _c;
    if (trangThai != null) q = q.where('trangThai', isEqualTo: trangThai);
    return q.snapshots().map((s) => s.docs.map(Phim.fromDoc).toList());
  }

  Stream<Phim?> chiTiet(String phimId) =>
      _c.doc(phimId).snapshots().map((d) => d.exists ? Phim.fromDoc(d) : null);

  /// UC-TK — lọc phía client cho phép tìm theo tên, thể loại, đạo diễn
  List<Phim> timKiem(List<Phim> nguon, String tuKhoa, {String? theLoai}) {
    final k = tuKhoa.trim().toLowerCase();
    return nguon.where((p) {
      final hopTuKhoa = k.isEmpty || p.khoaTimKiem.contains(k);
      final hopTheLoai = theLoai == null || p.theLoai.contains(theLoai);
      return hopTuKhoa && hopTheLoai;
    }).toList();
  }

  Future<String> them(Phim p) async => (await _c.add(p.toMap())).id;

  Future<void> capNhat(Phim p) => _c.doc(p.phimId).update(p.toMap());

  /// Ngoại lệ UC-QLP: phim đang có suất chiếu thì không cho xóa
  Future<void> xoa(String phimId) async {
    final suat = await FirebaseFirestore.instance
        .collection(Col.suatChieu)
        .where('phimId', isEqualTo: phimId)
        .where('gioBatDau', isGreaterThan: Timestamp.now())
        .limit(1)
        .get();
    if (suat.docs.isNotEmpty) {
      throw Exception('Phim đang có suất chiếu, vui lòng xử lý suất chiếu trước khi xóa.');
    }
    await _c.doc(phimId).delete();
  }
}
