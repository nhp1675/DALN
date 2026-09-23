import 'dart:math';
import 'package:intl/intl.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

String dinhDangTien(num v) => _vnd.format(v);
String dinhDangNgay(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String dinhDangGio(DateTime d) => DateFormat('HH:mm').format(d);
String dinhDangNgayGio(DateTime d) => DateFormat('HH:mm dd/MM/yyyy').format(d);
String maNgay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Phân loại ngày để tra bảng giaVe.loaiNgay
String loaiNgay(DateTime d) =>
    (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
        ? 'CuoiTuan'
        : 'NgayThuong';

/// Phân loại khung giờ để tra bảng giaVe.khungGio
String khungGio(DateTime d) => d.hour < 17 ? 'Sang' : 'Toi';

/// Khoảng cách Haversine (km) — phục vụ UC-DVI
double khoangCachKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double x) => x * pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String maQRNgauNhien() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
}
