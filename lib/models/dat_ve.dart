import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// Collection: donDatVe
class DonDatVe {
  final String donId;
  final String uid;
  final String suatId;
  final List<String> danhSachGheId;
  final num tongTien;
  final String trangThai;
  final String phuongThucThanhToan;
  final DateTime? ngayDat;
  // denormalize để hiển thị lịch sử đặt vé không cần join
  final String tenPhim;
  final String tenRap;
  final DateTime? gioChieu;

  const DonDatVe({
    required this.donId,
    required this.uid,
    required this.suatId,
    required this.danhSachGheId,
    required this.tongTien,
    this.trangThai = TrangThaiDon.choThanhToan,
    this.phuongThucThanhToan = '',
    this.ngayDat,
    this.tenPhim = '',
    this.tenRap = '',
    this.gioChieu,
  });

  factory DonDatVe.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return DonDatVe(
      donId: d.id,
      uid: m['uid'] ?? '',
      suatId: m['suatId'] ?? '',
      danhSachGheId: List<String>.from(m['danhSachGheId'] ?? const []),
      tongTien: m['tongTien'] ?? 0,
      trangThai: m['trangThai'] ?? TrangThaiDon.choThanhToan,
      phuongThucThanhToan: m['phuongThucThanhToan'] ?? '',
      ngayDat: (m['ngayDat'] as Timestamp?)?.toDate(),
      tenPhim: m['tenPhim'] ?? '',
      tenRap: m['tenRap'] ?? '',
      gioChieu: (m['gioChieu'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'suatId': suatId,
        'danhSachGheId': danhSachGheId,
        'tongTien': tongTien,
        'trangThai': trangThai,
        'phuongThucThanhToan': phuongThucThanhToan,
        'ngayDat': ngayDat == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(ngayDat!),
        'tenPhim': tenPhim,
        'tenRap': tenRap,
        'gioChieu': gioChieu == null ? null : Timestamp.fromDate(gioChieu!),
      };
}

/// Subcollection: donDatVe/{donId}/ve
class Ve {
  final String veId;
  final String donId;
  final String suatId;
  final String gheId;
  final String tenGhe;
  final String maQR;
  final num giaVe;
  final String trangThai;
  final String tenPhim;
  final String tenRap;
  final String tenPhong;
  final DateTime? gioChieu;
  final String uid;

  const Ve({
    required this.veId,
    required this.donId,
    required this.suatId,
    required this.gheId,
    required this.maQR,
    required this.giaVe,
    this.tenGhe = '',
    this.trangThai = TrangThaiVe.hopLe,
    this.tenPhim = '',
    this.tenRap = '',
    this.tenPhong = '',
    this.gioChieu,
    this.uid = '',
  });

  bool get coTheHuyDoi {
    if (trangThai != TrangThaiVe.hopLe || gioChieu == null) return false;
    return gioChieu!.difference(DateTime.now()).inHours >= QuyDinh.gioToiThieuTruocSuat;
  }

  factory Ve.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Ve(
      veId: d.id,
      donId: m['donId'] ?? '',
      suatId: m['suatId'] ?? '',
      gheId: m['gheId'] ?? '',
      tenGhe: m['tenGhe'] ?? '',
      maQR: m['maQR'] ?? '',
      giaVe: m['giaVe'] ?? 0,
      trangThai: m['trangThai'] ?? TrangThaiVe.hopLe,
      tenPhim: m['tenPhim'] ?? '',
      tenRap: m['tenRap'] ?? '',
      tenPhong: m['tenPhong'] ?? '',
      gioChieu: (m['gioChieu'] as Timestamp?)?.toDate(),
      uid: m['uid'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'donId': donId,
        'suatId': suatId,
        'gheId': gheId,
        'tenGhe': tenGhe,
        'maQR': maQR,
        'giaVe': giaVe,
        'trangThai': trangThai,
        'tenPhim': tenPhim,
        'tenRap': tenRap,
        'tenPhong': tenPhong,
        'gioChieu': gioChieu == null ? null : Timestamp.fromDate(gioChieu!),
        'uid': uid,
      };
}

/// Collection: thanhToan
class ThanhToan {
  final String thanhToanId;
  final String donId;
  final String phuongThuc;
  final num soTien;
  final String trangThai;
  final String maGiaoDich;
  final DateTime? thoiGian;

  const ThanhToan({
    required this.thanhToanId,
    required this.donId,
    required this.phuongThuc,
    required this.soTien,
    required this.trangThai,
    this.maGiaoDich = '',
    this.thoiGian,
  });

  factory ThanhToan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ThanhToan(
      thanhToanId: d.id,
      donId: m['donId'] ?? '',
      phuongThuc: m['phuongThuc'] ?? '',
      soTien: m['soTien'] ?? 0,
      trangThai: m['trangThai'] ?? TrangThaiThanhToan.dangXuLy,
      maGiaoDich: m['maGiaoDich'] ?? '',
      thoiGian: (m['thoiGian'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'donId': donId,
        'phuongThuc': phuongThuc,
        'soTien': soTien,
        'trangThai': trangThai,
        'maGiaoDich': maGiaoDich,
        'thoiGian': FieldValue.serverTimestamp(),
      };
}

/// Collection: huyDoiVe
class HuyDoiVe {
  final String id;
  final String veId;
  final String loai; // 'huy' | 'doi'
  final String lyDo;
  final num soTienHoan;
  final num soTienThuThem;
  final String? suatMoiId;
  final String? gheMoiId;
  final String trangThai;
  final DateTime? thoiGian;

  const HuyDoiVe({
    required this.id,
    required this.veId,
    required this.loai,
    this.lyDo = '',
    this.soTienHoan = 0,
    this.soTienThuThem = 0,
    this.suatMoiId,
    this.gheMoiId,
    this.trangThai = 'hoanTat',
    this.thoiGian,
  });

  factory HuyDoiVe.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return HuyDoiVe(
      id: d.id,
      veId: m['veId'] ?? '',
      loai: m['loai'] ?? 'huy',
      lyDo: m['lyDo'] ?? '',
      soTienHoan: m['soTienHoan'] ?? 0,
      soTienThuThem: m['soTienThuThem'] ?? 0,
      suatMoiId: m['suatMoiId'],
      gheMoiId: m['gheMoiId'],
      trangThai: m['trangThai'] ?? 'hoanTat',
      thoiGian: (m['thoiGian'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'veId': veId,
        'loai': loai,
        'lyDo': lyDo,
        'soTienHoan': soTienHoan,
        'soTienThuThem': soTienThuThem,
        'suatMoiId': suatMoiId,
        'gheMoiId': gheMoiId,
        'trangThai': trangThai,
        'thoiGian': FieldValue.serverTimestamp(),
      };
}
