import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/rap.dart';

/// UC-CR, UC-QLRPC, UC-QLG
class RapService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Rap>> danhSachRap() => _db
      .collection(Col.rap)
      .snapshots()
      .map((s) => s.docs.map(Rap.fromDoc).toList());

  Future<List<Rap>> layRapHoatDong() async {
    final s = await _db
        .collection(Col.rap)
        .where('trangThai', isEqualTo: 'hoatDong')
        .get();
    return s.docs.map(Rap.fromDoc).toList();
  }

  Future<String> themRap(Rap r) async =>
      (await _db.collection(Col.rap).add(r.toMap())).id;

  Future<void> capNhatRap(Rap r) =>
      _db.collection(Col.rap).doc(r.rapId).update(r.toMap());

  Future<void> xoaRap(String rapId) =>
      _db.collection(Col.rap).doc(rapId).delete();

  // ----- Phòng chiếu -----
  CollectionReference<Map<String, dynamic>> _phong(String rapId) =>
      _db.collection(Col.rap).doc(rapId).collection(Col.phongChieu);

  Stream<List<PhongChieu>> danhSachPhong(String rapId) =>
      _phong(rapId).snapshots().map((s) => s.docs.map(PhongChieu.fromDoc).toList());

  Future<PhongChieu?> layPhong(String rapId, String phongId) async {
    final d = await _phong(rapId).doc(phongId).get();
    return d.exists ? PhongChieu.fromDoc(d) : null;
  }

  /// Tạo phòng và sinh sẵn sơ đồ ghế (UC-QLG)
  Future<String> themPhong(
    PhongChieu p, {
    int soHang = 8,
    int soGheMoiHang = 10,
    List<String> hangVip = const ['E', 'F'],
  }) async {
    final ref = await _phong(p.rapId).add({
      ...p.toMap(),
      'soLuongGhe': soHang * soGheMoiHang,
    });
    final batch = _db.batch();
    for (var i = 0; i < soHang; i++) {
      final hang = String.fromCharCode(65 + i); // A, B, C...
      for (var j = 1; j <= soGheMoiHang; j++) {
        final gheRef = ref.collection(Col.ghe).doc('$hang$j');
        batch.set(gheRef, {
          'phongId': ref.id,
          'hang': hang,
          'so': j,
          'loaiGhe': hangVip.contains(hang) ? LoaiGhe.vip : LoaiGhe.thuong,
        });
      }
    }
    await batch.commit();
    return ref.id;
  }

  Future<void> capNhatPhong(PhongChieu p) =>
      _phong(p.rapId).doc(p.phongId).update(p.toMap());

  // ----- Ghế -----
  Future<List<Ghe>> layGheCuaPhong(String rapId, String phongId) async {
    final s = await _phong(rapId).doc(phongId).collection(Col.ghe).get();
    final ds = s.docs.map(Ghe.fromDoc).toList();
    ds.sort((a, b) => a.hang == b.hang ? a.so.compareTo(b.so) : a.hang.compareTo(b.hang));
    return ds;
  }

  Future<void> capNhatLoaiGhe(
          String rapId, String phongId, String gheId, String loaiGhe) =>
      _phong(rapId).doc(phongId).collection(Col.ghe).doc(gheId).update({'loaiGhe': loaiGhe});
}
