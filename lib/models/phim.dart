import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// Collection: phim
class Phim {
  final String phimId;
  final String tenPhim;
  final List<String> theLoai;
  final int thoiLuong; // phút
  final String noiDung;
  final String daoDien;
  final List<String> dienVien;
  final String doTuoi; // VD: T16
  final String poster;
  final String trailerUrl;
  final String trangThai;

  const Phim({
    required this.phimId,
    required this.tenPhim,
    this.theLoai = const [],
    this.thoiLuong = 0,
    this.noiDung = '',
    this.daoDien = '',
    this.dienVien = const [],
    this.doTuoi = '',
    this.poster = '',
    this.trailerUrl = '',
    this.trangThai = TrangThaiPhim.dangChieu,
  });

  /// Dùng cho UC-TK (tìm kiếm không dấu phân biệt hoa thường phía client)
  String get khoaTimKiem =>
      '${tenPhim.toLowerCase()} ${theLoai.join(' ').toLowerCase()} ${daoDien.toLowerCase()}';

  factory Phim.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Phim(
      phimId: d.id,
      tenPhim: m['tenPhim'] ?? '',
      theLoai: List<String>.from(m['theLoai'] ?? const []),
      thoiLuong: (m['thoiLuong'] ?? 0).toInt(),
      noiDung: m['noiDung'] ?? '',
      daoDien: m['daoDien'] ?? '',
      dienVien: List<String>.from(m['dienVien'] ?? const []),
      doTuoi: m['doTuoi'] ?? '',
      poster: m['poster'] ?? '',
      trailerUrl: m['trailerUrl'] ?? '',
      trangThai: m['trangThai'] ?? TrangThaiPhim.dangChieu,
    );
  }

  Map<String, dynamic> toMap() => {
        'tenPhim': tenPhim,
        'theLoai': theLoai,
        'thoiLuong': thoiLuong,
        'noiDung': noiDung,
        'daoDien': daoDien,
        'dienVien': dienVien,
        'doTuoi': doTuoi,
        'poster': poster,
        'trailerUrl': trailerUrl,
        'trangThai': trangThai,
      };

  Phim copyWith({String? tenPhim, List<String>? theLoai, int? thoiLuong, String? noiDung,
          String? daoDien, List<String>? dienVien, String? doTuoi, String? poster,
          String? trailerUrl, String? trangThai}) =>
      Phim(
        phimId: phimId,
        tenPhim: tenPhim ?? this.tenPhim,
        theLoai: theLoai ?? this.theLoai,
        thoiLuong: thoiLuong ?? this.thoiLuong,
        noiDung: noiDung ?? this.noiDung,
        daoDien: daoDien ?? this.daoDien,
        dienVien: dienVien ?? this.dienVien,
        doTuoi: doTuoi ?? this.doTuoi,
        poster: poster ?? this.poster,
        trailerUrl: trailerUrl ?? this.trailerUrl,
        trangThai: trangThai ?? this.trangThai,
      );
}
