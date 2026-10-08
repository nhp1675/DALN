# Bảo mật và giới hạn vận hành

Không phần mềm nào có thể được cam kết “không có lỗ hổng”. Bản này có các cơ chế phòng vệ cụ thể và bộ kiểm thử, nhưng chưa được pentest độc lập, chưa kiểm thử tải hoặc kiểm thử với cổng thanh toán thực. Không gọi đây là bản production-ready.

## Biện pháp trong mã nguồn

- Mật khẩu scrypt với salt ngẫu nhiên 16 byte, N=32768, r=8, p=1, output 64 byte; so sánh timing-safe. Mật khẩu 12–128 ký tự khi tạo/đổi.
- Session ngẫu nhiên 32 byte; database chỉ lưu HMAC token. Cookie HttpOnly, SameSite=Strict, Secure khi production, thời hạn 8 giờ. Logout xóa phiên server; đổi mật khẩu/khóa khách thu hồi phiên.
- Kiểm tra Origin trên mọi thao tác thay đổi. Phiên đăng nhập phải có CSRF token riêng. Bản build gọi API cùng origin; chế độ phát triển chỉ cho CORS đúng APP_ORIGIN với credentials, không mở CORS `*`.
- Rate limit IP toàn API và đăng nhập; rate limit theo user cho hold/chat. Mỗi khách tối đa 3 đơn chờ còn hạn, kiểm tra trong transaction.
- Zod strict schema, ID hợp lệ, giới hạn body 16 KB; không đưa object đầu vào trực tiếp vào MongoDB filter/update. Regex tìm kiếm được escape, giới hạn 100 ký tự.
- Phân quyền server cho mọi admin API; API vé/đơn giới hạn userId hiện tại. Không có API tự tăng role. Danh sách khách loại passwordHash.
- Giá, tổng tiền, chênh lệch, hoàn tiền và điểm tính ở backend. Client không được gửi giá mua tùy ý.
- Transaction và unique indexes cho `(showtime, seat)`, `(user, idempotencyKey)`, QR, chi tiết vé, thành viên chat; các bản ghi revision dùng để tránh race condition.
- Helmet CSP, chống MIME sniffing, không cho nhúng iframe, xóa X-Powered-By. Nội dung tin nhắn/tên phim render bằng widget Flutter Text, không chèn HTML. Ảnh remote chỉ cho HTTPS; không backend fetch URL người dùng.
- Audit trong transaction cho thanh toán, hold, hủy/đổi, lịch và soát vé. Không log password, session token hoặc URI DB. QR chỉ gửi đến chủ vé; không dùng query string công khai.
- Vị trí người dùng tính trên máy và không lưu DB. Liên kết chỉ đường gửi tọa độ rạp cho Google Maps; dịch vụ bản đồ có chính sách riêng.
- `.env` và thông tin DB không được đóng gói hoặc commit. Local setup tự tạo secrets ngẫu nhiên, MongoDB có auth và chỉ bind cổng host 127.0.0.1. Tài khoản app chỉ có readWrite database cinego.

## Các việc bắt buộc trước khi nhận tiền thật

1. **Tích hợp nhà cung cấp thật**: hiện PAYMENT_MODE chỉ nhận `demo` hoặc `disabled`. Cần triển khai adapter và bộ kiểm thử sandbox trước khi thêm mode thật. Xác thực chữ ký webhook, merchant, currency, amount, reference; dùng dữ liệu server. Callback trễ khi hold hết hạn cần quy trình đối soát và hoàn, không tự phát hành vé vào ghế đã bán.
2. **External payments không nằm trong MongoDB transaction**: không gọi API thanh toán trong callback `withTransaction` vì callback có thể retry. Dùng outbox/saga, trạng thái pending và idempotency nhà cung cấp. Hoàn tiền failed cần queue retry và màn hình đối soát. Hiện demo không mô phỏng lỗi mạng ngân hàng, chargeback hoặc settlement.
3. **HTTPS và secrets**: dùng reverse proxy HTTPS cùng domain. Đặt Origin chính xác, secrets có entropy cao; NODE_ENV=production không cho demo hoặc origin HTTP. Không tắt các guard để cố chạy thanh toán giả trên production.
4. **Proxy và scale**: mã mặc định không `trust proxy`. Nếu sau reverse proxy, cấu hình trusted proxy IP chính xác; không đặt trust proxy=true tùy tiện. Rate limiter hiện dùng memory mỗi process, cần store chung khi nhiều instance và chống bot ở edge.
5. **Quản trị**: bổ sung MFA cho admin, phân quyền chi tiết nếu nhiều nhân viên/rạp, theo dõi login bất thường, quy trình khôi phục tài khoản đã xác minh. Hiện chỉ có customer/admin theo báo cáo.
6. **Vận hành database**: dùng phiên bản MongoDB được hỗ trợ, TLS/allowlist, index migration, backup mã hóa, kiểm tra restore, giám sát transaction error và replica health. Compose chỉ dành local, chưa được thử trên máy người dùng.
7. **Dữ liệu cá nhân**: bổ sung thời hạn lưu tin nhắn, lịch sử, audit; quy trình xuất/xóa dữ liệu và thông báo quyền riêng tư phù hợp nơi triển khai. Chưa có API self-delete.
8. **Kiểm định**: chạy toàn bộ integration test, browser test, load test (p95, đồng thời giữ cùng ghế), audit dependencies, review/pentest độc lập. `npm audit` sạch không chứng minh code không có lỗi.

## Sao lưu và khôi phục

Cho vận hành thật, ưu tiên backup có quản lý của MongoDB Atlas hoặc MongoDB Database Tools, tài khoản backup chuyên biệt và bản sao mã hóa ngoài máy chủ. Không dùng tài khoản app readWrite làm tài khoản backup nếu chưa có quyền cần thiết.

Ví dụ quy trình bằng Database Tools (thay biến bằng URI của tài khoản được cấp quyền; không đưa URI thật vào git):

```powershell
$backupUri = Read-Host "MongoDB backup URI"
mongodump --uri="$backupUri" --db=cinego --archive=backups/cinego.archive --gzip
```

`Read-Host` không che nội dung trong ví dụ này; dùng secret manager trong vận hành. Tham số URI có thể xuất hiện trong danh sách tiến trình; cách xác thực của hạ tầng thật phải được đánh giá riêng. Tạo thư mục backups trước, hạn chế quyền truy cập, mã hóa và chuyển bản sao khỏi máy.

Khôi phục phải thử ở một replica set cô lập trước, không `--drop` database đang phục vụ người dùng. Kiểm tra số lượng orders/tickets, unique indexes, tổng thu/hoàn, ghế booked và khả năng đăng nhập. Sau đó mới xây dựng quy trình khôi phục production có người chịu trách nhiệm. Backup/restore chưa được thực nghiệm trong môi trường bàn giao.
