import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/nguoi_dung.dart';

/// UC-TV — Thẻ thành viên & điểm tích lũy
class ThanhVienService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) => _db
      .collection(Col.users)
      .doc(uid)
      .collection(Col.theThanhVien)
      .doc('info');

  Stream<TheThanhVien?> the(String uid) =>
      _ref(uid).snapshots().map((d) => d.exists ? TheThanhVien.fromDoc(d) : null);

  Future<TheThanhVien> layThe(String uid) async {
    final d = await _ref(uid).get();
    if (!d.exists) {
      final moi = TheThanhVien(uid: uid);
      await _ref(uid).set(moi.toMap());
      return moi;
    }
    return TheThanhVien.fromDoc(d);
  }

  Future<void> congDiem(String uid, int diem) async {
    if (diem <= 0) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref(uid));
      final hienTai = snap.exists ? (snap.data()!['diemTichLuy'] ?? 0).toInt() : 0;
      final moi = hienTai + diem;
      tx.set(_ref(uid), {
        'uid': uid,
        'diemTichLuy': moi,
        'hangThanhVien': HangThanhVien.tuDiem(moi),
        'ngayCapNhat': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> truDiem(String uid, int diem) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref(uid));
      final hienTai = snap.exists ? (snap.data()!['diemTichLuy'] ?? 0).toInt() : 0;
      final moi = (hienTai - diem).clamp(0, 1 << 31);
      tx.set(_ref(uid), {
        'uid': uid,
        'diemTichLuy': moi,
        'hangThanhVien': HangThanhVien.tuDiem(moi),
        'ngayCapNhat': FieldValue.serverTimestamp(),
      });
    });
  }
}
