import { Router } from "express";
import { z } from "zod";
import { rateLimit } from "express-rate-limit";
import {
  Order,
  OrderItem,
  Ticket,
  Showtime,
  Movie,
  Cinema,
  ShowtimeSeat,
  Payment,
  Refund,
  ChatRoom,
  ChatBan,
  Membership,
  Message,
  ChangeRequest,
} from "../models.js";
import { requireAuth } from "../auth.js";
import {
  route,
  body,
  objectId,
  parseId,
  fail,
  transaction,
  create,
  audit,
} from "../core.js";
import {
  hold,
  exchange,
  payDemo,
  cancelOrder,
  cancelTicket,
} from "../services/booking.js";
export const customerRouter = Router();
customerRouter.use(requireAuth);
const key = z.string().uuid();
const holdLimiter = rateLimit({
  windowMs: 60000,
  limit: 20,
  keyGenerator: (req) => String(req.user._id),
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Bạn thao tác quá nhanh. Vui lòng thử lại sau." },
});
customerRouter.post(
  "/orders",
  holdLimiter,
  body(
    z
      .object({
        showtimeId: objectId,
        seatIds: z
          .array(objectId)
          .min(1)
          .max(8)
          .refine((a) => new Set(a).size === a.length),
        idempotencyKey: key,
      })
      .strict(),
  ),
  route(async (req, res) => {
    const pending = await Order.countDocuments({
      userId: req.user._id,
      status: "pending",
      expiresAt: { $gt: new Date() },
    });
    if (
      pending >= 3 &&
      !(await Order.exists({
        userId: req.user._id,
        idempotencyKey: req.data.idempotencyKey,
      }))
    )
      fail(429, "Bạn đang có 3 đơn chờ. Hãy hoàn tất hoặc hủy đơn cũ.");
    res.status(201).json(await hold(req.user._id, req.data));
  }),
);
customerRouter.get(
  "/orders",
  route(async (req, res) =>
    res.json(
      await Order.find({ userId: req.user._id })
        .sort({ createdAt: -1 })
        .limit(100)
        .lean(),
    ),
  ),
);
customerRouter.get(
  "/orders/:id",
  route(async (req, res) => {
    const order = await Order.findOne({
      _id: parseId(req.params.id),
      userId: req.user._id,
    }).lean();
    if (!order) fail(404, "Không tìm thấy đơn.");
    const items = await OrderItem.find({ orderId: order._id }).lean();
    const seats = await ShowtimeSeat.find({
      _id: { $in: items.map((i) => i.showtimeSeatId) },
    }).lean();
    const show = await Showtime.findById(order.showtimeId).lean();
    const [movie, cinema, payments, requests] = await Promise.all([
      Movie.findById(show.movieId).lean(),
      Cinema.findById(show.cinemaId).lean(),
      Payment.find({ orderId: order._id }).select("-reference").lean(),
      ChangeRequest.find({ orderId: order._id }).lean(),
    ]);
    res.json({ order, items, seats, show, movie, cinema, payments, requests });
  }),
);
customerRouter.post(
  "/orders/:id/pay-demo",
  body(z.object({ outcome: z.enum(["success", "failed"]) }).strict()),
  route(async (req, res) =>
    res.json(
      await payDemo(req.user._id, parseId(req.params.id), req.data.outcome),
    ),
  ),
);
customerRouter.post(
  "/orders/:id/cancel",
  route(async (req, res) =>
    res.json(await cancelOrder(req.user._id, parseId(req.params.id))),
  ),
);
customerRouter.get(
  "/tickets",
  route(async (req, res) => {
    const tickets = await Ticket.find({ userId: req.user._id })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    const shows = await Showtime.find({
      _id: { $in: tickets.map((t) => t.showtimeId) },
    }).lean();
    const [movies, cinemas, seats, refunds] = await Promise.all([
      Movie.find({ _id: { $in: shows.map((s) => s.movieId) } }).lean(),
      Cinema.find({ _id: { $in: shows.map((s) => s.cinemaId) } }).lean(),
      ShowtimeSeat.find({
        _id: { $in: tickets.map((t) => t.showtimeSeatId) },
      }).lean(),
      Refund.find({ ticketId: { $in: tickets.map((t) => t._id) } })
        .select("-paymentId")
        .lean(),
    ]);
    res.json({ tickets, shows, movies, cinemas, seats, refunds });
  }),
);
customerRouter.post(
  "/tickets/:id/cancel",
  route(async (req, res) =>
    res.json(await cancelTicket(req.user._id, parseId(req.params.id))),
  ),
);
customerRouter.post(
  "/tickets/:id/exchange",
  holdLimiter,
  body(z.object({ seatId: objectId, idempotencyKey: key }).strict()),
  route(async (req, res) =>
    res
      .status(201)
      .json(await exchange(req.user._id, parseId(req.params.id), req.data)),
  ),
);
async function chatAccess(userId, showtimeId, session) {
  const tickets = await Ticket.find({
    userId,
    showtimeId,
    status: "valid",
  }).session(session || null);
  if (!tickets.length)
    fail(403, "Cần vé hợp lệ của suất chiếu để tham gia phòng chat.");
  const show = await Showtime.findOne({
    _id: showtimeId,
    status: "active",
    endAt: { $gt: new Date() },
  }).session(session || null);
  if (!show) fail(403, "Phòng chat đã đóng sau suất chiếu.");
  return tickets;
}
customerRouter.post(
  "/chat/:id/join",
  route(async (req, res) => {
    const showtimeId = parseId(req.params.id);
    res.json(
      await transaction(async (session) => {
        const tickets = await chatAccess(req.user._id, showtimeId, session);
        await Ticket.updateOne(
          { _id: tickets[0]._id },
          { $set: { updatedAt: new Date() } },
          { session },
        );
        const room = await ChatRoom.findOneAndUpdate(
          { showtimeId },
          { $setOnInsert: { showtimeId } },
          { upsert: true, new: true, session },
        );
        if (room.locked) fail(403, "Phòng chat đang bị quản trị viên khóa.");
        if (await ChatBan.exists({chatRoomId: room._id, userId: req.user._id}).session(session))
          fail(403, "Bạn đã bị chặn trong phòng chat này.");
        await ChatRoom.updateOne({_id: room._id}, {$inc: {revision: 1}}, {session});
        await Membership.updateOne(
          { userId: req.user._id, chatRoomId: room._id },
          { $setOnInsert: { userId: req.user._id, chatRoomId: room._id } },
          { upsert: true, session },
        );
        return room;
      }),
    );
  }),
);
customerRouter.delete(
  "/chat/:id/membership",
  route(async (req, res) => {
    const room = await ChatRoom.findOne({ showtimeId: parseId(req.params.id) });
    if (room)
      await Membership.deleteOne({
        userId: req.user._id,
        chatRoomId: room._id,
      });
    res.json({ ok: true });
  }),
);
async function roomAccess(req, session) {
  await chatAccess(req.user._id, parseId(req.params.id), session);
  const room = await ChatRoom.findOne({ showtimeId: req.params.id }).session(
    session || null,
  );
  const member =
    room &&
    (await Membership.findOne({
      userId: req.user._id,
      chatRoomId: room._id,
    }).session(session || null));
  if (!member) fail(403, "Hãy chọn tham gia phòng chat trước.");
  if (await ChatBan.exists({chatRoomId: room._id, userId: req.user._id}).session(session || null))
    fail(403, "Bạn đã bị chặn trong phòng chat này.");
  return { room, member };
}
customerRouter.get(
  "/chat/:id/messages",
  route(async (req, res) => {
    const { room } = await roomAccess(req);
    const msgs = await Message.find({ chatRoomId: room._id, hidden: {$ne: true} })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    res.json(msgs.reverse());
  }),
);
const chatLimiter = rateLimit({
  windowMs: 60000,
  limit: 20,
  keyGenerator: (req) => String(req.user._id),
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Bạn gửi quá nhanh. Thử lại sau một phút." },
});
customerRouter.post(
  "/chat/:id/messages",
  chatLimiter,
  body(z.object({ body: z.string().trim().min(1).max(1000) }).strict()),
  route(async (req, res) => {
    res.status(201).json(
      await transaction(async (session) => {
        const { room, member } = await roomAccess(req, session);
        if (room.locked) fail(403, "Phòng chat đang bị quản trị viên khóa.");
        await ChatRoom.updateOne({_id: room._id}, {$inc: {revision: 1}}, {session});
        await Membership.updateOne(
          { _id: member._id },
          { $set: { updatedAt: new Date() } },
          { session },
        );
        const ticket = await Ticket.findOne({
          userId: req.user._id,
          showtimeId: req.params.id,
          status: "valid",
        }).session(session);
        if (!ticket) fail(403, "Vé không còn hợp lệ.");
        await ticket.updateOne(
          { $set: { updatedAt: new Date() } },
          { session },
        );
        return create(
          Message,
          {
            chatRoomId: room._id,
            userId: req.user._id,
            name: req.user.name,
            body: req.data.body,
          },
          session,
        );
      }),
    );
  }),
);
