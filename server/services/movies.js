import { Movie, Showtime, ShowtimeSeat, Ticket, Order } from "../models.js";
import { transaction, fail, audit } from "../core.js";

const HOUR = 3600000;
// Ngày khởi chiếu / kết thúc được lưu dạng ngày (UTC 00:00). Phim còn bán vé hết
// ngày kết thúc, tính theo giờ Việt Nam (UTC+7).
export const vnToday = () =>
  new Date(Date.now() + 7 * HOUR).toISOString().slice(0, 10);
export const saleEndsAt = (m) =>
  m?.endDate ? new Date(+new Date(m.endDate) + 17 * HOUR) : null;

// Chặn mua/đổi vé khi phim đã ẩn hoặc đã hết thời gian chiếu.
export async function assertMovieOnSale(movieId, session) {
  const m = await Movie.findById(movieId)
    .session(session || null)
    .lean();
  if (!m || m.deletedAt || m.status === "archived")
    fail(409, "Phim đã ngừng bán vé.");
  const end = saleEndsAt(m);
  if (end && end <= new Date())
    fail(409, "Phim đã hết thời gian chiếu, không thể mua vé nữa.");
}

// Tự ẩn phim quá ngày kết thúc và tự chuyển phim sắp chiếu sang đang chiếu khi tới ngày khởi chiếu.
let lastSync = 0;
export async function syncMovieStatuses(maxAgeMs = 0) {
  const t = Date.now();
  if (maxAgeMs && t - lastSync < maxAgeMs) return;
  lastSync = t;
  await Movie.updateMany(
    { status: "now", endDate: { $lt: new Date(t - 17 * HOUR) } },
    { $set: { status: "archived" } },
  );
  await Movie.updateMany(
    {
      status: "soon",
      releaseDate: { $lte: new Date(t + 7 * HOUR) },
      $or: [{ endDate: null }, { endDate: { $gte: new Date(t - 17 * HOUR) } }],
    },
    { $set: { status: "now" } },
  );
}

export const hideMovie = (userId, id) =>
  transaction(async (session) => {
    const m = await Movie.findOneAndUpdate(
      { _id: id, deletedAt: null },
      { $set: { status: "archived" } },
      { new: true, session },
    );
    if (!m) fail(404, "Không tìm thấy phim.");
    await audit(userId, "movies.hidden", m._id, session);
    return m;
  });

// endDate: undefined = giữ nguyên, null = không giới hạn, "YYYY-MM-DD" = ngày mới.
export const reopenMovie = (userId, id, endDate) =>
  transaction(async (session) => {
    const m = await Movie.findOne({ _id: id, deletedAt: null }).session(session);
    if (!m) fail(404, "Không tìm thấy phim.");
    const end = endDate === undefined ? m.endDate : endDate ? new Date(endDate) : null;
    if (end && end.toISOString().slice(0, 10) < vnToday())
      fail(400, "Hãy chọn ngày kết thúc bán vé từ hôm nay trở đi.");
    m.status = "now";
    m.endDate = end;
    await m.save({ session });
    await audit(userId, "movies.reopened", m._id, session);
    return m;
  });

// Xóa phim: không cho xóa khi còn lịch chiếu sắp tới. Phim chưa từng bán vé bị xóa hẳn;
// phim đã có vé thì chỉ ẩn khỏi hệ thống để vé cũ vẫn xem được tên phim.
export const deleteMovie = (userId, id) =>
  transaction(async (session) => {
    const m = await Movie.findOne({ _id: id, deletedAt: null }).session(session);
    if (!m) fail(404, "Không tìm thấy phim.");
    if (
      await Showtime.exists({
        movieId: id,
        status: "active",
        endAt: { $gt: new Date() },
      }).session(session)
    )
      fail(
        409,
        "Phim vẫn còn lịch chiếu nên chưa thể xóa. Hãy hủy hết lịch chiếu của phim trước.",
      );
    const showIds = await Showtime.distinct("_id", { movieId: id }).session(session);
    const history =
      showIds.length > 0 &&
      ((await Ticket.exists({ showtimeId: { $in: showIds } }).session(session)) ||
        (await Order.exists({ showtimeId: { $in: showIds } }).session(session)));
    if (history) {
      m.deletedAt = new Date();
      m.status = "archived";
      await m.save({ session });
    } else {
      await ShowtimeSeat.deleteMany({ showtimeId: { $in: showIds } }, { session });
      await Showtime.deleteMany({ movieId: id }, { session });
      await Movie.deleteOne({ _id: id }, { session });
    }
    await audit(userId, "movies.deleted", id, session);
    return { ok: true };
  });
