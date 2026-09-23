/// Tên collection trong Firestore — khớp tài liệu Thiết kế CSDL.
class Col {
  static const users = 'users';
  static const theThanhVien = 'theThanhVien'; // users/{uid}/theThanhVien/info
  static const rap = 'rap';
  static const phongChieu = 'phongChieu';     // rap/{rapId}/phongChieu
  static const ghe = 'ghe';                   // phongChieu/{phongId}/ghe
  static const phim = 'phim';
  static const suatChieu = 'suatChieu';
  static const gheSuatChieu = 'ghe_suat_chieu';
  static const giaVe = 'giaVe';
  static const donDatVe = 'donDatVe';
  static const ve = 've';                     // donDatVe/{donId}/ve
  static const thanhToan = 'thanhToan';
  static const huyDoiVe = 'huyDoiVe';
  static const phongChat = 'phongChat';
  static const tinNhan = 'tinNhan';           // phongChat/{suatId}/tinNhan
}

class VaiTro {
  static const khachHang = 'customer';
  static const admin = 'admin';
}

class TrangThaiTaiKhoan {
  static const active = 'active';
  static const locked = 'locked';
}

class HangThanhVien {
  static const bronze = 'bronze';
  static const silver = 'silver';
  static const gold = 'gold';

  /// Quy đổi điểm tích lũy sang hạng thẻ
  static String tuDiem(int diem) {
    if (diem >= 5000) return gold;
    if (diem >= 2000) return silver;
    return bronze;
  }

  /// % giảm giá theo hạng thẻ (UC-TV)
  static double giamGia(String hang) =>
      switch (hang) { gold => 0.10, silver => 0.05, _ => 0.0 };
}

class TrangThaiPhim {
  static const dangChieu = 'dangChieu';
  static const sapChieu = 'sapChieu';
  static const ngungChieu = 'ngungChieu';
  static String nhan(String v) => switch (v) {
        dangChieu => 'Đang chiếu',
        sapChieu => 'Sắp chiếu',
        _ => 'Ngừng chiếu',
      };
}

class TrangThaiSuat {
  static const conSuat = 'conSuat';
  static const hetVe = 'hetVe';
  static const daHuy = 'daHuy';
}

class TrangThaiGhe {
  static const trong = 'trong';
  static const dangGiu = 'dangGiu';
  static const daDat = 'daDat';
}

class LoaiGhe {
  static const thuong = 'Thuong';
  static const vip = 'VIP';
  static const doi = 'Doi';
  static const all = [thuong, vip, doi];

  static String nhan(String v) =>
      switch (v) { vip => 'VIP', doi => 'Ghế đôi', _ => 'Thường' };

  /// Hệ số giá dùng khi không có bản ghi tương ứng trong bảng giaVe
  static double heSo(String loai) =>
      switch (loai) { vip => 1.3, doi => 1.8, _ => 1.0 };
}

class TrangThaiDon {
  static const choThanhToan = 'choThanhToan';
  static const daThanhToan = 'daThanhToan';
  static const daHuy = 'daHuy';
  static const daDoi = 'daDoi';
}

class TrangThaiVe {
  static const hopLe = 'hopLe';
  static const daDung = 'daDung';
  static const daHuy = 'daHuy';
  static const daDoi = 'daDoi';
}

class TrangThaiThanhToan {
  static const thanhCong = 'thanhCong';
  static const thatBai = 'thatBai';
  static const dangXuLy = 'dangXuLy';
}

class PhuongThucThanhToan {
  static const the = 'The';
  static const momo = 'Momo';
  static const qr = 'QR';
  static const all = [the, momo, qr];
  static String nhan(String v) => switch (v) {
        the => 'Thẻ ngân hàng',
        momo => 'Ví Momo',
        _ => 'Quét mã QR',
      };
}

/// Quy tắc nghiệp vụ (NFR #8, #9 và UC-HDV)
class QuyDinh {
  /// Thời gian giữ ghế tối đa trước khi tự nhả (phút)
  static const phutGiuGhe = 10;

  /// Chỉ cho hủy/đổi vé nếu còn ít nhất N giờ trước suất chiếu
  static const gioToiThieuTruocSuat = 2;

  /// Phí hủy vé (% tổng tiền vé)
  static const phiHuyVe = 0.10;

  /// 1 điểm tích lũy cho mỗi 1.000đ chi tiêu
  static const donViTichDiem = 1000;

  /// Bán kính tìm rạp gần (km) — UC-DVI
  static const banKinhTimRapKm = 30.0;
}
