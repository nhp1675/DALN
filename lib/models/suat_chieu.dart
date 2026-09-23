import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// Collection: suatChieu
class SuatChieu {
  final String suatId;
  final String phimId;
  final String phongId;
  final String rapId; // denormalize
  final String tenPhim; // denormalize — hiển thị danh sách không cần join
  final String tenRap;
  final String tenPhong;
  final DateTime gioBatDau;
  final DateTime gioKetThuc;
  final num giaVeCoBan;
  final String trangThai;

  const SuatChieu({
    required this.suatId,
    required this.phimId,
    required this.phongId,
    required this.rapId,
    required this.gioBatDau,
    required this.gioKetThuc,
    this.tenPhim = '',
    this.tenRap = '',
    this.tenPhong = '',
    this.giaVeCoBan = 0,
    this.trangThai = TrangThaiSuat.conSuat,
  });

  bool get daChieu => DateTime.now().isAfter(gioBatDau);
  bool get conBanVe => trangThai == TrangThaiSuat.conSuat && !daChieu;

  factory SuatChieu.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SuatChieu(
      suatId: d.id,
      phimId: m['phimId'] ?? '',
      phongId: m['phongId'] ?? '',
      rapId: m['rapId'] ?? '',
      tenPhim: m['tenPhim'] ?? '',
      tenRap: m['tenRap'] ?? '',
      tenPhong: m['tenPhong'] ?? '',
      gioBatDau: (m['gioBatDau'] as Timestamp).toDate(),
      gioKetThuc: (m['gioKetThuc'] as Timestamp).toDate(),
      giaVeCoBan: m['giaVeCoBan'] ?? 0,
      trangThai: m['trangThai'] ?? TrangThaiSuat.conSuat,
    );
  }

  Map<String, dynamic> toMap() => {
        'phimId': phimId,
        'phongId': phongId,
        'rapId': rapId,
        'tenPhim': tenPhim,
        'tenRap': tenRap,
        'tenPhong': tenPhong,
        'ngayChieu': '${gioBatDau.year}-${gioBatDau.month.toString().padLeft(2, '0')}-${gioBatDau.day.toString().padLeft(2, '0')}',
        'gioBatDau': Timestamp.fromDate(gioBatDau),
        'gioKetThuc': Timestamp.fromDate(gioKetThuc),
        'giaVeCoBan': giaVeCoBan,
        'trangThai': trangThai,
      };
}

/// Collection: ghe_suat_chieu — docId = {suatId}_{gheId}
class GheSuatChieu {
  final String id;
  final String suatId;
  final String gheId;
  final String trangThaiGhe;
  final DateTime? thoiGianGiu;
  final String? donId;
  final String? uidGiu;

  const GheSuatChieu({
    required this.id,
    required this.suatId,
    required this.gheId,
    this.trangThaiGhe = TrangThaiGhe.trong,
    this.thoiGianGiu,
    this.donId,
    this.uidGiu,
  });

  static String docId(String suatId, String gheId) => '${suatId}_$gheId';

  /// Ghế "đang giữ" quá hạn được coi như trống (Cloud Function sẽ dọn nền)
  bool get hetHanGiu =>
      trangThaiGhe == TrangThaiGhe.dangGiu &&
      thoiGianGiu != null &&
      DateTime.now().difference(thoiGianGiu!).inMinutes >= QuyDinh.phutGiuGhe;

  bool get conTrong => trangThaiGhe == TrangThaiGhe.trong || hetHanGiu;

  factory GheSuatChieu.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return GheSuatChieu(
      id: d.id,
      suatId: m['suatId'] ?? '',
      gheId: m['gheId'] ?? '',
      trangThaiGhe: m['trangThaiGhe'] ?? TrangThaiGhe.trong,
      thoiGianGiu: (m['thoiGianGiu'] as Timestamp?)?.toDate(),
      donId: m['donId'],
      uidGiu: m['uidGiu'],
    );
  }
}

/// Collection: giaVe
class GiaVe {
  final String giaVeId;
  final String loaiGhe;
  final String loaiNgay;  // NgayThuong | CuoiTuan
  final String khungGio;  // Sang | Toi
  final num giaTien;
  final DateTime? ngayApDung;

  const GiaVe({
    required this.giaVeId,
    required this.loaiGhe,
    required this.loaiNgay,
    required this.khungGio,
    required this.giaTien,
    this.ngayApDung,
  });

  factory GiaVe.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return GiaVe(
      giaVeId: d.id,
      loaiGhe: m['loaiGhe'] ?? LoaiGhe.thuong,
      loaiNgay: m['loaiNgay'] ?? 'NgayThuong',
      khungGio: m['khungGio'] ?? 'Sang',
      giaTien: m['giaTien'] ?? 0,
      ngayApDung: (m['ngayApDung'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'loaiGhe': loaiGhe,
        'loaiNgay': loaiNgay,
        'khungGio': khungGio,
        'giaTien': giaTien,
        'ngayApDung': ngayApDung == null ? null : Timestamp.fromDate(ngayApDung!),
      };
}
