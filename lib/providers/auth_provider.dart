import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nguoi_dung.dart';
import '../services/auth_service.dart';

/// Trạng thái đăng nhập dùng chung toàn app (UC-DKDN)
class AuthProvider extends ChangeNotifier {
  final _service = AuthService();
  StreamSubscription? _subUser, _subHoSo;

  User? _firebaseUser;
  NguoiDung? _hoSo;
  bool _dangTai = true;

  AuthProvider() {
    _subUser = _service.trangThaiDangNhap.listen((u) async {
      _firebaseUser = u;
      _subHoSo?.cancel();
      if (u == null) {
        _hoSo = null;
        _dangTai = false;
        notifyListeners();
      } else {
        _subHoSo = _service.hoSo(u.uid).listen((nd) {
          _hoSo = nd;
          _dangTai = false;
          notifyListeners();
        });
      }
    });
  }

  bool get dangTai => _dangTai;
  bool get daDangNhap => _firebaseUser != null;
  bool get laAdmin => _hoSo?.laAdmin ?? false;
  String get uid => _firebaseUser?.uid ?? '';
  String get hoTen => _hoSo?.hoTen ?? _firebaseUser?.displayName ?? 'Khách';
  NguoiDung? get hoSo => _hoSo;
  AuthService get service => _service;

  Future<void> dangNhap(String email, String matKhau) =>
      _service.dangNhap(email, matKhau);

  Future<void> dangKy({
    required String hoTen,
    required String email,
    required String soDienThoai,
    required String matKhau,
  }) =>
      _service.dangKy(
          hoTen: hoTen, email: email, soDienThoai: soDienThoai, matKhau: matKhau);

  Future<void> dangNhapVoiGoogle() => _service.dangNhapVoiGoogle();

  Future<void> dangXuat() => _service.dangXuat();

  @override
  void dispose() {
    _subUser?.cancel();
    _subHoSo?.cancel();
    super.dispose();
  }
}