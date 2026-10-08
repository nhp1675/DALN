import { moderationRouter } from "./moderation.js";
import { Router } from "express";
import { z } from "zod";
import {
  Movie,
  Cinema,
  Room,
  Seat,
  Showtime,
  ShowtimeSeat,
  User,
  Session,
  Order,
  Ticket,
  Payment,
  Refund,
  Audit,
} from "../models.js";
import { requireAuth, requireAdmin } from "../auth.js";
import {
  route,
  body,
  objectId,
  parseId,
  fail,
  transaction,
  audit,
  same,
} from "../core.js";
import {
  saveShowtime,
  deleteShowtime,
  saveRoom,
  editSeat,
} from "../services/catalog.js";
export const adminRouter = Router();
adminRouter.use(requireAuth, requireAdmin);
adminRouter.use("/chat", moderationRouter);
const str = z.string().trim().min(1).max(200);
const poster = z
  .string()
  .max(2048)
  .refine(
    (x) =>
      x === "" ||
      /^\/posters\/[a-z0-9_-]+\.svg$/.test(x) ||
      /^https:\/\//.test(x),
    "Ảnh cần URL HTTPS hoặc ảnh poster có sẵn",
  );
const movieSchema = z
  .object({
    title: str,
    genre: str,
    duration: z.number().int().min(1).max(400),
    synopsis: z.string().trim().min(1).max(5000),
    cast: z.string().max(1000).default(""),
    director: z.string().max(200).default(""),
    ageRating: z.enum(["P", "K", "T13", "T16", "T18"]),
    status: z.enum(["now", "soon", "archived"]),
    poster: poster.default(""),
    releaseDate: z.string().date().optional(),
  })
  .strict();
const cinemaSchema = z
  .object({
    name: str,
    address: str,
    city: str,
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    active: z.boolean(),
  })
  .strict();
const roomSchema = z
  .object({
    cinemaId: objectId,
    name: str,
    rows: z.number().int().min(1).max(15),
    columns: z.number().int().min(1).max(20),
  })
  .strict();
const showSchema = z
  .object({
    movieId: objectId,
    roomId: objectId,
    startAt: z.string().datetime({ offset: true }),
    standardPrice: z.number().int().min(1000).max(10000000),
    vipPrice: z.number().int().min(1000).max(10000000),
  })
  .strict();
