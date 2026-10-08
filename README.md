# CineGo — Website đặt vé xem phim

CineGo là website đặt vé xem phim trực tuyến với giao diện tiếng Việt. Frontend sử dụng Flutter Web, backend sử dụng Node.js và Express, dữ liệu được lưu trên MongoDB thông qua Mongoose.

Người dùng có thể tìm phim, chọn rạp, chọn suất chiếu và ghế ngồi, thanh toán thử nghiệm, nhận vé điện tử và quản lý lịch sử đặt vé. Hệ thống có khu vực quản trị để quản lý danh mục, lịch chiếu, đơn hàng và phòng chat.

## Công nghệ sử dụng

| Thành phần | Công nghệ |
| --- | --- |
| Giao diện | Flutter Web, Dart |
| Backend | Node.js, Express |
| Cơ sở dữ liệu | MongoDB Atlas hoặc MongoDB replica set |
| Truy cập dữ liệu | Mongoose |
| Xác thực | Session cookie, mật khẩu băm bằng scrypt |
| Kiểm tra dữ liệu | Zod |
| Kiểm thử | Node.js Test Runner, Flutter Test, Playwright |

## Chức năng chính

### Khách hàng

- Đăng ký, đăng nhập và quản lý thông tin cá nhân.
- Xem danh sách phim đang chiếu, sắp chiếu và tìm kiếm phim.
- Xem nội dung phim, thể loại, thời lượng và phân loại độ tuổi.
- Xem banner trượt ngang giới thiệu phim và thông tin CineGo.
- Tìm rạp gần vị trí hiện tại khi được cấp quyền truy cập vị trí.
- Chọn rạp, ngày chiếu, suất chiếu và ghế thường hoặc VIP.
- Giữ ghế tạm thời và xem tổng tiền trước khi thanh toán.
- Thanh toán thử nghiệm và nhận vé điện tử có mã QR.
- Xem lịch sử đặt vé, hủy hoặc đổi vé theo điều kiện của hệ thống.
- Xem điểm tích lũy.
- Tham gia phòng chat theo suất chiếu; Enter để gửi, Shift+Enter để xuống dòng.

### Quản trị viên

- Quản lý phim, rạp, phòng chiếu và sơ đồ ghế.
- Quản lý suất chiếu và giá vé.
- Quản lý trạng thái tài khoản khách hàng.
- Theo dõi đơn hàng, số tiền thu, hoàn tiền và nhật ký thao tác.
- Soát vé bằng mã QR.
- Kiểm duyệt phòng chat: ẩn hoặc khôi phục tin nhắn, xóa tin nhắn, khóa hoặc mở phòng, chặn hoặc bỏ chặn thành viên.

## Yêu cầu môi trường

- Node.js 22 trở lên và npm.
- Flutter SDK tương thích với dự án; phiên bản tham chiếu: Flutter 3.41.4, Dart 3.11.1.
- Google Chrome.
- Visual Studio Code với extension Flutter và Dart nếu chạy bằng F5.
- MongoDB Atlas hoặc MongoDB replica set để hỗ trợ transaction.

Dự án hiện tập trung vào Flutter Web. Android và iOS chưa được cấu hình và kiểm thử đầy đủ. Khi sử dụng Atlas, cần kết nối internet; không cần mở Docker Desktop.

## Cài đặt lần đầu với MongoDB Atlas

Mở thư mục gốc của dự án, nơi chứa `package.json`, `server` và `frontend`.

### 1. Cài thư viện

Tại thư mục gốc:

```bash
npm ci
cd frontend
flutter pub get
cd ..
```

### 2. Cấu hình Atlas và biến môi trường

Trên MongoDB Atlas:

1. Tạo cluster và database user có quyền đọc, ghi trên database dự định sử dụng.
2. Thêm IP công cộng hiện tại vào danh sách Network Access.
3. Chọn Connect, lấy chuỗi kết nối dành cho ứng dụng Node.js.

Tạo file `.env` tại thư mục gốc, có thể sao chép từ `.env.example`. Ví dụ cho database mới tên `cinego`:

```env
NODE_ENV=development
PORT=4000
APP_ORIGIN=http://localhost:5173
MONGODB_URI="mongodb+srv://DB_USER:DB_PASSWORD@CLUSTER_HOST/cinego?retryWrites=true&w=majority"
SESSION_SECRET=THAY_BANG_CHUOI_NGAU_NHIEN_IT_NHAT_48_KY_TU
PAYMENT_MODE=demo
HOLD_MINUTES=10
CHANGE_CUTOFF_HOURS=24
REFUND_PERCENT=100
POINTS_PER_VND=10000
```

