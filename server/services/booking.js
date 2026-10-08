import mongoose from "mongoose";
import { randomBytes } from "node:crypto";
import { config, policy } from "../config.js";
import {
  Order,
  OrderItem,
  Showtime,
  ShowtimeSeat,
  Ticket,
  Payment,
  Allocation,
  Refund,
  ChangeRequest,
  User,
  Membership,
  ChatRoom,
} from "../models.js";
import { transaction, create, fail, same, audit } from "../core.js";
const now = () => new Date();
export async function releaseExpired() {
  return transaction(async (session) => {
    const orders = await Order.find({
      status: "pending",
      expiresAt: { $lte: now() },
    })
      .limit(100)
      .session(session);
    for (const o of orders) {
      await ShowtimeSeat.updateMany(
        { orderId: o._id, status: "held" },
        { $set: { status: "available" }, $unset: { orderId: 1, holdUntil: 1 } },
        { session },
      );
      o.status = "expired";
      await o.save({ session });
      await ChangeRequest.updateMany(
        { orderId: o._id, status: "pending" },
        { $set: { status: "failed" } },
        { session },
      );
      await audit(o.userId, "order.expired", o._id, session);
    }
  });
}
async function lockShowtime(id, session) {
  const show = await Showtime.findOneAndUpdate(
    { _id: id, status: "active", startAt: { $gt: now() } },
    { $inc: { revision: 1 } },
    { new: true, session },
  );
  if (!show) fail(409, "Suất chiếu không còn mở đặt vé.");
  return show;
}
async function checkChange(ticket, session) {
  if (!ticket || ticket.status !== "valid")
    fail(409, "Vé không còn hiệu lực để hủy/đổi.");
  const show = await Showtime.findById(ticket.showtimeId).session(session);
  if (
    !show ||
    show.startAt.getTime() - Date.now() <
      ticket.policy.changeCutoffHours * 3600000
  )
    fail(
      409,
      `Chỉ hủy/đổi trước giờ chiếu ít nhất ${ticket.policy.changeCutoffHours} giờ.`,
    );
  return show;
}
async function holdSeats(ids, orderId, expiresAt, showtimeId, session) {
  const seats = await ShowtimeSeat.find({
    _id: { $in: ids },
    showtimeId,
  }).session(session);
  if (seats.length !== ids.length) fail(400, "Ghế không thuộc suất chiếu.");
  const r = await ShowtimeSeat.updateMany(
    {
      _id: { $in: ids },
      showtimeId,
      $or: [
        { status: "available" },
        { status: "held", holdUntil: { $lte: now() } },
      ],
    },
    {
      $set: { status: "held", orderId, holdUntil: expiresAt },
      $unset: { ticketId: 1 },
    },
    { session },
  );
  if (r.modifiedCount !== ids.length)
    fail(409, "Một ghế vừa được người khác giữ hoặc đặt. Vui lòng chọn lại.");
  return seats;
}
async function lockCustomer(userId, session) {
  const user = await User.findOneAndUpdate(
    { _id: userId, active: true },
    { $inc: { bookingRevision: 1 } },
    { new: true, session },
  );
  if (!user) fail(403, "Tài khoản không còn hoạt động.");
  const pending = await Order.countDocuments({
    userId,
    status: "pending",
    expiresAt: { $gt: now() },
  }).session(session);
  if (pending >= 3)
    fail(429, "Bạn đang có 3 đơn chờ. Hãy hoàn tất hoặc hủy đơn cũ.");
}
export async function hold(userId, { showtimeId, seatIds, idempotencyKey }) {
  return transaction(async (session) => {
    const existing = await Order.findOne({ userId, idempotencyKey }).session(
      session,
    );
    if (existing) {
      const items = await OrderItem.find({ orderId: existing._id }).session(
        session,
      );
      if (
        !same(existing.showtimeId, showtimeId) ||
        existing.kind !== "booking" ||
        items
          .map((x) => String(x.showtimeSeatId))
          .sort()
          .join() != [...seatIds].sort().join()
      )
        fail(409, "Khóa yêu cầu đã dùng cho nội dung khác.");
      return existing;
    }
    await lockCustomer(userId, session);
    await lockShowtime(showtimeId, session);
    const _id = new mongoose.Types.ObjectId(),
      expiresAt = new Date(Date.now() + policy.holdMinutes * 60000);
    const seats = await holdSeats(seatIds, _id, expiresAt, showtimeId, session);
    const order = await create(
      Order,
      {
        _id,
        userId,
        showtimeId,
        total: seats.reduce((n, s) => n + s.price, 0),
        expiresAt,
        idempotencyKey,
        policy,
      },
      session,
    );
    for (const s of seats)
      await create(
        OrderItem,
        { orderId: _id, showtimeSeatId: s._id, price: s.price },
        session,
      );
    await audit(userId, "order.held", _id, session);
    return order;
  });
}
export async function exchange(userId, ticketId, { seatId, idempotencyKey }) {
  return transaction(async (session) => {
    const existing = await Order.findOne({ userId, idempotencyKey }).session(
      session,
    );
    if (existing) {
      const item = await OrderItem.findOne({ orderId: existing._id }).session(
        session,
      );
      if (
        existing.kind !== "exchange" ||
        !same(existing.exchangeTicketId, ticketId) ||
        !same(item?.showtimeSeatId, seatId)
      )
        fail(409, "Khóa yêu cầu đã được sử dụng.");
      return existing;
    }
    await lockCustomer(userId, session);
    const ticket = await Ticket.findOne({ _id: ticketId, userId }).session(
      session,
    );
    await checkChange(ticket, session);
    if (same(ticket.showtimeSeatId, seatId)) fail(400, "Hãy chọn ghế mới.");
    const pending = await Order.exists({
      exchangeTicketId: ticketId,
      status: "pending",
      expiresAt: { $gt: now() },
    }).session(session);
    if (pending)
      fail(409, "Vé đang có yêu cầu đổi. Hoàn tất hoặc hủy yêu cầu trước.");
    const seat = await ShowtimeSeat.findById(seatId).session(session);
    if (!seat) fail(404, "Không tìm thấy ghế.");
    const target = await lockShowtime(seat.showtimeId, session);
    const source = await Showtime.findById(ticket.showtimeId).session(session);
    if (!same(source.movieId, target.movieId))
      fail(400, "Chỉ đổi suất chiếu của cùng một phim.");
    const _id = new mongoose.Types.ObjectId(),
      expiresAt = new Date(Date.now() + policy.holdMinutes * 60000);
    await holdSeats([seatId], _id, expiresAt, seat.showtimeId, session);
    const difference = seat.price - ticket.currentValue;
    const order = await create(
      Order,
      {
        _id,
        userId,
        kind: "exchange",
        showtimeId: seat.showtimeId,
        total: Math.max(difference, 0),
        refundAmount: Math.max(-difference, 0),
        newValue: seat.price,
        exchangeTicketId: ticketId,
        oldShowtimeSeatId: ticket.showtimeSeatId,
        expiresAt,
        idempotencyKey,
        policy: ticket.policy,
      },
      session,
    );
    await create(
      OrderItem,
      { orderId: _id, showtimeSeatId: seatId, price: seat.price },
      session,
    );
    await create(
      ChangeRequest,
      {
        userId,
        ticketId,
        type: "exchange",
        status: "pending",
        oldSeatId: ticket.showtimeSeatId,
        newSeatId: seatId,
        orderId: _id,
        difference,
        policy: ticket.policy,
      },
      session,
    );
    await ticket.updateOne({ $set: { updatedAt: now() } }, { session });
    await audit(userId, "exchange.held", _id, session);
    return order;
  });
}
async function refundTicket(ticket, amount, requestId, session) {
  let remaining = amount;
  const allocations = await Allocation.find({ ticketId: ticket._id })
    .sort({ createdAt: -1 })
    .session(session);
  for (const a of allocations) {
    const portion = Math.min(remaining, a.amount - a.refunded);
    if (portion <= 0) continue;
    await create(
      Refund,
      {
        ticketId: ticket._id,
        paymentId: a.paymentId,
        requestId,
        amount: portion,
        status: "success",
        provider: "demo",
      },
      session,
    );
    a.refunded += portion;
    await a.save({ session });
    remaining -= portion;
  }
  if (remaining !== 0) fail(409, "Khoản hoàn vượt số tiền đã thu.");
  if (amount)
    await User.updateOne(
      { _id: ticket.userId },
      { $inc: { netSpend: -amount } },
      { session },
    );
}
async function revokeChat(userId, showtimeId, session) {
  const remaining = await Ticket.exists({
    userId,
    showtimeId,
    status: "valid",
  }).session(session);
  if (!remaining) {
    const room = await ChatRoom.findOne({ showtimeId }).session(session);
    if (room)
      await Membership.deleteMany(
        { userId, chatRoomId: room._id },
        { session },
      );
  }
}
export async function payDemo(userId, orderId, outcome) {
  if (config.PAYMENT_MODE !== "demo" || config.NODE_ENV === "production")
    fail(503, "Thanh toán chưa được cấu hình. Liên hệ quản trị viên.");
  return transaction(async (session) => {
    const order = await Order.findOne({ _id: orderId, userId }).session(
      session,
    );
    if (!order) fail(404, "Không tìm thấy đơn.");
    if (order.status === "paid") return order;
    if (order.status !== "pending" || order.expiresAt <= now())
      fail(409, "Đơn đã hết thời gian giữ ghế.");
    await lockShowtime(order.showtimeId, session);
    const items = await OrderItem.find({ orderId }).session(session);
    const held = await ShowtimeSeat.countDocuments({
      orderId,
      status: "held",
      holdUntil: { $gt: now() },
    }).session(session);
    if (held !== items.length) fail(409, "Thời gian giữ ghế đã hết.");
    if (outcome === "failed") {
      await create(
        Payment,
        {
          userId,
          orderId,
          amount: order.total,
          status: "failed",
          reference: randomBytes(24).toString("hex"),
          purpose: order.kind,
        },
        session,
      );
      await audit(userId, "payment.failed", order._id, session);
      return order;
    }
    const payment = await create(
      Payment,
      {
        userId,
        orderId,
        amount: order.total,
        status: "success",
        reference: `demo:${orderId}`,
        purpose: order.kind,
      },
      session,
    );
    if (order.kind === "booking") {
      for (const item of items) {
        const ticket = await create(
          Ticket,
          {
            userId,
            orderId,
            orderItemId: item._id,
            showtimeId: order.showtimeId,
            showtimeSeatId: item.showtimeSeatId,
            currentValue: item.price,
            qr: randomBytes(32).toString("base64url"),
            policy: order.policy,
          },
          session,
        );
        await create(
          Allocation,
          { ticketId: ticket._id, paymentId: payment._id, amount: item.price },
          session,
        );
        await ShowtimeSeat.updateOne(
          { _id: item.showtimeSeatId, orderId },
          {
            $set: { status: "booked", ticketId: ticket._id },
            $unset: { holdUntil: 1 },
          },
          { session },
        );
      }
    } else {
      const ticket = await Ticket.findOne({
        _id: order.exchangeTicketId,
        userId,
      }).session(session);
      await checkChange(ticket, session);
      if (!same(ticket.showtimeSeatId, order.oldShowtimeSeatId))
        fail(409, "Vé đã thay đổi. Hãy tạo yêu cầu mới.");
      const oldShow = ticket.showtimeId;
      const request = await ChangeRequest.findOne({
        orderId,
        status: "pending",
      }).session(session);
      if (!request) fail(409, "Yêu cầu đổi không còn hiệu lực.");
      if (order.total > 0)
        await create(
          Allocation,
          { ticketId: ticket._id, paymentId: payment._id, amount: order.total },
          session,
        );
      if (order.refundAmount)
        await refundTicket(ticket, order.refundAmount, request._id, session);
      await ShowtimeSeat.updateOne(
        { _id: ticket.showtimeSeatId, ticketId: ticket._id },
        {
          $set: { status: "available" },
          $unset: { orderId: 1, ticketId: 1, holdUntil: 1 },
        },
        { session },
      );
      ticket.showtimeId = order.showtimeId;
      ticket.showtimeSeatId = items[0].showtimeSeatId;
      ticket.currentValue = order.newValue;
      ticket.qr = randomBytes(32).toString("base64url");
      await ticket.save({ session });
      await ShowtimeSeat.updateOne(
        { _id: ticket.showtimeSeatId, orderId },
        {
          $set: { status: "booked", ticketId: ticket._id },
          $unset: { holdUntil: 1 },
        },
        { session },
      );
      request.status = "completed";
      await request.save({ session });
      await revokeChat(userId, oldShow, session);
    }
    await User.updateOne(
      { _id: userId },
      { $inc: { netSpend: order.total } },
      { session },
    );
    order.status = "paid";
    await order.save({ session });
    await audit(userId, "payment.demo.success", order._id, session);
    return order;
  });
}
export async function cancelOrder(userId, orderId) {
  return transaction(async (session) => {
    const order = await Order.findOne({ _id: orderId, userId }).session(
      session,
    );
    if (!order) fail(404, "Không tìm thấy đơn.");
    if (order.status === "cancelled") return order;
    if (order.status !== "pending") fail(409, "Chỉ hủy đơn chưa thanh toán.");
    await ShowtimeSeat.updateMany(
      { orderId, status: "held" },
      { $set: { status: "available" }, $unset: { orderId: 1, holdUntil: 1 } },
      { session },
    );
    await ChangeRequest.updateMany(
      { orderId, status: "pending" },
      { $set: { status: "failed" } },
      { session },
    );
    order.status = "cancelled";
    await order.save({ session });
    await audit(userId, "order.cancelled", order._id, session);
    return order;
  });
}
export async function cancelTicket(userId, ticketId) {
  if (config.PAYMENT_MODE !== "demo" || config.NODE_ENV === "production")
    fail(503, "Dịch vụ hoàn tiền chưa được cấu hình.");
  return transaction(async (session) => {
    const ticket = await Ticket.findOne({ _id: ticketId, userId }).session(
      session,
    );
    if (ticket?.status === "cancelled") return ticket;
    await checkChange(ticket, session);
    if (
      await Order.exists({
        exchangeTicketId: ticketId,
        status: "pending",
        expiresAt: { $gt: now() },
      }).session(session)
    )
      fail(409, "Hãy hủy yêu cầu đổi đang chờ trước.");
    const amount = Math.floor(
      (ticket.currentValue * ticket.policy.refundPercent) / 100,
    );
    const request = await create(
      ChangeRequest,
      {
        userId,
        ticketId,
        type: "cancel",
        status: "completed",
        oldSeatId: ticket.showtimeSeatId,
        difference: -amount,
        policy: ticket.policy,
      },
      session,
    );
    await refundTicket(ticket, amount, request._id, session);
    ticket.status = "cancelled";
    await ticket.save({ session });
    await ShowtimeSeat.updateOne(
      { _id: ticket.showtimeSeatId, ticketId },
      {
        $set: { status: "available" },
        $unset: { orderId: 1, ticketId: 1, holdUntil: 1 },
      },
      { session },
    );
    await revokeChat(userId, ticket.showtimeId, session);
    await audit(userId, "ticket.cancelled", ticket._id, session, {
      refund: amount,
    });
    return ticket;
  });
}
