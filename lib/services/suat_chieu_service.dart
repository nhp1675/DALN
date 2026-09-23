import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/suat_chieu.dart';

/// UC-XLC, UC-CSC, UC-QLSC
class SuatChieuService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _c => _db.collection(Col.suatChieu);

  /// Lịch chiếu theo phim + rạp + ngày (UC-XLC)
  Stream<List<SuatChieu>> theoPhim(String phimId, {String? rapId, DateTime? ngay}) {
    Query<Map<String, dynamic>> q =
        _c.where('phimId', isEqualTo: phimId).where('trangThai', isEqualTo: TrangThaiSuat.conSuat);
    if (rapId != null) q = q.where('rapId', isEqualTo: rapId);
    if (ngay != null) {
      final dau = DateTime(ngay.year, ngay.month, ngay.day);
      final cuoi = dau.add(const Duration(days: 1));
      q = q
          .where('gioBatDau', isGreaterThanOrEqualTo: Timestamp.fromDate(dau))
          .where('gioBatDau', isLessThan: Timestamp.fromDate(cuoi));
    }
    return q.orderBy('gioBatDau').snapshots().map((s) => s.docs.map(SuatChieu.fromDoc).toList());
  }

  Stream<List<SuatChieu>> tatCa() =>
      _c.orderBy('gioBatDau', descending: true).snapshots().map((s) => s.docs.map(SuatChieu.fromDoc).toList());

  Future<SuatChieu?> chiTiet(String suatId) async {
    final d = await _c.doc(suatId).get();
    return d.exists ? SuatChieu.fromDoc(d) : null;
  }

  Stream<SuatChieu?> chiTietStream(String suatId) =>
      _c.doc(suatId).snapshots().map((d) => d.exists ? SuatChieu.fromDoc(d) : null);

  /// UC-QLSC — chặn trùng lịch phòng chiếu (ngoại lệ trong đặc tả)
  Future<String> them(SuatChieu s) async {
    await _kiemTraTrungLich(s);
    return (await _c.add(s.toMap())).id;
  }

  Future<void> capNhat(SuatChieu s) async {
    await _kiemTraTrungLich(s, boQuaSuatId: s.suatId);
    await _c.doc(s.suatId).update(s.toMap());
  }

  Future<void> _kiemTraTrungLich(SuatChieu s, {String? boQuaSuatId}) async {
    if (!s.gioKetThuc.isAfter(s.gioBatDau)) {
      throw Exception('Giờ kết thúc phải sau giờ bắt đầu.');
    }
    final snap = await _c
        .where('phongId', isEqualTo: s.phongId)
        .where('gioBatDau', isLessThan: Timestamp.fromDate(s.gioKetThuc))
        .get();
    for (final d in snap.docs) {
      if (d.id == boQuaSuatId) continue;
      final khac = SuatChieu.fromDoc(d);
      if (khac.trangThai == TrangThaiSuat.daHuy) continue;
      if (khac.gioKetThuc.isAfter(s.gioBatDau)) {
        throw Exception('Phòng chiếu đã có suất chiếu khác trong khung giờ này.');
      }
    }
  }

  /// Ngoại lệ UC-QLSC: suất chiếu đã có vé thì không xóa, chỉ hủy
  Future<void> xoa(String suatId) async {
    final ve = await _db
        .collection(Col.gheSuatChieu)
        .where('suatId', isEqualTo: suatId)
        .where('trangThaiGhe', isEqualTo: TrangThaiGhe.daDat)
        .limit(1)
        .get();
    if (ve.docs.isNotEmpty) {
      throw Exception('Suất chiếu đã có vé được đặt, không thể xóa. Hãy chuyển sang trạng thái Đã hủy.');
    }
    await _c.doc(suatId).delete();
  }

  Future<void> doiTrangThai(String suatId, String trangThai) =>
      _c.doc(suatId).update({'trangThai': trangThai});
}
