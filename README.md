# CineGo

**Link deploy:https://cinego-nhom7.netlify.app**

**Link tài khoản thanh toán demo:https://sandbox.vnpayment.vn/apis/vnpay-demo**

CineGo là hệ thống đặt vé xem phim trực tuyến, xây dựng bằng Flutter Web, Node.js và MongoDB. Dự án hỗ trợ tìm phim, xem lịch chiếu, chọn ghế, thanh toán, nhận vé QR và quản lý hoạt động của rạp.

## Thành viên tham gia

| Mã sinh viên | Họ và tên |
| --- | --- |
| 23010873 | Nguyễn Hồng Phong |
| 23010869 | Phùng Gia Minh |

## Chức năng

| Khách hàng | Quản trị viên |
| --- | --- |
| Xem phim, trailer và lịch theo ngày, thành phố, rạp | Quản lý phim, cụm rạp, phòng và giá vé |
| Chọn ghế, thanh toán và xem vé QR theo suất chiếu | Tạo hoặc sửa suất chiếu qua bộ chọn thành phố → rạp → phòng |
| Hủy hoặc đổi vé theo chính sách, mua và nhận bỏng nước | Quét vé, theo dõi đơn, tồn kho, nhận hàng và doanh thu |
| Trò chuyện theo suất chiếu, đọc bình luận và chấm 1–5 sao | Kiểm duyệt phòng chat và đánh giá |

Mọi người đều có thể đọc đánh giá công khai. Để viết đánh giá, người dùng cần có vé hợp lệ hoặc đã sử dụng của phim và suất chiếu đã kết thúc. Khi hết giờ chiếu, vé hiện trạng thái không còn hiệu lực và ẩn mã QR dùng để soát vé.

Các vé cùng suất chiếu được gộp thành một mục, bên trong hiển thị từng ghế và mã QR tương ứng. Danh sách phòng chat cũng được nhóm theo suất chiếu.

## Hệ thống rạp và lịch chiếu

| Thành phố | Cụm rạp |
| --- | --- |
| Hà Nội | CineGo Hà Nội, CineGo Long Biên |
| Hồ Chí Minh | CineGo Hồ Chí Minh |
| Đà Nẵng | CineGo Đà Nẵng |
| Thái Nguyên | CineGo Thái Nguyên |

Lịch chiếu hiển thị theo thứ tự **ngày → thành phố → rạp → giờ chiếu**. Người dùng chọn ngày và thành phố để xem các suất phù hợp. Bộ dữ liệu bổ sung có lịch mô phỏng đến hết **30/11/2026**; quản trị viên có thể tạo thêm lịch trong trang quản trị.

## Công nghệ

- **Frontend** dùng Flutter Web và Dart.
- **Backend** dùng Node.js, Express và Zod.
- **Database** dùng MongoDB và Mongoose. Các luồng giao dịch cần MongoDB Atlas hoặc MongoDB replica set.
- **Tài khoản** hỗ trợ xác minh email, mã đăng nhập và đặt lại mật khẩu qua SMTP.
- **Thanh toán** có chế độ demo và cấu hình VNPay hoặc MoMo. Hoàn tiền trong luồng demo được mô phỏng.

## Chạy trên máy cá nhân

Cần Node.js **22 trở lên**, npm, Flutter SDK có Dart **3.9 trở lên** theo `pubspec.yaml` và Chrome. Mở terminal tại thư mục chứa `package.json`.

### 1. Cài backend và tạo cấu hình

Trên Windows PowerShell, chạy:

```powershell
npm ci
Copy-Item .env.example .env
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Nếu đã có `.env`, bỏ qua lệnh sao chép và dùng file hiện tại. Dán chuỗi ngẫu nhiên vừa tạo vào `SESSION_SECRET`. Ví dụ cấu hình phát triển với Atlas:

```env
NODE_ENV=development
PORT=4000
APP_ORIGIN=http://localhost:4000
MONGODB_URI=mongodb+srv://USERNAME:PASSWORD@CLUSTER.mongodb.net/cinego?retryWrites=true&w=majority
SESSION_SECRET=THAY_BANG_CHUOI_NGAU_NHIEN_VUA_TAO
PAYMENT_MODE=demo
```

Thay thông tin Atlas và tên database theo project của nhóm. Cấp tài khoản database riêng cho mỗi thành viên và thêm IP công cộng của máy chạy backend vào danh sách IP được phép. Giữ thông tin kết nối trong `.env` trên từng máy, ngoài Git.

Để thử xác thực email trên máy cá nhân, có thể để trống `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` và `MAIL_FROM`. Khi đó backend ghi nội dung email thử nghiệm vào terminal. Nếu dùng SMTP, điền các biến tương ứng theo `.env.example`.

### 2. Chạy backend

```powershell
npm run dev
```

Kiểm tra tại [http://localhost:4000/api/health](http://localhost:4000/api/health).

### 3. Chạy Flutter Web

Mở terminal thứ hai tại thư mục gốc:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-hostname localhost --dart-define=API_BASE_URL=http://localhost:4000
```