Thay các giá trị mẫu bằng cấu hình của bạn. Nếu mật khẩu chứa ký tự đặc biệt, mã hóa URL trước khi đưa vào chuỗi kết nối. Database user của Atlas khác với tài khoản admin của CineGo.

Tạo giá trị ngẫu nhiên cho `SESSION_SECRET` bằng lệnh:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Chép kết quả vào `.env`. Không đưa `.env`, mật khẩu hoặc chuỗi kết nối thật lên GitHub.

Nếu dự án đã kết nối thành công và có dữ liệu, giữ nguyên `.env` hiện có. Không tự đổi tên database trong URI: thay tên sẽ khiến ứng dụng đọc một database khác.

### 3. Tạo tài khoản quản trị

Chỉ thực hiện khi chưa có tài khoản admin:

```bash
npm run admin
```

Nhập email, tên và mật khẩu tối thiểu 12 ký tự. Mật khẩu hiện trong terminal khi nhập. Lệnh không ghi đè hoặc nâng quyền tài khoản đã tồn tại.

### 4. Nhập dữ liệu phim

Bộ dữ liệu tuyển chọn được đối chiếu ngày 07/10/2026 nằm tại `scripts/data/movies-2026-10-07.json`, gồm bốn phim: Quyết Cua Anh Này, Thần Sư Chung Quỳ: Linh Giới Đại Chiến, Scotty: Giải Cứu Hoàng Thượng và Khóa Chặt Cửa Nào Suzume.

Xem trước dữ liệu:

```bash
node scripts/import-current-movies.js
```

Nhập phim và tạo lịch chiếu mô phỏng trong 7 ngày tính từ ngày chạy:

```bash
node scripts/import-current-movies.js --apply --demo-showtimes
```

Nếu chỉ muốn nhập phim:

```bash
node scripts/import-current-movies.js --apply
```

Lệnh giữ nguyên phim trùng tên, tài khoản và dữ liệu hiện có. Không chạy nhiều tiến trình nhập cùng lúc. Lịch mô phỏng sử dụng rạp CineGo Hà Đông · Demo, giá ghế thường 80.000 đồng và VIP 110.000 đồng; đây không phải lịch hoặc giá vé thương mại thực tế.

Nguồn thông tin và URL poster được ghi trong file JSON. Dữ liệu không tự cập nhật theo thị trường. Poster từ nguồn ngoài cần internet. Không cần chạy `npm run seed` khi sử dụng bộ dữ liệu này; lệnh seed cũ tạo danh mục phim hư cấu riêng.

## Chạy dự án hằng ngày

### 1. Khởi động backend

Tại thư mục gốc:

```bash
npm run dev
```

Đợi thông báo:

```text
CineGo API listening on port 4000; payment mode=demo
```

Giữ terminal hoạt động trong khi sử dụng website.

### 2. Khởi động Flutter bằng F5

Mở toàn bộ thư mục dự án trong VS Code, không chỉ mở riêng `frontend`.

1. Vào Run and Debug bằng `Ctrl+Shift+D`.
2. Chọn `CineGo - Chrome (auto port)` để tự chọn cổng trống, hoặc `CineGo - Chrome (choose port)` để nhập cổng.
3. Nhấn F5.

Cấu hình nằm trong `.vscode/launch.json`. F5 chỉ chạy Flutter; backend vẫn cần khởi động riêng.

Khi `NODE_ENV=development`, backend cho phép các cổng HTTP localhost hợp lệ nên không cần đổi `APP_ORIGIN` mỗi lần Flutter đổi cổng. Backend mặc định ở cổng 4000; không chọn cổng này cho Flutter.

Nếu chạy Flutter bằng terminal, dùng:

```bash
cd frontend
flutter run -d chrome --web-hostname localhost --dart-define=API_BASE_URL=http://localhost:4000
```

Không cần cài lại thư viện, tạo admin hoặc nhập lại dữ liệu mỗi lần mở dự án. Khi lịch chiếu đã hết, thêm lịch trong trang quản trị hoặc chạy lại tùy chọn tạo lịch mô phỏng.

Dừng Flutter bằng Shift+F5 và dừng backend bằng Ctrl+C.

## Chạy bản build trên máy cá nhân

Tại thư mục gốc:

```bash
cd frontend
flutter build web --release --csp --no-web-resources-cdn
cd ..
npm start
```