adminRouter.get(
  "/overview",
  route(async (req, res) => {
    const [users, tickets, payments, refunds, pending] = await Promise.all([
      User.countDocuments({ role: "customer" }),
      Ticket.countDocuments({ status: "valid" }),
      Payment.aggregate([
        { $match: { status: "success" } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),
      Refund.aggregate([
        { $match: { status: "success" } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),
      Order.countDocuments({
        status: "pending",
        expiresAt: { $gt: new Date() },
      }),
    ]);
    res.json({
      users,
      tickets,
      pending,
      gross: payments[0]?.total || 0,
      refunds: refunds[0]?.total || 0,
      net: (payments[0]?.total || 0) - (refunds[0]?.total || 0),
    });
  }),
);
const lists = {
  movies: Movie,
  cinemas: Cinema,
  rooms: Room,
  seats: Seat,
  showtimes: Showtime,
  orders: Order,
  users: User,
  payments: Payment,
  refunds: Refund,
  audits: Audit,
};
adminRouter.get(
  "/data/:entity",
  route(async (req, res) => {
    const Model = lists[req.params.entity];
    if (!Model) fail(404, "Danh mục không tồn tại.");
    const page = z.coerce
      .number()
      .int()
      .min(1)
      .max(10000)
      .parse(req.query.page || 1);
    const filter = {};
    if (req.params.entity === "seats" && req.query.roomId)
      filter.roomId = parseId(req.query.roomId);
    const [items, total] = await Promise.all([
      Model.find(filter)
        .select(Model === User ? "-passwordHash" : "")
        .sort({ createdAt: -1 })
        .skip((page - 1) * 50)
        .limit(50)
        .lean(),
      Model.countDocuments(filter),
    ]);
    res.json({ items, total, page, pages: Math.ceil(total / 50) });
  }),
);
for (const [name, Model, schema] of [
  ["movies", Movie, movieSchema],
  ["cinemas", Cinema, cinemaSchema],
]) {
  adminRouter.post(
    "/" + name,
    body(schema),
    route(async (req, res) => {
      const doc = await Model.create(req.data);
      await Audit.create({
        userId: req.user._id,
        action: `${name}.created`,
        entityId: doc._id,
      });
      res.status(201).json(doc);
    }),
  );
  adminRouter.put(
    "/" + name + "/:id",
    body(schema),
    route(async (req, res) => {
      const id = parseId(req.params.id);
      res.json(
        await transaction(async (session) => {
          const doc = await Model.findByIdAndUpdate(
            id,
            { $set: req.data },
            { new: true, runValidators: true, session },
          );
          if (!doc) fail(404, "Không tìm thấy dữ liệu.");
          const disabling =
            name === "movies" ? req.data.status !== "now" : !req.data.active;
          if (
            disabling &&
            (await Showtime.exists({
              [name === "movies" ? "movieId" : "cinemaId"]: id,
              status: "active",
              endAt: { $gt: new Date() },
            }).session(session))
          )
            fail(
              409,
              "Đang có lịch chiếu; không thể tắt rạp hoặc chuyển phim khỏi đang chiếu.",
            );
          await audit(req.user._id, `${name}.updated`, doc._id, session);
          return doc;
        }),
      );
    }),
  );
  adminRouter.delete(
    "/" + name + "/:id",
    route(async (req, res) => {
      const id = parseId(req.params.id);
      res.json(
        await transaction(async (session) => {
          const filter = name === "movies" ? { movieId: id } : { cinemaId: id };
          if (
            await Showtime.exists({
              ...filter,
              status: "active",
              endAt: { $gt: new Date() },
            }).session(session)
          )
            fail(409, "Đang có lịch chiếu. Hãy xử lý lịch trước.");
          const update =
            name === "movies" ? { status: "archived" } : { active: false };
          const doc = await Model.findByIdAndUpdate(
            id,
            { $set: update },
            { new: true, session },
          );
          if (!doc) fail(404, "Không tìm thấy dữ liệu.");
          await audit(req.user._id, `${name}.archived`, doc._id, session);
          return doc;
        }),
      );
    }),
  );
}
adminRouter.post(
  "/rooms",
  body(roomSchema),
  route(async (req, res) =>
    res.status(201).json(await saveRoom(req.user._id, req.data)),
  ),
);
adminRouter.put(
  "/rooms/:id",
  body(roomSchema),
  route(async (req, res) =>
    res.json(await saveRoom(req.user._id, req.data, parseId(req.params.id))),
  ),
);
adminRouter.delete(
  "/rooms/:id",
  route(async (req, res) => {
    const id = parseId(req.params.id);
    await transaction(async (session) => {
      const room = await Room.findOneAndUpdate(
        { _id: id },
        { $inc: { revision: 1 } },
        { session },
      );
      if (!room) fail(404, "Không tìm thấy phòng.");
      if (await Showtime.exists({ roomId: id }).session(session))
        fail(409, "Không xóa phòng đã có lịch chiếu.");
      await Seat.deleteMany({ roomId: id }, { session });
      await Room.deleteOne({ _id: id }, { session });
      await audit(req.user._id, "room.deleted", room._id, session);
    });
    res.json({ ok: true });
  }),
);
adminRouter.patch(
  "/seats/:id",
  body(
    z
      .object({ type: z.enum(["standard", "vip"]), active: z.boolean() })
      .strict(),
  ),
  route(async (req, res) =>
    res.json(await editSeat(req.user._id, parseId(req.params.id), req.data)),
  ),
);
adminRouter.post(
  "/showtimes",
  body(showSchema),
  route(async (req, res) =>
    res.status(201).json(await saveShowtime(req.user._id, req.data)),
  ),
);
adminRouter.put(
  "/showtimes/:id",
  body(showSchema),
  route(async (req, res) =>
    res.json(
      await saveShowtime(req.user._id, req.data, parseId(req.params.id)),
    ),
  ),
);
adminRouter.delete(
  "/showtimes/:id",
  route(async (req, res) =>
    res.json(await deleteShowtime(req.user._id, parseId(req.params.id))),
  ),
);
adminRouter.patch(
  "/users/:id",
  body(z.object({ active: z.boolean() }).strict()),
  route(async (req, res) => {
    const id = parseId(req.params.id);
    if (same(id, req.user._id)) fail(400, "Không thể tự khóa tài khoản.");
    const user = await User.findOneAndUpdate(
      { _id: id, role: "customer" },
      { $set: req.data },
      { new: true },
    ).select("-passwordHash");
    if (!user) fail(404, "Không tìm thấy khách hàng.");
    if (!req.data.active) await Session.deleteMany({ userId: id });
    await Audit.create({
      userId: req.user._id,
      action: "user.status",
      entityId: user._id,
      details: req.data,
    });
    res.json(user);
  }),
);
adminRouter.post(
  "/check-in",
  body(z.object({ qr: z.string().min(30).max(100) }).strict()),
  route(async (req, res) =>
    res.json(
      await transaction(async (session) => {
        const ticket = await Ticket.findOne({
          qr: req.data.qr,
          status: "valid",
        }).session(session);
        if (!ticket) fail(409, "QR không hợp lệ hoặc vé đã sử dụng/hủy.");
        const show = await Showtime.findOne({
          _id: ticket.showtimeId,
          status: "active",
        }).session(session);
        if (
          !show ||
          Date.now() < +show.startAt - 3600000 ||
          Date.now() > +show.endAt
        )
          fail(
            409,
            "Chỉ soát vé trong khoảng 60 phút trước giờ chiếu đến hết phim.",
          );
        ticket.status = "used";
        ticket.usedAt = new Date();
        await ticket.save({ session });
        await audit(req.user._id, "ticket.checked-in", ticket._id, session);
        const seat = await ShowtimeSeat.findById(ticket.showtimeSeatId).session(
          session,
        );
        return {
          ok: true,
          ticketId: ticket._id,
          seat: seat.label,
          showtime: show.startAt,
        };
      }),
    ),
  ),
);