Nếu dự án có cấu hình chạy Chrome trong VS Code, bạn cũng có thể dùng F5 sau khi đã chạy backend.

## Dữ liệu phim, rạp và lịch chiếu

Ứng dụng đọc dữ liệu từ MongoDB qua API. Thành viên dùng cùng database Atlas sẽ thấy danh mục phim và lịch chiếu hiện tại của nhóm. File [data/movies-cgv.json](data/movies-cgv.json) là dữ liệu nguồn. Để sửa phim đang hiển thị, vào **Quản trị → Phim**.

Nếu đang dùng một database trống để thử dự án, chạy `npm run seed` để tạo phim và lịch mẫu. Tạo tài khoản quản trị khi cần bằng `npm run admin`. Với database đã có dữ liệu của nhóm, cấu hình kết nối đến đúng database đó.

Để cập nhật **bộ rạp và lịch mô phỏng đến 30/11/2026** trên database đã có phim phù hợp, chạy từ thư mục gốc:

```powershell
node scripts/update-cinemas-november.js --database
node scripts/update-cinemas-november.js --apply
```

Lệnh đầu xem trước. Lệnh sau ghi rạp, phòng và các suất phù hợp vào MongoDB. Script giữ lịch có sẵn và bỏ qua khung giờ bị trùng. Xem điều kiện lập lịch, địa chỉ và cấu hình trong [hướng dẫn tháng 11](HUONG_DAN_RAP_LICH_THANG_11.md). Bộ lịch này có mốc kết thúc cố định, còn lịch mới có thể tạo trong **Quản trị → Suất chiếu & giá**.

## Cấu trúc thư mục

| Thư mục | Nội dung |
| --- | --- |
| `frontend/lib/screens/` | Giao diện phim, lịch, vé, phòng chat, tài khoản và quản trị |
| `frontend/lib/widgets/` | Thành phần dùng chung và phần đánh giá phim |
| `frontend/lib/core/` | Cấu hình, trạng thái ứng dụng và các tiện ích dùng chung |
| `server/routes/` | Các API Express |
| `server/models.js` | Các model Mongoose |
| `server/services/` | Nghiệp vụ đặt vé, phim, rạp và bỏng nước |
| `data/` và `scripts/` | Dữ liệu nguồn, công cụ nhập liệu và lập lịch |
| `tests/` và `frontend/test/` | Kiểm thử backend và Flutter |

## Kiểm tra mã nguồn

Tại thư mục gốc:

```powershell
npm run test:unit
node --test tests/network-planner.test.js
```

Tại thư mục `frontend`:

```powershell
flutter analyze
flutter test
```

Các bài integration backend chạy riêng bằng `npm run test:integration` và cần môi trường hỗ trợ MongoDB replica set thử nghiệm. Tài liệu kỹ thuật của dự án nằm trong [docs/](docs/).

## Lưu ý khi làm việc nhóm

- Mã nguồn được chia sẻ qua GitHub; dữ liệu phim, rạp, lịch chiếu và đơn hàng được lưu trên MongoDB.
- Pull mã nguồn không tự sao chép dữ liệu database. Các thành viên cần được cấp quyền kết nối đến database chung hoặc tạo dữ liệu mẫu trên database riêng.
- Không commit `.env`, mật khẩu, khóa thanh toán hoặc chuỗi kết nối Atlas lên GitHub. Dùng `.env.example` làm mẫu cấu hình.
- Chế độ demo dùng để thử luồng thanh toán. Khi triển khai thanh toán thực tế, cần cấu hình nhà cung cấp và các URL callback phù hợp.
