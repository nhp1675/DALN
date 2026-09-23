import 'dart:math';
import '../core/constants.dart';

class KetQuaThanhToan {
  final bool thanhCong;
  final String maGiaoDich;
  final String? thongBaoLoi;
  const KetQuaThanhToan(this.thanhCong, this.maGiaoDich, {this.thongBaoLoi});
}

/// UC-TT — Cổng thanh toán.
///
/// Đây là lớp giả lập (mock) để chạy được đồ án mà không cần merchant thật.
/// Khi tích hợp VNPay/Momo thật, chỉ cần thay phần thân [thanhToan] bằng lời
/// gọi tạo URL thanh toán + xử lý callback, phần còn lại của hệ thống giữ nguyên.
class ThanhToanService {
  final _rnd = Random();

  Future<KetQuaThanhToan> thanhToan({
    required String donId,
    required num soTien,
    required String phuongThuc,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // mô phỏng gọi cổng
    final ma = 'TX${DateTime.now().millisecondsSinceEpoch}';

    // 10% giao dịch thất bại để kiểm thử luồng ngoại lệ (NFR #9)
    final thatBai = _rnd.nextInt(10) == 0;
    if (thatBai) {
      return KetQuaThanhToan(false, ma,
          thongBaoLoi: 'Giao dịch bị từ chối bởi ${PhuongThucThanhToan.nhan(phuongThuc)}.');
    }
    return KetQuaThanhToan(true, ma);
  }

  /// Hoàn tiền khi hủy vé (UC-HDV)
  Future<KetQuaThanhToan> hoanTien({required String donId, required num soTien}) async {
    await Future.delayed(const Duration(seconds: 1));
    return KetQuaThanhToan(true, 'RF${DateTime.now().millisecondsSinceEpoch}');
  }
}
