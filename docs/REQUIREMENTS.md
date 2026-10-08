# Đối chiếu 23 use case trong báo cáo

“Đã viết” trong bảng là trạng thái mã nguồn, không có nghĩa đã vượt qua kiểm thử MongoDB. Các giới hạn xác minh nằm trong TEST-RESULTS.md.

| Use case | Triển khai |
| --- | --- |
| UC-DKDN | Đã viết đăng ký, đăng nhập, logout, sửa hồ sơ, đổi mật khẩu; quyền admin/customer |
| UC-XDSP | Trang chủ phim đang/sắp chiếu |
| UC-XTTP | Chi tiết tên, thời lượng, thể loại, nội dung, đạo diễn, diễn viên, tuổi |
| UC-XLC | Lịch chiếu theo phim/rạp/ngày |
| UC-CR | Bộ lọc rạp và trang hệ thống rạp |
| UC-CSC | Chọn suất chiếu tương lai đang hoạt động |
| UC-CC | Sơ đồ ghế, chọn/bỏ, trạng thái available/held/booked, cập nhật 8 giây |
| UC-DV | Order + OrderItem, giữ ghế và kiểm tra giá server |
| UC-TT | Mô phỏng thành công/thất bại/retry; tích hợp cổng thật còn thiếu |
| UC-XLSDV | Lịch sử đơn, vé, trạng thái và khoản hoàn |
| UC-QLP | Thêm/sửa/ẩn phim; bảo vệ lịch chiếu đang có |
| UC-QLRPC | Rạp và phòng, bảo vệ dữ liệu đã có lịch |
| UC-QLG | Sinh sơ đồ thường/VIP, sửa loại/trạng thái ghế trước khi lên lịch |
| UC-QLSC | CRUD có điều kiện, tránh trùng lịch và 15 phút dọn phòng |
| UC-QLGV | Giá thường/VIP theo suất, snapshot trên ShowtimeSeat và OrderItem; chưa có biểu giá tự động ngày lễ |
| UC-QLDDV | Theo dõi đơn, thu/hoàn; không có API sửa trạng thái thanh toán tùy ý |
| UC-QLKH | Xem khách, khóa/mở, thu hồi phiên khi khóa |
| UC-HDV | Hủy/đổi từng vé theo policy snapshot, chênh giá, refund mô phỏng |
| UC-TV | Hồ sơ thành viên và điểm ròng; chưa có chương trình sử dụng ưu đãi do thiếu chính sách |
| UC-TK | Tìm phim theo tên và thể loại |
| UC-PHV | Tự tạo QR ngẫu nhiên riêng mỗi ghế sau xác nhận thanh toán mô phỏng; bổ sung admin soát QR |
| UC-PC | Chủ động vào/rời, kiểm tra vé cùng suất, tin nhắn chữ, không upload ảnh |
| UC-DVI | Browser geolocation, tính khoảng cách local, bán kính/thành phố, Google Maps chỉ đường |

Các giả định phải xác nhận trước vận hành thật: 10 phút giữ ghế; 8 ghế/đơn; 3 đơn giữ/khách; hủy/đổi trước 24 giờ; hoàn 100%; đổi cùng phim có thể khác rạp; 1 điểm/10.000 VND; chat đóng cuối suất. Các cấu hình dễ thay đổi nằm trong `.env`; quy tắc khác ghi rõ trong service để nhóm dự án điều chỉnh có kiểm thử.
