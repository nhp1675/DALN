import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/dat_ve.dart';
import '../models/rap.dart';
import '../models/suat_chieu.dart';
import 'thanh_vien_service.dart';

/// UC-CC, UC-DV, UC-TT, UC-PHV
///
/// Toàn bộ thao tác đụng tới ghế đều chạy trong Firestore Transaction để bảo
/// đảm NFR #8: "Không được xảy ra tình trạng hai khách hàng cùng đặt thành
/// công một ghế".
class DatVeService {
  final _db = FirebaseFirestore.instance;
  final _thanhVien = ThanhVienService();

  CollectionReference<Map<String, dynamic>> get _gsc => _db.collection(Col.gheSuatChieu);
  CollectionReference<Map<String, dynamic>> get _don => _db.collection(Col.donDatVe);

  /// Sơ đồ ghế realtime của một suất chiếu (UC-CC bước 8, 9)
  Stream<Map<String, GheSuatChieu>> trangThaiGheTheoSuat(String suatId) => _gsc
      .where('suatId', isEqualTo: suatId)
      .snapshots()
      .map((s) => {for (final d in s.docs) GheSuatChieu.fromDoc(d).gheId: GheSuatChieu.fromDoc(d)});

  /// Bước 10 UC-DV: giữ ghế tạm thời trong [QuyDinh.phutGiuGhe] phút.
  /// Ném Exception nếu có ghế vừa bị người khác chiếm.
  Future<void> giuGhe({
    required String suatId,
    required List<String> gheIds,
    required String uid,
    String? donId,
  }) async {
    if (gheIds.isEmpty) throw Exception('Vui lòng chọn ít nhất 1 ghế.');
    await _db.runTransaction((tx) async {
      final refs = gheIds.map((g) => _gsc.doc(GheSuatChieu.docId(suatId, g))).toList();
      final snaps = await Future.wait(refs.map(tx.get));

      for (var i = 0; i < refs.length; i++) {
        final snap = snaps[i];
        if (snap.exists) {
          final g = GheSuatChieu.fromDoc(snap);
          final cuaChinhMinh = g.uidGiu == uid;
          if (!g.conTrong && !cuaChinhMinh) {
            throw Exception('Ghế ${gheIds[i]} vừa được người khác chọn, vui lòng chọn ghế khác.');
          }
        }
      }
      for (var i = 0; i < refs.length; i++) {
        tx.set(refs[i], {
          'suatId': suatId,
          'gheId': gheIds[i],
          'trangThaiGhe': TrangThaiGhe.dangGiu,
          'thoiGianGiu': FieldValue.serverTimestamp(),
          'uidGiu': uid,
          'donId': donId,
        });
      }
    });
  }

  /// Bỏ chọn ghế / hủy quá trình đặt vé (luồng thay thế UC-DV)
  Future<void> nhaGhe({
    required String suatId,
    required List<String> gheIds,
    required String uid,
  }) async {
    if (gheIds.isEmpty) return;
    await _db.runTransaction((tx) async {
      final refs = gheIds.map((g) => _gsc.doc(GheSuatChieu.docId(suatId, g))).toList();
      final snaps = await Future.wait(refs.map(tx.get));
      for (var i = 0; i < refs.length; i++) {
        if (!snaps[i].exists) continue;
        final g = GheSuatChieu.fromDoc(snaps[i]);
        // Chỉ nhả ghế mình đang giữ, không đụng vào ghế đã đặt
        if (g.trangThaiGhe == TrangThaiGhe.dangGiu && g.uidGiu == uid) {
          tx.set(refs[i], {
            'suatId': suatId,
            'gheId': gheIds[i],
            'trangThaiGhe': TrangThaiGhe.trong,
            'thoiGianGiu': null,
            'uidGiu': null,
            'donId': null,
          });
        }
      }
    });
  }

  /// Bước 13, 21 UC-DV: tạo đơn ở trạng thái "Chờ thanh toán".
  Future<String> taoDon({
    required String uid,
    required SuatChieu suat,
    required List<Ghe> ghes,
    required num tongTien,
  }) async {
    final gheIds = ghes.map((e) => e.gheId).toList();
    await giuGhe(suatId: suat.suatId, gheIds: gheIds, uid: uid);

    final don = DonDatVe(
      donId: '',
      uid: uid,
      suatId: suat.suatId,
      danhSachGheId: gheIds,
      tongTien: tongTien,
      trangThai: TrangThaiDon.choThanhToan,
      tenPhim: suat.tenPhim,
      tenRap: suat.tenRap,
      gioChieu: suat.gioBatDau,
    );
    final ref = await _don.add(don.toMap());
    // gắn donId vào các bản ghi giữ ghế để Cloud Function dọn dẹp biết nguồn gốc
    await giuGhe(suatId: suat.suatId, gheIds: gheIds, uid: uid, donId: ref.id);
    return ref.id;
  }