Mở [http://localhost:4000](http://localhost:4000). Backend phục vụ các file trong `frontend/build/web`. Giữ cấu hình phát triển khi chạy thanh toán demo; đây chưa phải hướng dẫn triển khai production.

## Cấu trúc dự án

| Đường dẫn | Nội dung |
| --- | --- |
| `.vscode/launch.json` | Cấu hình chạy Flutter bằng F5 |
| `frontend/lib/core` | API client, phiên đăng nhập và định dạng dữ liệu |
| `frontend/lib/screens` | Màn hình khách hàng và quản trị |
| `frontend/lib/widgets` | Thành phần giao diện dùng chung và carousel |
| `frontend/lib/platform` | Tích hợp các chức năng trình duyệt |
| `frontend/assets` | Tài nguyên giao diện và font chữ |
| `frontend/test` | Kiểm thử Flutter |
| `server` | Cấu hình, model, xác thực, API và nghiệp vụ |
| `scripts` | Khởi tạo môi trường, tạo admin và nhập dữ liệu |
| `scripts/data` | Bộ dữ liệu phim và nguồn tham khảo |
| `tests` | Kiểm thử backend và giao diện trình duyệt |
| `docs` | Tài liệu yêu cầu, backend, bảo mật và kiểm thử |

Flutter gọi API của backend; chỉ backend kết nối trực tiếp với MongoDB. Giá tiền, quyền truy cập và điều kiện đặt vé được kiểm tra ở phía server.

## Kiểm tra mã nguồn

Kiểm tra backend:

```bash
npm run test:unit
npm run test:integration
```

Kiểm tra Flutter:

```bash
cd frontend
flutter analyze
flutter test
```

Kiểm thử tích hợp cần môi trường có thể chạy MongoDB replica set thử nghiệm. Xem `docs/TEST-RESULTS.md` để biết phạm vi và giới hạn của các lần kiểm thử trước; các báo cáo cũ không xác nhận toàn bộ bản cập nhật mới nhất.

## Lỗi thường gặp

| Hiện tượng | Cách kiểm tra |
| --- | --- |
| Không kết nối Atlas, lỗi TLS hoặc ServerSelectionError | Kiểm tra IP hiện tại trong Network Access, trạng thái cluster và đường mạng; thử mạng khác để khoanh vùng nếu cần |
| Lỗi xác thực MongoDB | Kiểm tra database user, mật khẩu, mã hóa ký tự đặc biệt và quyền trên database |
| F5 không nhận cấu hình | Mở đúng thư mục gốc, kiểm tra `.vscode/launch.json` và extension Flutter/Dart |
| Không tìm thấy `home_carousel.dart` | Kiểm tra file tại `frontend/lib/widgets/home_carousel.dart` |
| Lỗi Origin hoặc CSRF | Kiểm tra `NODE_ENV`, `APP_ORIGIN`, dùng hostname `localhost`, khởi động lại backend và đăng nhập lại |
| Không có lịch chiếu | Kiểm tra ngày lọc, trạng thái phim và bổ sung suất chiếu tương lai |
| Không hiện poster | Kiểm tra internet và URL ảnh trong dữ liệu phim |
| Không lấy được vị trí | Cấp quyền vị trí cho trình duyệt; triển khai thực tế cần HTTPS |

## Lưu ý khi đưa mã nguồn lên GitHub

- Không commit `.env`, khóa riêng, mật khẩu database hoặc ảnh chụp chứa thông tin bí mật.
- Chỉ đưa cấu hình mẫu không có bí mật vào `.env.example`.
- Bỏ qua `node_modules`, `.dart_tool` và các thư mục build trong `.gitignore`.
- Giữ `package-lock.json` và `frontend/pubspec.lock` để cố định phiên bản thư viện.
- Kiểm tra `git status` và `git diff --cached` trước khi commit.
- Nếu bí mật từng bị lộ, thay hoặc thu hồi bí mật đó; xóa file ở commit mới không xóa nội dung khỏi lịch sử Git.
- Git lưu mã nguồn; dữ liệu trên Atlas cần được sao lưu riêng.

## Phạm vi hiện tại

Thanh toán và hoàn tiền đang ở chế độ thử nghiệm, chưa kết nối cổng thanh toán thật. Điểm tích lũy chưa được dùng để giảm giá. Hệ thống chưa có gửi email/SMS hoặc khôi phục mật khẩu tự động.

Các điều kiện giữ ghế, hủy, đổi và hoàn tiền hiện là cấu hình mô phỏng. Trước khi triển khai thực tế cần tích hợp thanh toán, xác định chính sách vận hành, cấu hình HTTPS và sao lưu, đồng thời kiểm thử đầy đủ các luồng giao dịch và bảo mật.
