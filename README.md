# CineTicket — Hệ thống đặt vé xem phim (Flutter + Firebase)

Sản phẩm được xây dựng bám sát hai tài liệu của đồ án: **Thiết kế CSDL (15 collection Firestore)** và **Phân tích Use Case (23 UC + 18 yêu cầu phi chức năng)**.

## 1. Chạy thử

```bash
flutter pub get

# Cấu hình Firebase (sinh lại lib/firebase_options.dart)
dart pub global activate flutterfire_cli
flutterfire configure

# Bật Authentication > Email/Password và tạo Firestore database trên Firebase Console
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm install && cd .. && firebase deploy --only functions

# Dữ liệu mẫu (tải serviceAccountKey.json từ Project settings > Service accounts)
node tool/seed.js serviceAccountKey.json

flutter run -d chrome
```

Tạo tài khoản admin: đăng ký bình thường trên web, sau đó vào Firestore sửa `users/{uid}.vaiTro` thành `admin`.

## 2. Cấu trúc mã nguồn

```
lib/
├── core/           constants.dart (tên collection + enum nghiệp vụ), utils.dart, theme.dart
├── models/         15 collection -> 6 file model (fromDoc / toMap thủ công)
├── services/       toàn bộ nghiệp vụ, mỗi service ứng với một nhóm use case
├── providers/      AuthProvider (phiên đăng nhập), BookingProvider (giỏ ghế + đồng hồ giữ ghế)
├── screens/        giao diện khách hàng và khu vực quản trị
├── app.dart        định tuyến go_router + chặn truy cập theo vai trò
└── main.dart
functions/index.js  dọn ghế giữ quá hạn, cập nhật suất hết vé
firestore.rules     phân quyền admin/khách hàng
tool/seed.js        dữ liệu mẫu
```

## 3. Ánh xạ Use Case → mã nguồn

| Use case | Xử lý nghiệp vụ | Giao diện |
|---|---|---|
| UC-DKDN (UC-SI-01, UC-LG-02) | `services/auth_service.dart` | `screens/auth/` |
| UC-XDSP, UC-XTTP, UC-TK | `services/phim_service.dart` | `screens/home/`, `screens/phim/` |
| UC-XLC, UC-CSC, UC-QLSC | `services/suat_chieu_service.dart` | `screens/phim/phim_detail_screen.dart`, `screens/admin/quan_ly_suat_chieu.dart` |
| UC-CR, UC-QLRPC, UC-QLG | `services/rap_service.dart` | `screens/admin/quan_ly_rap.dart` |
| UC-CC, UC-DV (UC-BT-04) | `services/dat_ve_service.dart` | `screens/booking/so_do_ghe_screen.dart` |
| UC-TT, UC-PHV | `dat_ve_service.xacNhanThanhToan()` + `thanh_toan_service.dart` | `screens/booking/thanh_toan_screen.dart` |
| UC-XLSDV | `dat_ve_service.lichSuDon()`, `ve_service.veCuaToi()` | `screens/ve/ve_cua_toi_screen.dart` |
| UC-HDV (UC-HDV-06) | `ve_service.huyVe()`, `ve_service.doiVe()` | `screens/ve/ve_detail_screen.dart`, `doi_ve_screen.dart` |
| UC-TV | `services/thanh_vien_service.dart` | tab "Thẻ thành viên" |
| UC-QLGV | `services/gia_ve_service.dart` | `screens/admin/quan_ly_rap.dart` (tab Giá vé) |
| UC-QLDDV, UC-QLKH | `dat_ve_service.tatCaDon()`, `auth_service.danhSachKhachHang()` | `screens/admin/quan_ly_don.dart` |
| UC-QLP | `services/phim_service.dart` | `screens/admin/quan_ly_phim.dart` |
| UC-PC (UC-PC-09) | `services/chat_service.dart` | `screens/chat/phong_chat_screen.dart` |
| UC-DVI (UC-DVI-10) | `services/vi_tri_service.dart` | `screens/rap/rap_gan_day_screen.dart` |

## 4. Cách các yêu cầu phi chức năng được đáp ứng

- **NFR #8 — không hai khách cùng đặt một ghế**: mọi thao tác ghế chạy trong `runTransaction`. Chọn ghế = tạo bản ghi `ghe_suat_chieu/{suatId}_{gheId}` trạng thái `dangGiu` kèm `uidGiu` + `thoiGianGiu`; thanh toán chỉ thành công nếu ghế **vẫn** do chính người đó giữ và chưa quá hạn.
- **Giữ chỗ 10 phút**: `QuyDinh.phutGiuGhe`, đồng hồ đếm ngược trong `BookingProvider`, Cloud Function `donGheGiuQuaHan` chạy mỗi 2 phút trả ghế về trống và hủy đơn treo.
- **NFR #9 — thanh toán thất bại không phát hành vé giả**: vé chỉ được tạo bên trong transaction sau khi cổng trả về thành công; thất bại thì ghi bản ghi `thanhToan` trạng thái `thatBai` và giữ nguyên đơn để khách thử lại.
- **NFR #5, #6, #7 — bảo mật**: mật khẩu do Firebase Auth băm; `firestore.rules` chặn khách hàng đọc đơn/vé của người khác và chặn ghi vào danh mục nếu không phải admin; route `/admin` được chặn ở `app.dart`.
- **NFR #11 — responsive**: `KhungWeb` giới hạn bề rộng, lưới phim tự tính số cột theo `LayoutBuilder`.
- **NFR #16 — audit**: `thanhToan` và `huyDoiVe` lưu lại mọi giao dịch, hủy, đổi kèm mốc thời gian.
- **NFR #17 — tính tiền chính xác**: `gia_ve_service.dart` tra bảng `giaVe` theo (loại ghế, loại ngày, khung giờ), có đường lùi về giá cơ bản × hệ số loại ghế.

## 5. Phần cần hoàn thiện thêm trước khi bảo vệ

1. **Cổng thanh toán thật**: `services/thanh_toan_service.dart` hiện là mock (10% giao dịch thất bại để test luồng ngoại lệ). Thay bằng VNPay/Momo sandbox — chỉ cần sửa thân hàm `thanhToan`, phần còn lại giữ nguyên.
2. **Soát vé bằng camera**: `ve_service.kiemTraMaQR()` đã sẵn sàng, cần thêm màn hình quét (gói `mobile_scanner`).
3. **Ảnh poster / ảnh trong chat**: dùng Firebase Storage rồi lưu URL vào `phim.poster` và `tinNhan.hinhAnhUrl`.
4. **Đẩy phần chốt vé sang Cloud Function** nếu muốn siết bảo mật tối đa (rules hiện đã chặn khách ghi đè ghế người khác, nhưng logic chạy ở client).
