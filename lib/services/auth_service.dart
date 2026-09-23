import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants.dart';
import '../models/nguoi_dung.dart';

/// UC-DKDN: Đăng ký / Đăng nhập (Email + Google)
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _google = GoogleSignIn(scopes: ['email']);

  Stream<User?> get trangThaiDangNhap => _auth.authStateChanges();
  User? get userHienTai => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(Col.users).doc(uid);

  /// UC-SI-01 — luồng chính bước 5, 6, 7
  Future<NguoiDung> dangKy({
    required String hoTen,
    required String email,
    required String soDienThoai,
    required String matKhau,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: matKhau);
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(hoTen);

      final nd = NguoiDung(
        uid: uid,
        hoTen: hoTen.trim(),
        email: email.trim(),
        soDienThoai: soDienThoai.trim(),
        vaiTro: VaiTro.khachHang,
      );
      // Tạo hồ sơ + thẻ thành viên (UC-TV) trong cùng một batch
      final batch = _db.batch();
      batch.set(_userRef(uid), nd.toMap());
      batch.set(_userRef(uid).collection(Col.theThanhVien).doc('info'), {
        'uid': uid,
        'diemTichLuy': 0,
        'hangThanhVien': HangThanhVien.bronze,
        'ngayCapNhat': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return nd;
    } on FirebaseAuthException catch (e) {
      throw Exception(_dichLoi(e.code));
    }
  }

  /// UC-LG-02
  Future<NguoiDung> dangNhap(String email, String matKhau) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: matKhau);
      final doc = await _userRef(cred.user!.uid).get();
      final nd = NguoiDung.fromDoc(doc);
      if (nd.biKhoa) {
        await _auth.signOut();
        throw Exception('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.');
      }
      return nd;
    } on FirebaseAuthException catch (e) {
      throw Exception(_dichLoi(e.code));
    }
  }

  /// Đăng nhập bằng Google — nếu là lần đầu thì tự tạo hồ sơ + thẻ thành viên
  /// giống luồng đăng ký thường (UC-SI-01), nếu đã có thì lấy hồ sơ hiện tại.
  Future<NguoiDung> dangNhapVoiGoogle() async {
    try {
      UserCredential cred;
      if (kIsWeb) {
        // Trên web, dùng popup của FirebaseAuth trực tiếp — ổn định hơn
        // và không cần cấu hình thêm Client ID phía package google_sign_in.
        final provider = GoogleAuthProvider();
        cred = await _auth.signInWithPopup(provider);
      } else {
        final ggUser = await _google.signIn();
        if (ggUser == null) throw Exception('Bạn đã hủy đăng nhập Google.');
        final ggAuth = await ggUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: ggAuth.accessToken,
          idToken: ggAuth.idToken,
        );
        cred = await _auth.signInWithCredential(credential);
      }

      final user = cred.user!;
      final docRef = _userRef(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Lần đầu đăng nhập bằng Google -> tạo hồ sơ + thẻ thành viên
        final nd = NguoiDung(
          uid: user.uid,
          hoTen: user.displayName ?? 'Khách hàng',
          email: user.email ?? '',
          soDienThoai: user.phoneNumber ?? '',
          vaiTro: VaiTro.khachHang,
        );
        final batch = _db.batch();
        batch.set(docRef, nd.toMap());
        batch.set(docRef.collection(Col.theThanhVien).doc('info'), {
          'uid': user.uid,
          'diemTichLuy': 0,
          'hangThanhVien': HangThanhVien.bronze,
          'ngayCapNhat': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        return nd;
      }

      final nd = NguoiDung.fromDoc(doc);
      if (nd.biKhoa) {
        await dangXuat();
        throw Exception('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.');
      }
      return nd;
    } on FirebaseAuthException catch (e) {
      throw Exception(_dichLoi(e.code));
    }
  }

  Future<void> dangXuat() async {
    await _auth.signOut();
    if (!kIsWeb) await _google.signOut();
  }

  Future<void> guiEmailDatLaiMatKhau(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Stream<NguoiDung?> hoSo(String uid) =>
      _userRef(uid).snapshots().map((d) => d.exists ? NguoiDung.fromDoc(d) : null);

  Future<NguoiDung?> layHoSo(String uid) async {
    final d = await _userRef(uid).get();
    return d.exists ? NguoiDung.fromDoc(d) : null;
  }

  /// UC-QLKH: admin khóa / mở khóa tài khoản
  Future<void> doiTrangThaiTaiKhoan(String uid, String trangThai) =>
      _userRef(uid).update({'trangThai': trangThai});

  Stream<List<NguoiDung>> danhSachKhachHang() => _db
      .collection(Col.users)
      .where('vaiTro', isEqualTo: VaiTro.khachHang)
      .snapshots()
      .map((s) => s.docs.map(NguoiDung.fromDoc).toList());

  String _dichLoi(String code) => switch (code) {
        'email-already-in-use' => 'Email đã được sử dụng, vui lòng dùng email khác.',
        'invalid-email' => 'Email không hợp lệ.',
        'weak-password' => 'Mật khẩu quá yếu (tối thiểu 6 ký tự).',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email hoặc mật khẩu không đúng.',
        'too-many-requests' => 'Bạn thử quá nhiều lần, vui lòng đợi ít phút.',
        _ => 'Đã xảy ra lỗi ($code). Vui lòng thử lại.',
      };
}