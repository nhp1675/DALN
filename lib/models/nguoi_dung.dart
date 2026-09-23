import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// Collection: users
class NguoiDung {
  final String uid;
  final String hoTen;
  final String email;
  final String soDienThoai;
  final String vaiTro;
  final String trangThai;
  final DateTime? ngayTao;

  const NguoiDung({
    required this.uid,
    required this.hoTen,
    required this.email,
    this.soDienThoai = '',
    this.vaiTro = VaiTro.khachHang,
    this.trangThai = TrangThaiTaiKhoan.active,
    this.ngayTao,
  });

  bool get laAdmin => vaiTro == VaiTro.admin;
  bool get biKhoa => trangThai == TrangThaiTaiKhoan.locked;

  factory NguoiDung.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return NguoiDung(
      uid: d.id,
      hoTen: m['hoTen'] ?? '',
      email: m['email'] ?? '',
      soDienThoai: m['soDienThoai'] ?? '',
      vaiTro: m['vaiTro'] ?? VaiTro.khachHang,
      trangThai: m['trangThai'] ?? TrangThaiTaiKhoan.active,
      ngayTao: (m['ngayTao'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'hoTen': hoTen,
        'email': email,
        'soDienThoai': soDienThoai,
        'vaiTro': vaiTro,
        'trangThai': trangThai,
        'ngayTao': ngayTao == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(ngayTao!),
      };
}

/// Subcollection: users/{uid}/theThanhVien/info
class TheThanhVien {
  final String uid;
  final int diemTichLuy;
  final String hangThanhVien;
  final DateTime? ngayCapNhat;

  const TheThanhVien({
    required this.uid,
    this.diemTichLuy = 0,
    this.hangThanhVien = HangThanhVien.bronze,
    this.ngayCapNhat,
  });

  double get phanTramGiam => HangThanhVien.giamGia(hangThanhVien);

  factory TheThanhVien.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return TheThanhVien(
      uid: m['uid'] ?? '',
      diemTichLuy: (m['diemTichLuy'] ?? 0).toInt(),
      hangThanhVien: m['hangThanhVien'] ?? HangThanhVien.bronze,
      ngayCapNhat: (m['ngayCapNhat'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'diemTichLuy': diemTichLuy,
        'hangThanhVien': hangThanhVien,
        'ngayCapNhat': FieldValue.serverTimestamp(),
      };
}
