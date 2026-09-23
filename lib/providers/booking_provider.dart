import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/rap.dart';
import '../models/suat_chieu.dart';
import '../services/dat_ve_service.dart';
import '../services/gia_ve_service.dart';

/// Giỏ ghế đang chọn cho 1 suất chiếu (UC-CC, UC-DV).
/// Giữ cả đồng hồ đếm ngược thời gian giữ ghế.
class BookingProvider extends ChangeNotifier {
  final _datVe = DatVeService();
  final _giaVe = GiaVeService();

  SuatChieu? suat;
  final List<Ghe> _dangChon = [];
  final Map<String, num> _gia = {};
  double _giamGiaThanhVien = 0;
  Timer? _dongHo;
  Duration _conLai = Duration.zero;
  String? donId;

  List<Ghe> get dangChon => List.unmodifiable(_dangChon);
  Map<String, num> get giaTheoGhe => Map.unmodifiable(_gia);
  Duration get conLai => _conLai;
  bool get dangGiuGhe => _dongHo?.isActive ?? false;

  num get tamTinh => _dangChon.fold<num>(0, (t, g) => t + (_gia[g.gheId] ?? 0));
  num get tongTien => (tamTinh * (1 - _giamGiaThanhVien)).round();
  num get tienGiam => tamTinh - tongTien;
  double get phanTramGiam => _giamGiaThanhVien;

  void batDauSuat(SuatChieu s, {double giamGiaThanhVien = 0}) {
    if (suat?.suatId != s.suatId) {
      _dangChon.clear();
      _gia.clear();
      donId = null;
    }
    suat = s;
    _giamGiaThanhVien = giamGiaThanhVien;
    notifyListeners();
  }

  bool daChon(String gheId) => _dangChon.any((e) => e.gheId == gheId);

  /// Chọn / bỏ chọn ghế — có giữ chỗ trên Firestore để tránh trùng (NFR #8)
  Future<void> chonGhe(Ghe ghe, String uid) async {
    if (suat == null) return;
    if (daChon(ghe.gheId)) {
      await _datVe.nhaGhe(suatId: suat!.suatId, gheIds: [ghe.gheId], uid: uid);
      _dangChon.removeWhere((e) => e.gheId == ghe.gheId);
      _gia.remove(ghe.gheId);
      if (_dangChon.isEmpty) _dungDongHo();
    } else {
      await _datVe.giuGhe(suatId: suat!.suatId, gheIds: [ghe.gheId], uid: uid);
      _dangChon.add(ghe);
      _gia[ghe.gheId] = await _giaVe.giaMotGhe(suat!, ghe);
      _khoiDongDongHo();
    }
    notifyListeners();
  }

  void _khoiDongDongHo() {
    _dongHo?.cancel();
    _conLai = const Duration(minutes: QuyDinh.phutGiuGhe);
    _dongHo = Timer.periodic(const Duration(seconds: 1), (t) {
      _conLai -= const Duration(seconds: 1);
      if (_conLai.isNegative || _conLai == Duration.zero) {
        t.cancel();
        _conLai = Duration.zero;
      }
      notifyListeners();
    });
  }

  void _dungDongHo() {
    _dongHo?.cancel();
    _conLai = Duration.zero;
  }

  /// Hủy quá trình đặt vé: nhả toàn bộ ghế đang giữ
  Future<void> huyBo(String uid) async {
    if (suat != null && _dangChon.isNotEmpty) {
      await _datVe.nhaGhe(
          suatId: suat!.suatId, gheIds: _dangChon.map((e) => e.gheId).toList(), uid: uid);
    }
    xoaHet();
  }

  void xoaHet() {
    _dangChon.clear();
    _gia.clear();
    donId = null;
    _dungDongHo();
    notifyListeners();
  }

  @override
  void dispose() {
    _dongHo?.cancel();
    super.dispose();
  }
}
