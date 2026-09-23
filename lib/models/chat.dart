import 'package:cloud_firestore/cloud_firestore.dart';

/// Collection: phongChat — docId = suatId (1-1 với suất chiếu)
class PhongChat {
  final String suatId;
  final List<String> danhSachThanhVien;
  final DateTime? ngayTao;
  final String tenPhim;
  final DateTime? gioChieu;

  const PhongChat({
    required this.suatId,
    this.danhSachThanhVien = const [],
    this.ngayTao,
    this.tenPhim = '',
    this.gioChieu,
  });

  factory PhongChat.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return PhongChat(
      suatId: d.id,
      danhSachThanhVien: List<String>.from(m['danhSachThanhVien'] ?? const []),
      ngayTao: (m['ngayTao'] as Timestamp?)?.toDate(),
      tenPhim: m['tenPhim'] ?? '',
      gioChieu: (m['gioChieu'] as Timestamp?)?.toDate(),
    );
  }
}

/// Subcollection: phongChat/{suatId}/tinNhan
class TinNhan {
  final String tinNhanId;
  final String uid;
  final String hoTen; // denormalize để hiển thị
  final String noiDung;
  final String? hinhAnhUrl;
  final DateTime? thoiGian;

  const TinNhan({
    required this.tinNhanId,
    required this.uid,
    required this.noiDung,
    this.hoTen = '',
    this.hinhAnhUrl,
    this.thoiGian,
  });

  factory TinNhan.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return TinNhan(
      tinNhanId: d.id,
      uid: m['uid'] ?? '',
      hoTen: m['hoTen'] ?? '',
      noiDung: m['noiDung'] ?? '',
      hinhAnhUrl: m['hinhAnhUrl'],
      thoiGian: (m['thoiGian'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'hoTen': hoTen,
        'noiDung': noiDung,
        'hinhAnhUrl': hinhAnhUrl,
        'thoiGian': FieldValue.serverTimestamp(),
      };
}
