import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// Collection: rap
class Rap {
  final String rapId;
  final String tenRap;
  final String diaChi;
  final GeoPoint? viTri;
  final String soDienThoai;
  final String trangThai; // 'hoatDong' | 'tamNgung'

  const Rap({
    required this.rapId,
    required this.tenRap,
    this.diaChi = '',
    this.viTri,
    this.soDienThoai = '',
    this.trangThai = 'hoatDong',
  });

  bool get dangHoatDong => trangThai == 'hoatDong';

  factory Rap.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Rap(
      rapId: d.id,
      tenRap: m['tenRap'] ?? '',
      diaChi: m['diaChi'] ?? '',
      viTri: m['viTri'] as GeoPoint?,
      soDienThoai: m['soDienThoai'] ?? '',
      trangThai: m['trangThai'] ?? 'hoatDong',
    );
  }

  Map<String, dynamic> toMap() => {
        'tenRap': tenRap,
        'diaChi': diaChi,
        'viTri': viTri,
        'soDienThoai': soDienThoai,
        'trangThai': trangThai,
      };
}

/// Subcollection: rap/{rapId}/phongChieu
class PhongChieu {
  final String phongId;
  final String rapId; // denormalize
  final String tenPhong;
  final String loaiPhong; // 2D | 3D | IMAX
  final int soLuongGhe;

  const PhongChieu({
    required this.phongId,
    required this.rapId,
    required this.tenPhong,
    this.loaiPhong = '2D',
    this.soLuongGhe = 0,
  });

  factory PhongChieu.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return PhongChieu(
      phongId: d.id,
      rapId: m['rapId'] ?? '',
      tenPhong: m['tenPhong'] ?? '',
      loaiPhong: m['loaiPhong'] ?? '2D',
      soLuongGhe: (m['soLuongGhe'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'rapId': rapId,
        'tenPhong': tenPhong,
        'loaiPhong': loaiPhong,
        'soLuongGhe': soLuongGhe,
      };
}

/// Subcollection: rap/{rapId}/phongChieu/{phongId}/ghe
class Ghe {
  final String gheId;
  final String phongId;
  final String hang; // A, B, C...
  final int so;
  final String loaiGhe;

  const Ghe({
    required this.gheId,
    required this.phongId,
    required this.hang,
    required this.so,
    this.loaiGhe = LoaiGhe.thuong,
  });

  String get ten => '$hang$so';

  factory Ghe.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Ghe(
      gheId: d.id,
      phongId: m['phongId'] ?? '',
      hang: m['hang'] ?? '',
      so: (m['so'] ?? 0).toInt(),
      loaiGhe: m['loaiGhe'] ?? LoaiGhe.thuong,
    );
  }

  Map<String, dynamic> toMap() =>
      {'phongId': phongId, 'hang': hang, 'so': so, 'loaiGhe': loaiGhe};
}
