import {
  Movie,
  Cinema,
  Room,
  Seat,
  Showtime,
  ShowtimeSeat,
  Order,
  Ticket,
} from "../models.js";
import { transaction, create, fail, audit, same } from "../core.js";
async function lockRoom(roomId, session) {
  const room = await Room.findOneAndUpdate(
    { _id: roomId },
    { $inc: { revision: 1 } },
    { new: true, session },
  );
  if (!room) fail(404, "Không tìm thấy phòng.");
  return room;
}
export async function saveShowtime(userId, data, id) {
  return transaction(async (session) => {
    let old = id ? await Showtime.findById(id).session(session) : null;
    if (id && !old) fail(404, "Không tìm thấy suất chiếu.");
    const room = await lockRoom(data.roomId, session);
    if (old && !same(old.roomId, data.roomId))
      await lockRoom(old.roomId, session);
    if (old) {
      await Showtime.updateOne(
        { _id: id },
        { $inc: { revision: 1 } },
        { session },
      );
      if (
        await Order.exists({
          showtimeId: id,
          $or: [
            { status: "paid" },
            { status: "pending", expiresAt: { $gt: new Date() } },
          ],
        }).session(session)
      )
        fail(409, "Suất đang có đơn hoặc vé; không được sửa lịch hoặc giá.");
    }
    const movie = await Movie.findOneAndUpdate(
      { _id: data.movieId, status: "now" },
      { $inc: { revision: 1 } },
      { new: true, session },
    );
    const cinema = await Cinema.findOneAndUpdate(
      { _id: room.cinemaId, active: true },
      { $inc: { revision: 1 } },
      { new: true, session },
    );
    if (!movie || !cinema) fail(400, "Phim hoặc rạp không hoạt động.");
    const startAt = new Date(data.startAt),
      endAt = new Date(startAt.getTime() + movie.duration * 60000);
    if (startAt <= new Date()) fail(400, "Giờ chiếu phải ở tương lai.");
    if (
      await Showtime.exists({
        roomId: data.roomId,
        status: "active",
        _id: { $ne: id || null },
        startAt: { $lt: new Date(endAt.getTime() + 15 * 60000) },
        endAt: { $gt: new Date(startAt.getTime() - 15 * 60000) },
      }).session(session)
    )
      fail(409, "Trùng lịch phòng chiếu (bao gồm 15 phút dọn phòng).");
    const seats = await Seat.find({
      roomId: data.roomId,
      active: true,
    }).session(session);
    if (!seats.length) fail(400, "Phòng chưa có ghế.");
    const values = {
      ...data,
      cinemaId: room.cinemaId,
      startAt,
      endAt,
      status: "active",
    };
    const show = old
      ? await Showtime.findByIdAndUpdate(
          id,
          { $set: values },
          { new: true, runValidators: true, session },
        )
      : await create(Showtime, values, session);
    if (old) await ShowtimeSeat.deleteMany({ showtimeId: id }, { session });
    await ShowtimeSeat.insertMany(
      seats.map((s) => ({
        showtimeId: show._id,
        seatId: s._id,
        label: s.label,
        type: s.type,
        price: s.type === "vip" ? data.vipPrice : data.standardPrice,
      })),
      { session },
    );
    await audit(
      userId,
      old ? "showtime.updated" : "showtime.created",
      show._id,
      session,
    );
    return show;
  });
}
export async function deleteShowtime(userId, id) {
  return transaction(async (session) => {
    const show = await Showtime.findById(id).session(session);
    if (!show) fail(404, "Không tìm thấy suất chiếu.");
    await lockRoom(show.roomId, session);
    await Showtime.updateOne(
      { _id: id },
      { $inc: { revision: 1 } },
      { session },
    );
    if (
      (await Order.exists({
        showtimeId: id,
        $or: [
          { status: "paid" },
          { status: "pending", expiresAt: { $gt: new Date() } },
        ],
      }).session(session)) ||
      (await Ticket.exists({ showtimeId: id }).session(session))
    )
      fail(409, "Không xóa suất đã có vé hoặc đơn đang giữ ghế.");
    show.status = "cancelled";
    await show.save({ session });
    await audit(userId, "showtime.cancelled", show._id, session);
    return show;
  });
}
export async function saveRoom(userId, data, id) {
  return transaction(async (session) => {
    if (
      !(await Cinema.exists({ _id: data.cinemaId, active: true }).session(
        session,
      ))
    )
      fail(400, "Rạp không hoạt động.");
    let room;
    if (id) {
      room = await lockRoom(id, session);
      if (await Showtime.exists({ roomId: id }).session(session))
        fail(409, "Phòng đã có lịch chiếu; không thay sơ đồ ghế.");
      room.set({ name: data.name, cinemaId: data.cinemaId });
      await room.save({ session });
      await Seat.deleteMany({ roomId: id }, { session });
    } else
      room = await create(
        Room,
        { name: data.name, cinemaId: data.cinemaId },
        session,
      );
    const seats = [];
    for (let row = 0; row < data.rows; row++)
      for (let n = 1; n <= data.columns; n++)
        seats.push({
          roomId: room._id,
          label: `${String.fromCharCode(65 + row)}${n}`,
          row: String.fromCharCode(65 + row),
          number: n,
          type: row >= Math.floor(data.rows / 2) ? "vip" : "standard",
        });
    await Seat.insertMany(seats, { session });
    await audit(userId, "room.saved", room._id, session);
    return room;
  });
}
export async function editSeat(userId, id, data) {
  return transaction(async (session) => {
    const seat = await Seat.findById(id).session(session);
    if (!seat) fail(404, "Không tìm thấy ghế.");
    await lockRoom(seat.roomId, session);
    if (
      await Showtime.exists({
        roomId: seat.roomId,
        status: "active",
        endAt: { $gt: new Date() },
      }).session(session)
    )
      fail(409, "Không thay ghế của phòng đang có lịch chiếu.");
    seat.set(data);
    await seat.save({ session });
    await audit(userId, "seat.updated", seat._id, session);
    return seat;
  });
}
