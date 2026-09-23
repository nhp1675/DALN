import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/rap.dart';
import 'rap_service.dart';

class RapGanDay {
  final Rap rap;
  final double khoangCach; // km
  const RapGanDay(this.rap, this.khoangCach);
}

/// UC-DVI — Định vị rạp chiếu phim gần vị trí hiện tại
class ViTriService {
  final _rapService = RapService();

  /// Bước 2, 3, 4: xin quyền và lấy vị trí hiện tại
  Future<Position> viTriHienTai() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Dịch vụ định vị đang tắt. Vui lòng bật để tìm rạp gần bạn.');
    }
    var quyen = await Geolocator.checkPermission();
    if (quyen == LocationPermission.denied) {
      quyen = await Geolocator.requestPermission();
    }
    if (quyen == LocationPermission.denied) {
      throw Exception('Không thể xác định vị trí hiện tại.');
    }
    if (quyen == LocationPermission.deniedForever) {
      throw Exception('Quyền truy cập vị trí đã bị từ chối vĩnh viễn, hãy bật lại trong cài đặt trình duyệt.');
    }
    return Geolocator.getCurrentPosition();
  }

  /// Bước 5, 6, 7: lấy rạp đang hoạt động, sắp xếp theo khoảng cách
  Future<List<RapGanDay>> timRapGan({double? banKinhKm}) async {
    final vt = await viTriHienTai();
    final ds = await _rapService.layRapHoatDong();
    final kq = <RapGanDay>[];
    for (final r in ds) {
      if (r.viTri == null) continue;
      final d = khoangCachKm(vt.latitude, vt.longitude, r.viTri!.latitude, r.viTri!.longitude);
      if (banKinhKm == null || d <= banKinhKm) kq.add(RapGanDay(r, d));
    }
    kq.sort((a, b) => a.khoangCach.compareTo(b.khoangCach));
    if (kq.isEmpty) {
      throw Exception('Không tìm thấy rạp chiếu phim gần vị trí của bạn.');
    }
    return kq;
  }

  /// Bước 10, 11: mở bản đồ chỉ đường
  Future<void> moChiDuong(Rap rap) async {
    if (rap.viTri == null) throw Exception('Rạp chưa có tọa độ trên bản đồ.');
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${rap.viTri!.latitude},${rap.viTri!.longitude}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Không mở được ứng dụng bản đồ. Địa chỉ rạp: ${rap.diaChi}');
    }
  }

  static double get banKinhMacDinh => QuyDinh.banKinhTimRapKm;
}