  /// Bước 19–23 UC-DV + UC-PHV: chốt ghế, phát hành vé điện tử, ghi nhận
  /// thanh toán và cộng điểm thành viên — tất cả trong MỘT transaction.
  Future<List<Ve>> xacNhanThanhToan({
    required String donId,
    required String uid,
    required SuatChieu suat,
    required List<Ghe> ghes,
    required Map<String, num> giaTheoGhe,
    required String phuongThuc,
    required String maGiaoDich,
  }) async {
    final veTao = <Ve>[];

    await _db.runTransaction((tx) async {
      final donRef = _don.doc(donId);
      final donSnap = await tx.get(donRef);
      if (!donSnap.exists) throw Exception('Không tìm thấy đơn đặt vé.');
      final don = DonDatVe.fromDoc(donSnap);
      if (don.trangThai == TrangThaiDon.daThanhToan) {
        throw Exception('Đơn này đã được thanh toán.');
      }

      // 1. Kiểm tra lại toàn bộ ghế vẫn đang do người này giữ
      final refs = ghes.map((g) => _gsc.doc(GheSuatChieu.docId(suat.suatId, g.gheId))).toList();
      final snaps = await Future.wait(refs.map(tx.get));
      for (var i = 0; i < snaps.length; i++) {
        if (!snaps[i].exists) throw Exception('Ghế ${ghes[i].ten} không còn hợp lệ.');
        final g = GheSuatChieu.fromDoc(snaps[i]);
        final hopLe = (g.trangThaiGhe == TrangThaiGhe.dangGiu && g.uidGiu == uid && !g.hetHanGiu);
        if (!hopLe) {
          throw Exception('Ghế ${ghes[i].ten} đã hết thời gian giữ hoặc được người khác đặt.');
        }
      }

      // 2. Chốt ghế sang "đã đặt"
      for (var i = 0; i < refs.length; i++) {
        tx.update(refs[i], {
          'trangThaiGhe': TrangThaiGhe.daDat,
          'donId': donId,
          'uidGiu': uid,
        });
      }

      // 3. Ghi nhận giao dịch thanh toán
      tx.set(_db.collection(Col.thanhToan).doc(), {
        'donId': donId,
        'phuongThuc': phuongThuc,
        'soTien': don.tongTien,
        'trangThai': TrangThaiThanhToan.thanhCong,
        'maGiaoDich': maGiaoDich,
        'thoiGian': FieldValue.serverTimestamp(),
      });

      // 4. Phát hành vé điện tử (UC-PHV)
      for (final g in ghes) {
        final veRef = donRef.collection(Col.ve).doc();
        final ve = Ve(
          veId: veRef.id,
          donId: donId,
          suatId: suat.suatId,
          gheId: g.gheId,
          tenGhe: g.ten,
          maQR: maQRNgauNhien(),
          giaVe: giaTheoGhe[g.gheId] ?? 0,
          trangThai: TrangThaiVe.hopLe,
          tenPhim: suat.tenPhim,
          tenRap: suat.tenRap,
          tenPhong: suat.tenPhong,
          gioChieu: suat.gioBatDau,
          uid: uid,
        );
        tx.set(veRef, ve.toMap());
        veTao.add(ve);
      }

      // 5. Cập nhật đơn
      tx.update(donRef, {
        'trangThai': TrangThaiDon.daThanhToan,
        'phuongThucThanhToan': phuongThuc,
      });
    });

    // 6. Cộng điểm thành viên (UC-TV) — ngoài transaction, không ảnh hưởng vé
    final don = await layDon(donId);
    if (don != null) {
      await _thanhVien.congDiem(uid, (don.tongTien / QuyDinh.donViTichDiem).floor());
    }
    return veTao;
  }

  /// Thanh toán thất bại / khách hủy ở cổng thanh toán (NFR #9)
  Future<void> huyDonChuaThanhToan({required String donId, required String uid}) async {
    final don = await layDon(donId);
    if (don == null || don.trangThai == TrangThaiDon.daThanhToan) return;
    await nhaGhe(suatId: don.suatId, gheIds: don.danhSachGheId, uid: uid);
    await _don.doc(donId).update({'trangThai': TrangThaiDon.daHuy});
  }

  Future<void> ghiNhanThanhToanThatBai({
    required String donId,
    required num soTien,
    required String phuongThuc,
    required String maGiaoDich,
  }) =>
      _db.collection(Col.thanhToan).add({
        'donId': donId,
        'phuongThuc': phuongThuc,
        'soTien': soTien,
        'trangThai': TrangThaiThanhToan.thatBai,
        'maGiaoDich': maGiaoDich,
        'thoiGian': FieldValue.serverTimestamp(),
      });

  Future<DonDatVe?> layDon(String donId) async {
    final d = await _don.doc(donId).get();
    return d.exists ? DonDatVe.fromDoc(d) : null;
  }

  /// UC-XLSDV: lịch sử đặt vé của khách hàng
  Stream<List<DonDatVe>> lichSuDon(String uid) => _don
      .where('uid', isEqualTo: uid)
      .orderBy('ngayDat', descending: true)
      .snapshots()
      .map((s) => s.docs.map(DonDatVe.fromDoc).toList());

  /// UC-QLDDV: admin theo dõi toàn bộ đơn
  Stream<List<DonDatVe>> tatCaDon({String? trangThai}) {
    Query<Map<String, dynamic>> q = _don.orderBy('ngayDat', descending: true).limit(200);
    if (trangThai != null) {
      q = _don
          .where('trangThai', isEqualTo: trangThai)
          .orderBy('ngayDat', descending: true)
          .limit(200);
    }
    return q.snapshots().map((s) => s.docs.map(DonDatVe.fromDoc).toList());
  }
}
