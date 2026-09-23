import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/chat.dart';
import '../models/suat_chieu.dart';

/// UC-PC — Phòng chat theo suất chiếu.
/// Chỉ khách hàng có vé đã thanh toán của suất chiếu đó mới được vào.
class ChatService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _phong(String suatId) =>
      _db.collection(Col.phongChat).doc(suatId);

  /// Bước 4, 5 UC-PC: kiểm tra vé hợp lệ của khách cho suất chiếu này
  Future<bool> duDieuKienVao(String uid, String suatId) async {
    final s = await _db
        .collectionGroup(Col.ve)
        .where('uid', isEqualTo: uid)
        .where('suatId', isEqualTo: suatId)
        .where('trangThai', isEqualTo: TrangThaiVe.hopLe)
        .limit(1)
        .get();
    return s.docs.isNotEmpty;
  }

  /// Bước 6, 7, 8: xác định phòng theo suatId, tạo nếu chưa có, thêm thành viên
  Future<PhongChat> vaoPhong({
    required String uid,
    required SuatChieu suat,
  }) async {
    if (!await duDieuKienVao(uid, suat.suatId)) {
      throw Exception('Bạn cần có vé đã thanh toán của suất chiếu này để vào phòng chat.');
    }
    final ref = _phong(suat.suatId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'danhSachThanhVien': [uid],
          'ngayTao': FieldValue.serverTimestamp(),
          'tenPhim': suat.tenPhim,
          'gioChieu': Timestamp.fromDate(suat.gioBatDau),
        });
      } else {
        tx.update(ref, {'danhSachThanhVien': FieldValue.arrayUnion([uid])});
      }
    });
    return PhongChat.fromDoc(await ref.get());
  }

  /// Bước 13, 14: rời phòng
  Future<void> roiPhong(String uid, String suatId) =>
      _phong(suatId).update({'danhSachThanhVien': FieldValue.arrayRemove([uid])});

  Stream<PhongChat?> thongTinPhong(String suatId) =>
      _phong(suatId).snapshots().map((d) => d.exists ? PhongChat.fromDoc(d) : null);

  Stream<List<TinNhan>> tinNhan(String suatId) => _phong(suatId)
      .collection(Col.tinNhan)
      .orderBy('thoiGian', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(TinNhan.fromDoc).toList());

  Future<void> guiTinNhan({
    required String suatId,
    required String uid,
    required String hoTen,
    required String noiDung,
    String? hinhAnhUrl,
  }) async {
    final text = noiDung.trim();
    if (text.isEmpty && hinhAnhUrl == null) return;
    await _phong(suatId).collection(Col.tinNhan).add(TinNhan(
          tinNhanId: '', uid: uid, hoTen: hoTen,
          noiDung: text, hinhAnhUrl: hinhAnhUrl,
        ).toMap());
  }

  /// Danh sách phòng chat mà khách hàng đang tham gia
  Stream<List<PhongChat>> phongCuaToi(String uid) => _db
      .collection(Col.phongChat)
      .where('danhSachThanhVien', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(PhongChat.fromDoc).toList());
}
