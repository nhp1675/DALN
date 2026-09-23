import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/dat_ve.dart';
import '../models/rap.dart';
import '../models/suat_chieu.dart';
import 'dat_ve_service.dart';
import 'thanh_toan_service.dart';

/// UC-XLSDV, UC-HDV — quản lý vé điện tử, hủy và đổi vé
class VeService {
  final _db = FirebaseFirestore.instance;
  final _datVe = DatVeService();
  final _cong = ThanhToanService();

  /// Tất cả vé của một khách hàng (collectionGroup trên subcollection ve)
  Stream<List<Ve>> veCuaToi(String uid) => _db
      .collectionGroup(Col.ve)
      .where('uid', isEqualTo: uid)
      .orderBy('gioChieu', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Ve.fromDoc).toList());

  Stream<List<Ve>> veCuaDon(String donId) => _db
      .collection(Col.donDatVe)
      .doc(donId)
      .collection(Col.ve)
      .snapshots()
      .map((s) => s.docs.map(Ve.fromDoc).toList());

  DocumentReference<Map<String, dynamic>> _veRef(String donId, String veId) =>
      _db.collection(Col.donDatVe).doc(donId).collection(Col.ve).doc(veId);

  /// Soát vé tại rạp (quét QR)
  Future<Ve> kiemTraMaQR(String maQR) async {
    final s = await _db.collectionGroup(Col.ve).where('maQR', isEqualTo: maQR).limit(1).get();
    if (s.docs.isEmpty) throw Exception('Mã vé không tồn tại.');
    final ve = Ve.fromDoc(s.docs.first);
    if (ve.trangThai != TrangThaiVe.hopLe) throw Exception('Vé không còn hợp lệ (${ve.trangThai}).');
    await s.docs.first.reference.update({'trangThai': TrangThaiVe.daDung});
    return ve;
  }

  /// UC-HDV — Hủy vé: nhả ghế, hoàn tiền (trừ phí), ghi log huyDoiVe
  Future<num> huyVe({required Ve ve, required String uid, String lyDo = ''}) async {
    if (!ve.coTheHuyDoi) {
      throw Exception(
          'Vé không đủ điều kiện hủy (phải hủy trước giờ chiếu ít nhất ${QuyDinh.gioToiThieuTruocSuat} giờ).');
    }
    final tienHoan = (ve.giaVe * (1 - QuyDinh.phiHuyVe)).round();

    // 1. Nhả ghế + cập nhật trạng thái vé trong transaction
    await _db.runTransaction((tx) async {
      final veSnap = await tx.get(_veRef(ve.donId, ve.veId));
      if (!veSnap.exists) throw Exception('Không tìm thấy vé.');
      if ((veSnap.data()!['trangThai'] ?? '') != TrangThaiVe.hopLe) {
        throw Exception('Vé đã được xử lý trước đó.');
      }
      final gscRef = _db.collection(Col.gheSuatChieu).doc(GheSuatChieu.docId(ve.suatId, ve.gheId));
      tx.update(_veRef(ve.donId, ve.veId), {'trangThai': TrangThaiVe.daHuy});
      tx.set(gscRef, {
        'suatId': ve.suatId,
        'gheId': ve.gheId,
        'trangThaiGhe': TrangThaiGhe.trong,
        'thoiGianGiu': null,
        'uidGiu': null,
        'donId': null,
      });
    });

    // 2. Hoàn tiền qua cổng thanh toán
    final kq = await _cong.hoanTien(donId: ve.donId, soTien: tienHoan);

    // 3. Ghi nhận vào bảng huyDoiVe
    await _db.collection(Col.huyDoiVe).add(HuyDoiVe(
          id: '',
          veId: ve.veId,
          loai: 'huy',
          lyDo: lyDo,
          soTienHoan: kq.thanhCong ? tienHoan : 0,
          trangThai: kq.thanhCong ? 'hoanTat' : 'thatBai',
        ).toMap());

    if (!kq.thanhCong) throw Exception('Hoàn tiền thất bại, hệ thống đã ghi nhận để xử lý lại.');
    return tienHoan;
  }

  /// UC-HDV — Đổi vé sang suất/ghế mới, xử lý chênh lệch giá.
  /// Nếu phải thu thêm mà thanh toán thất bại thì giữ nguyên vé cũ.
  Future<num> doiVe({
    required Ve veCu,
    required String uid,
    required SuatChieu suatMoi,
    required Ghe gheMoi,
    required num giaMoi,
  }) async {
    if (!veCu.coTheHuyDoi) {
      throw Exception('Vé không đủ điều kiện đổi.');
    }
    if (!suatMoi.conBanVe) throw Exception('Suất chiếu mới không còn bán vé.');

    final chenhLech = giaMoi - veCu.giaVe;

    // 1. Giữ ghế mới trước (nếu bị người khác chiếm thì dừng, vé cũ nguyên vẹn)
    await _datVe.giuGhe(suatId: suatMoi.suatId, gheIds: [gheMoi.gheId], uid: uid);

    // 2. Thu thêm nếu giá cao hơn
    if (chenhLech > 0) {
      final kq = await _cong.thanhToan(
          donId: veCu.donId, soTien: chenhLech, phuongThuc: PhuongThucThanhToan.the);
      if (!kq.thanhCong) {
        await _datVe.nhaGhe(suatId: suatMoi.suatId, gheIds: [gheMoi.gheId], uid: uid);
        await _db.collection(Col.huyDoiVe).add(HuyDoiVe(
              id: '', veId: veCu.veId, loai: 'doi',
              soTienThuThem: chenhLech, trangThai: 'thatBai',
              suatMoiId: suatMoi.suatId, gheMoiId: gheMoi.gheId,
            ).toMap());
        throw Exception('Thanh toán chênh lệch thất bại, vé cũ được giữ nguyên.');
      }
    } else if (chenhLech < 0) {
      await _cong.hoanTien(donId: veCu.donId, soTien: -chenhLech);
    }

    // 3. Chuyển ghế: nhả ghế cũ, chốt ghế mới, cập nhật vé
    await _db.runTransaction((tx) async {
      final veRef = _veRef(veCu.donId, veCu.veId);
      final veSnap = await tx.get(veRef);
      if (!veSnap.exists || (veSnap.data()!['trangThai'] ?? '') != TrangThaiVe.hopLe) {
        throw Exception('Vé đã được xử lý trước đó.');
      }
      final gheCuRef = _db.collection(Col.gheSuatChieu).doc(GheSuatChieu.docId(veCu.suatId, veCu.gheId));
      final gheMoiRef = _db.collection(Col.gheSuatChieu).doc(GheSuatChieu.docId(suatMoi.suatId, gheMoi.gheId));

      tx.set(gheCuRef, {
        'suatId': veCu.suatId, 'gheId': veCu.gheId,
        'trangThaiGhe': TrangThaiGhe.trong,
        'thoiGianGiu': null, 'uidGiu': null, 'donId': null,
      });
      tx.set(gheMoiRef, {
        'suatId': suatMoi.suatId, 'gheId': gheMoi.gheId,
        'trangThaiGhe': TrangThaiGhe.daDat,
        'thoiGianGiu': null, 'uidGiu': uid, 'donId': veCu.donId,
      });
      tx.update(veRef, {
        'suatId': suatMoi.suatId,
        'gheId': gheMoi.gheId,
        'tenGhe': gheMoi.ten,
        'giaVe': giaMoi,
        'tenPhim': suatMoi.tenPhim,
        'tenRap': suatMoi.tenRap,
        'tenPhong': suatMoi.tenPhong,
        'gioChieu': Timestamp.fromDate(suatMoi.gioBatDau),
      });
    });

    // 4. Ghi log
    await _db.collection(Col.huyDoiVe).add(HuyDoiVe(
          id: '', veId: veCu.veId, loai: 'doi',
          soTienThuThem: chenhLech > 0 ? chenhLech : 0,
          soTienHoan: chenhLech < 0 ? -chenhLech : 0,
          suatMoiId: suatMoi.suatId, gheMoiId: gheMoi.gheId,
          trangThai: 'hoanTat',
        ).toMap());

    return chenhLech;
  }
}
