# Kết quả kiểm thử bản Flutter — 04/10/2026

## Đã thực hiện

| Kiểm tra | Kết quả | Phạm vi |
| --- | --- | --- |
| Flutter 3.41.4 / Dart 3.11.1 analyze | Không có vấn đề | Mã frontend và widget tests |
| Flutter test | 5/5 đạt | Haversine, API CSRF/lỗi, catalog, chọn/bỏ ghế trên mobile, demo fail/retry/QR, biểu mẫu admin |
| Flutter build web --release --csp --no-web-resources-cdn | Đạt | Biên dịch release Flutter Web với CanvasKit cục bộ |
| npm run test:unit | 8/8 đạt | Scrypt/salt, Origin/CSRF, role, headers, xác thực, validation chống object injection và tự cấp role, schema/index, CORS đúng origin |
| npm run test:ui | 2/2 đạt | Chromium: catalog release và CSP, sơ đồ ghế 390px, biểu mẫu admin; API fixtures |
| Kiểm tra ảnh render | Đã xem | Trang chủ desktop, sơ đồ ghế mobile, hộp thoại quản trị |
| npm audit | 0 lỗ hổng được báo cáo | 153 dependencies npm tại thời điểm chạy; không kiểm chứng logic nghiệp vụ hay dependency Dart |

Lỗi đã sửa khi kiểm tra browser: font trong poster SVG không khớp font đã đóng gói và ký tự dấu tích thiếu glyph. Poster nay dùng Roboto cục bộ, dấu tích dùng Material Icon; trang chủ không còn lỗi CSP/font ngoài.

## Chưa xác nhận

**Integration MongoDB: bị chặn, không phải đã đạt.** Binary MongoDB 7.0.24 tải được nhưng môi trường thực thi từ chối khởi động với lỗi `std::exception ... open: Operation not permitted` và exit code 100. Vì hook khởi tạo database thất bại, 9 bài integration không chạy đến nghiệp vụ. Không dùng kết quả giao diện giả lập để tuyên bố backend hoạt động đúng với MongoDB.

Các bài đã viết trong `tests/integration.test.js`, cần chạy trên máy hỗ trợ MongoDB:

1. Origin, CSRF, quyền admin, NoSQL object, tự nâng quyền.
2. Hai khách giữ cùng một ghế đồng thời, chỉ một thành công.
3. Chặn truy cập đơn của người khác; thanh toán lỗi không tạo vé.
4. Hai request thanh toán đồng thời không tạo vé/thu tiền lặp.
5. Đổi vé lỗi giữ vé cũ; thành công thu chênh, thay QR và trả ghế cũ.
6. Chat yêu cầu vé và membership; hủy vé thu hồi chat và hoàn đúng một lần.
7. Hold hết hạn không thể thanh toán, ghế được giải phóng.
8. Giá tính tại server, idempotency mismatch bị chặn, lịch trùng và xóa suất đã bán bị chặn.
9. Logout thu hồi phiên.

Các kiểm tra chưa thực hiện: Docker Compose trên Windows, Atlas, nhà cung cấp thanh toán thật, email/SMS, tải cao, HA nhiều node, backup/restore thực tế, kiểm toán bảo mật/pentest độc lập, kiểm tra accessibility toàn diện.

## Chạy lại

Xem lệnh ở README.md. Flutter widget tests và browser tests dùng API giả lập. Chúng không chứng minh transaction, thanh toán hay chống đặt trùng trong MongoDB đã chạy đúng. Hình trong docs/screenshots được chụp từ bản Flutter release với fixtures. Không có kết quả kiểm thử React được tính cho bản Flutter này.
