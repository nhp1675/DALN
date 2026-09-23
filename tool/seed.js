/**
 * Tạo dữ liệu mẫu để chạy thử (phim, rạp, phòng + ghế, suất chiếu, bảng giá).
 * Cách dùng:
 *   npm i firebase-admin
 *   node tool/seed.js serviceAccountKey.json
 */
const { initializeApp } = require("firebase-admin/app");
const { cert } = require("firebase-admin/app");
const { getFirestore, Timestamp, GeoPoint } = require("firebase-admin/firestore");
const path = require("path");

// Đường dẫn tới file service account được tính theo thư mục bạn đang
// chạy lệnh `node tool/seed.js ...` (thường là thư mục gốc `cinema`),
// không phải theo thư mục chứa file seed.js.
const keyPathArg = process.argv[2] || "./serviceAccountKey.json";
const keyPath = path.resolve(process.cwd(), keyPathArg);

initializeApp({ credential: cert(require(keyPath)) });
const db = getFirestore();

async function main() {
  // 1. Phim
  const phims = [
    { tenPhim: "Mắt Biếc", theLoai: ["Tình cảm"], thoiLuong: 117, doTuoi: "T13",
      daoDien: "Victor Vũ", dienVien: ["Trần Nghĩa", "Trúc Anh"],
      noiDung: "Chuyện tình đơn phương của Ngạn dành cho Hà Lan.",
      poster: "", trangThai: "dangChieu" },
    { tenPhim: "Nhà Bà Nữ", theLoai: ["Hài", "Gia đình"], thoiLuong: 106, doTuoi: "T16",
      daoDien: "Trấn Thành", dienVien: ["Lê Giang", "Uyển Ân"],
      noiDung: "Mâu thuẫn giữa các thế hệ trong một gia đình bán bánh canh.",
      poster: "", trangThai: "dangChieu" },
    { tenPhim: "Địa Đạo", theLoai: ["Chiến tranh"], thoiLuong: 128, doTuoi: "T18",
      daoDien: "Bùi Thạc Chuyên", dienVien: ["Thái Hòa"],
      noiDung: "Câu chuyện về những chiến sĩ trong lòng đất.", poster: "", trangThai: "sapChieu" },
  ];
  const phimIds = [];
  for (const p of phims) phimIds.push((await db.collection("phim").add(p)).id);

  // 2. Rạp + phòng + ghế
  const raps = [
    { tenRap: "CineTicket Cầu Giấy", diaChi: "Số 1 Trần Thái Tông, Hà Nội",
      viTri: new GeoPoint(21.0307, 105.7823),
      soDienThoai: "02412345678", trangThai: "hoatDong" },
    { tenRap: "CineTicket Hà Đông", diaChi: "Số 2 Quang Trung, Hà Đông, Hà Nội",
      viTri: new GeoPoint(20.9721, 105.7788),
      soDienThoai: "02487654321", trangThai: "hoatDong" },
  ];

  const suatCanTao = [];
  for (const r of raps) {
    const rapRef = await db.collection("rap").add(r);
    for (let k = 1; k <= 2; k++) {
      const phongRef = await rapRef.collection("phongChieu").add({
        rapId: rapRef.id, tenPhong: `Phòng ${k}`, loaiPhong: k === 1 ? "2D" : "3D",
        soLuongGhe: 80,
      });
      const batch = db.batch();
      for (let i = 0; i < 8; i++) {
        const hang = String.fromCharCode(65 + i);
        for (let j = 1; j <= 10; j++) {
          batch.set(phongRef.collection("ghe").doc(`${hang}${j}`), {
            phongId: phongRef.id, hang, so: j,
            loaiGhe: ["E", "F"].includes(hang) ? "VIP" : "Thuong",
          });
        }
      }
      await batch.commit();
      suatCanTao.push({ rap: r, rapId: rapRef.id, phongId: phongRef.id, tenPhong: `Phòng ${k}` });
    }
  }

  // 3. Suất chiếu 3 ngày tới
  for (let ngay = 0; ngay < 3; ngay++) {
    for (const [i, p] of phimIds.entries()) {
      for (const [j, phong] of suatCanTao.entries()) {
        const batDau = new Date();
        batDau.setDate(batDau.getDate() + ngay);
        batDau.setHours(10 + ((i * 3 + j * 2) % 10), 0, 0, 0);
        const ketThuc = new Date(batDau.getTime() + phims[i].thoiLuong * 60000);
        await db.collection("suatChieu").add({
          phimId: p, phongId: phong.phongId, rapId: phong.rapId,
          tenPhim: phims[i].tenPhim, tenRap: phong.rap.tenRap, tenPhong: phong.tenPhong,
          ngayChieu: batDau.toISOString().slice(0, 10),
          gioBatDau: Timestamp.fromDate(batDau),
          gioKetThuc: Timestamp.fromDate(ketThuc),
          giaVeCoBan: 75000, soLuongGhe: 80, trangThai: "conSuat",
        });
      }
    }
  }

  // 4. Bảng giá vé
  const gia = [
    { loaiGhe: "Thuong", loaiNgay: "NgayThuong", khungGio: "Sang", giaTien: 60000 },
    { loaiGhe: "Thuong", loaiNgay: "NgayThuong", khungGio: "Toi", giaTien: 75000 },
    { loaiGhe: "Thuong", loaiNgay: "CuoiTuan", khungGio: "Sang", giaTien: 75000 },
    { loaiGhe: "Thuong", loaiNgay: "CuoiTuan", khungGio: "Toi", giaTien: 90000 },
    { loaiGhe: "VIP", loaiNgay: "NgayThuong", khungGio: "Sang", giaTien: 80000 },
    { loaiGhe: "VIP", loaiNgay: "NgayThuong", khungGio: "Toi", giaTien: 100000 },
    { loaiGhe: "VIP", loaiNgay: "CuoiTuan", khungGio: "Sang", giaTien: 100000 },
    { loaiGhe: "VIP", loaiNgay: "CuoiTuan", khungGio: "Toi", giaTien: 120000 },
  ];
  for (const g of gia) {
    await db.collection("giaVe").add({ ...g, ngayApDung: Timestamp.now() });
  }

  console.log("Đã tạo xong dữ liệu mẫu.");
}

main().catch(console.error);