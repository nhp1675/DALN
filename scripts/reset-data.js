// Xóa dữ liệu nghiệp vụ trong MongoDB (phim, rạp, phòng, ghế, suất chiếu, đơn, vé,
// thanh toán, bỏng nước, chat...). Luôn giữ tài khoản admin.
//
//   npm run reset-data                 -> chỉ xem trước, KHÔNG xóa gì
//   npm run reset-data -- --apply      -> xóa thật (phải gõ tên database để xác nhận)
//   npm run reset-data -- --apply --users
//                                      -> xóa thêm tài khoản khách và mọi phiên đăng nhập
import { createInterface } from "node:readline/promises";
import mongoose from "mongoose";
import { config } from "../server/config.js";
import { allModels, User } from "../server/models.js";

const flags = new Set(process.argv.slice(2));
const unknown = [...flags].filter((f) => !["--apply", "--users"].includes(f));
if (unknown.length) throw Error(`Tùy chọn không hợp lệ: ${unknown.join(", ")}`);
if (config.NODE_ENV === "production")
  throw Error("Không chạy script xóa dữ liệu ở môi trường production.");

const apply = flags.has("--apply");
const withUsers = flags.has("--users");
// User xử lý riêng (giữ admin); Session chỉ xóa khi --users.
const targets = allModels.filter((m) => !["User", "Session"].includes(m.modelName));
const sessionModel = allModels.find((m) => m.modelName === "Session");

try {
  await mongoose.connect(config.MONGODB_URI, { serverSelectionTimeoutMS: 10000 });
  const dbName = mongoose.connection.name;
  console.log(`Database: ${dbName}`);

  const rows = [];
  for (const m of targets)
    rows.push({ collection: m.modelName, "sẽ xóa": await m.countDocuments({}) });
  const admins = await User.countDocuments({ role: "admin" });
  const customers = await User.countDocuments({ role: { $ne: "admin" } });
  rows.push({
    collection: "User (khách)",
    "sẽ xóa": withUsers ? customers : 0,
  });
  rows.push({
    collection: "Session",
    "sẽ xóa": withUsers ? await sessionModel.countDocuments({}) : 0,
  });
  console.table(rows);
  console.log(`Giữ lại: ${admins} tài khoản admin${withUsers ? "" : `, ${customers} tài khoản khách`}.`);

  if (!apply) {
    console.log("Chỉ xem trước, chưa xóa gì. Thêm --apply để xóa thật.");
  } else {
    console.log("\nCẢNH BÁO: thao tác này xóa vĩnh viễn, không hoàn tác được.");
    console.log("Hãy sao lưu trước (Atlas backup hoặc mongodump) nếu cần giữ lại.");
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    const typed = (await rl.question(`Gõ đúng tên database "${dbName}" để xác nhận: `)).trim();
    rl.close();
    if (typed !== dbName) {
      console.log("Tên không khớp. Đã hủy, chưa xóa gì.");
    } else {
      for (const m of targets) await m.deleteMany({});
      if (withUsers) {
        await User.deleteMany({ role: { $ne: "admin" } });
        await sessionModel.deleteMany({});
      }
      console.log("Đã xóa xong.");
    }
  }
} catch (e) {
  console.error("Không hoàn tất:", e.message);
  process.exitCode = 1;
} finally {
  await mongoose.disconnect();
}
