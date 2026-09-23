/**
 * Cloud Functions — phần nền của hệ thống đặt vé.
 * Triển khai: cd functions && npm install && firebase deploy --only functions
 */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const PHUT_GIU_GHE = 10;

/**
 * Dọn các bản ghi ghe_suat_chieu ở trạng thái "đang giữ" quá thời gian quy định,
 * trả ghế về trạng thái trống (lưu ý cuối tài liệu Thiết kế CSDL).
 * Đồng thời hủy các đơn "chờ thanh toán" đã quá hạn.
 */
exports.donGheGiuQuaHan = onSchedule("every 2 minutes", async () => {
  const hanCuoi = admin.firestore.Timestamp.fromMillis(
    Date.now() - PHUT_GIU_GHE * 60 * 1000
  );

  const snap = await db
    .collection("ghe_suat_chieu")
    .where("trangThaiGhe", "==", "dangGiu")
    .where("thoiGianGiu", "<=", hanCuoi)
    .limit(500)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  const donCanHuy = new Set();

  snap.docs.forEach((d) => {
    const data = d.data();
    if (data.donId) donCanHuy.add(data.donId);
    batch.update(d.ref, {
      trangThaiGhe: "trong",
      thoiGianGiu: null,
      uidGiu: null,
      donId: null,
    });
  });

  for (const donId of donCanHuy) {
    const ref = db.collection("donDatVe").doc(donId);
    const don = await ref.get();
    if (don.exists && don.data().trangThai === "choThanhToan") {
      batch.update(ref, { trangThai: "daHuy" });
    }
  }

  await batch.commit();
  console.log(`Đã trả lại ${snap.size} ghế hết hạn giữ chỗ.`);
});

/**
 * Khi mọi ghế của một suất đã được đặt thì cập nhật suất chiếu sang "hết vé".
 */
exports.capNhatTrangThaiSuat = onDocumentUpdated(
  "ghe_suat_chieu/{id}",
  async (event) => {
    const sau = event.data.after.data();
    if (!sau || sau.trangThaiGhe !== "daDat") return;

    const suatId = sau.suatId;
    const suatRef = db.collection("suatChieu").doc(suatId);
    const suat = await suatRef.get();
    if (!suat.exists) return;

    const phongPath = suat.data().phongId;
    const conTrong = await db
      .collection("ghe_suat_chieu")
      .where("suatId", "==", suatId)
      .where("trangThaiGhe", "==", "trong")
      .limit(1)
      .get();

    // Chỉ đánh dấu hết vé khi không còn bản ghi ghế trống nào được tạo
    if (conTrong.empty && phongPath) {
      // Ghi chú: hệ thống chỉ tạo bản ghi ghe_suat_chieu khi có người chọn ghế,
      // nên cần so sánh với tổng số ghế của phòng để chính xác tuyệt đối.
      const tongDaDat = await db
        .collection("ghe_suat_chieu")
        .where("suatId", "==", suatId)
        .where("trangThaiGhe", "==", "daDat")
        .count()
        .get();
      const soGhe = suat.data().soLuongGhe || 0;
      if (soGhe > 0 && tongDaDat.data().count >= soGhe) {
        await suatRef.update({ trangThai: "hetVe" });
      }
    }
  }
);
