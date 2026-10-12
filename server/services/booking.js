import { reserveSnacks, releaseSnacks, selectChanges, takeCredit, allocate, refundCredit, removeLines, fulfillSnacks, cancelLines, selectionKey, ensureChangeTime } from './concessions.js';
import mongoose from "mongoose";
import { randomBytes } from "node:crypto";
import { config, policy, vnpay, momo, paymentMethods } from "../config.js";
import {
  RevenueEntry,
  Cinema,
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
import {
  transaction,
  create,
  fail,
  same,
  audit,
  HttpError,
} from "../core.js";
import {
  createPaymentUrl,
  makeTxnRef,
  bankCodeFor,
} from "../payments/vnpay.js";
import { createPayment as createMomoPayment } from "../payments/momo.js";
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
      await releaseSnacks(o, session);
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
  ensureChangeTime(show?.startAt);
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
export async function hold(userId, { showtimeId, seatIds, idempotencyKey, snacks = [] }) {
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
        (existing.selectionKey || selectionKey()) !== selectionKey(snacks) ||
        items
          .map((x) => String(x.showtimeSeatId))
          .sort()
          .join() != [...seatIds].sort().join()
      )
        fail(409, "Khóa yêu cầu đã dùng cho nội dung khác.");
      return existing;
    }
    await lockCustomer(userId, session);
    const show = await lockShowtime(showtimeId, session);
    const _id = new mongoose.Types.ObjectId(),
      expiresAt = new Date(Date.now() + policy.holdMinutes * 60000);
    const seats = await holdSeats(seatIds, _id, expiresAt, showtimeId, session);
    const snackLines = await reserveSnacks(show.cinemaId, snacks, session);
    const snackTotal = snackLines.reduce((n,x)=>n+x.price*x.quantity,0);
    const order = await create(
      Order,
      {
        _id,
        userId,
        showtimeId,
        total: seats.reduce((n, s) => n + s.price, 0) + snackTotal,
        cinemaId: show.cinemaId, pickupDate: show.startAt.toLocaleDateString("en-CA",{timeZone:"Asia/Ho_Chi_Minh"}),
        snacks: snackLines, snackTotal, selectionKey: selectionKey(snacks),
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
export async function exchange(userId, ticketId, { seatId, idempotencyKey, snacks = [], snackChanges = [] }) {
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
        (existing.selectionKey || selectionKey()) !== selectionKey(snacks,snackChanges) ||
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

    const _id = new mongoose.Types.ObjectId(),
      expiresAt = new Date(Date.now() + policy.holdMinutes * 60000);
    await holdSeats([seatId], _id, expiresAt, seat.showtimeId, session);
    const changes = await selectChanges(ticket, snackChanges, _id, session);
    const oldSnackTotal = changes.reduce((n,x)=>n+x.price*x.quantity,0);
    const snackLines = await reserveSnacks(target.cinemaId,snacks,session,changes);
    const snackTotal = snackLines.reduce((n,x)=>n+x.price*x.quantity,0);
    const difference = seat.price + snackTotal - ticket.currentValue - oldSnackTotal;
    if(difference<0 && config.NODE_ENV==="production")fail(503,"Hoàn tiền mô phỏng chỉ dùng trong môi trường thử nghiệm.");
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
        cinemaId:target.cinemaId,pickupDate:target.startAt.toLocaleDateString("en-CA",{timeZone:"Asia/Ho_Chi_Minh"}),
        snacks:snackLines,snackChanges:changes,snackTotal,oldSnackTotal,selectionKey:selectionKey(snacks,snackChanges),
        exchangeTicketId: ticketId,
        oldShowtimeSeatId: ticket.showtimeSeatId,
        expiresAt,
        idempotencyKey,
        policy: {...ticket.policy,changeCutoffHours:12},
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
        policy: {...ticket.policy,changeCutoffHours:12},
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
        reportVersion: 1,
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
// Đơn còn thanh toán được không (kiểm tra trước khi thu tiền).
async function assertPayable(order, session) {
  if (order.status !== "pending" || order.expiresAt <= now())
    fail(409, "Đơn đã hết thời gian giữ ghế.");
  if (order.kind !== "snack") await lockShowtime(order.showtimeId, session);
  const items = await OrderItem.find({ orderId: order._id }).session(session);
  const held = await ShowtimeSeat.countDocuments({
    orderId: order._id,
    status: "held",
    holdUntil: { $gt: now() },
  }).session(session);
  if (held !== items.length) fail(409, "Thời gian giữ ghế đã hết.");
  return items;
}
// Phát hành vé sau khi đã thu tiền. Dùng chung cho demo và cổng thanh toán.
// Nâng giao dịch thất bại lên thành công trong cùng transaction phát hành vé.
// Giữ nguyên _id; callback lặp lại được chặn trước khi gọi hàm này.
async function saveSuccessfulPayment(data, session) {
  const previous = await Payment.findOneAndUpdate(
    { reference: data.reference, status: "failed", orderId: data.orderId },
    { $set: data },
    { new: true, runValidators: true, session },
  );
  return previous || create(Payment, data, session);
}
async function settlePaid(order, items, { provider, reference }, session) {
  const userId = order.userId,
    orderId = order._id;
  const payment = await saveSuccessfulPayment(
    {
      userId,
      orderId,
      amount: order.total,
      status: "success",
      provider,
      reference,
      purpose: order.kind,
    },
    session,
  );
  const funds = [{paymentId:payment._id,amount:order.total}];
  if (!order.cinemaId && order.showtimeId) order.cinemaId = (await Showtime.findById(order.showtimeId).session(session)).cinemaId;
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
      await allocate(funds,{ticketId:ticket._id},item.price,session);
      await ShowtimeSeat.updateOne(
        { _id: item.showtimeSeatId, orderId },
        {
          $set: { status: "booked", ticketId: ticket._id },
          $unset: { holdUntil: 1 },
        },
        { session },
      );
    }
  } else if (order.kind === "exchange") {
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
    const sourceShow = await Showtime.findById(ticket.showtimeId).session(session);
    const oldValue = ticket.currentValue;
    funds.push(...await takeCredit({ticketId:ticket._id,snackLineId:{$exists:false}}, oldValue, session));
    funds.push(...await removeLines(order,session));
    await allocate(funds,{ticketId:ticket._id},order.newValue,session);
    await create(RevenueEntry,{orderId,cinemaId:sourceShow.cinemaId,description:'Giá trị chuyển khỏi vé/bỏng nước cũ',ticketNet:-oldValue,snackNet:-(order.oldSnackTotal||0)},session);
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
  await fulfillSnacks(order,funds,session);
  const returned = await refundCredit(funds, order.exchangeTicketId ? {ticketId:order.exchangeTicketId} : {}, order._id,session);
  if (returned !== (order.refundAmount || 0)) fail(409,'Chênh lệch hoàn tiền không khớp.');
  await create(RevenueEntry,{orderId,paymentId:payment._id,cinemaId:order.cinemaId,
    description: order.kind === 'exchange' ? 'Đổi vé và bỏng nước' : 'Thanh toán đơn',
    ticketNet: order.kind === 'exchange' ? order.newValue : order.total-(order.snackTotal||0),
    snackNet:order.snackTotal||0,received:order.total,returned},session);
  await User.updateOne(
    { _id: userId },
    { $inc: { netSpend: order.total - returned } },
    { session },
  );
  order.status = "paid";
  await order.save({ session });
  await audit(userId, `payment.${provider}.success`, order._id, session);
  return order;
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
    const items = await assertPayable(order, session);
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
    return settlePaid(
      order,
      items,
      { provider: "demo", reference: `demo:${orderId}` },
      session,
    );
  });
}
// Bước 1 của thanh toán qua cổng: trả về đường dẫn để chuyển khách sang VNPay.
export async function startGatewayPayment(userId, orderId, method, ipAddr) {
  if (config.PAYMENT_MODE !== "online")
    fail(503, "Thanh toán trực tuyến chưa được cấu hình. Liên hệ quản trị viên.");
  if (!paymentMethods.includes(method))
    fail(400, "Phương thức thanh toán này chưa được bật.");
  const order = await Order.findOne({ _id: orderId, userId });
  if (!order) fail(404, "Không tìm thấy đơn.");
  if (order.status === "paid") return { paid: true };
  if (order.total === 0) {
    // Đổi vé không phát sinh thêm tiền: không cần qua cổng thanh toán.
    await transaction(async (session) => {
      const fresh = await Order.findOne({ _id: orderId, userId }).session(
        session,
      );
      if (fresh.status === "paid") return;
      const items = await assertPayable(fresh, session);
      await settlePaid(
        fresh,
        items,
        { provider: "none", reference: `free:${orderId}` },
        session,
      );
    });
    return { paid: true };
  }
  if (order.status !== "pending" || order.expiresAt <= now())
    fail(409, "Đơn đã hết thời gian giữ ghế.");
  const [held, count] = await Promise.all([
    ShowtimeSeat.countDocuments({
      orderId: order._id,
      status: "held",
      holdUntil: { $gt: now() },
    }),
    OrderItem.countDocuments({ orderId: order._id }),
  ]);
  if (held !== count) fail(409, "Thời gian giữ ghế đã hết.");
  await Order.updateOne({ _id: order._id }, { $set: { paymentMethod: method } });
  const txnRef = makeTxnRef(String(order._id));
  const orderInfo = `Thanh toan ve CineGo ${order._id}`;
  if (method === "momo") {
    // MoMo tạo giao dịch bằng cuộc gọi từ server; payUrl trả về để chuyển khách sang.
    try {
      const { payUrl } = await createMomoPayment(momo, {
        txnRef,
        amount: order.total,
        orderInfo,
      });
      return { paymentUrl: payUrl };
    } catch (e) {
      console.error(
        JSON.stringify({
          level: "error",
          path: "momo-create",
          message: String(e.message).slice(0, 200),
        }),
      );
      fail(502, "Không tạo được giao dịch MoMo. Vui lòng thử lại sau.");
    }
  }
  return {
    paymentUrl: createPaymentUrl(vnpay, {
      txnRef,
      amount: order.total,
      orderInfo,
      ipAddr,
      bankCode: bankCodeFor(method),
      expiresAt: order.expiresAt,
    }),
  };
}
// Đã thu tiền nhưng không phát hành được vé (đơn hết hạn, ghế mất, trả trùng...).
// Ghi lại để quản trị viên đối soát và hoàn tiền thủ công.
async function recordUnfulfilled(order, r, purpose, session) {
  await saveSuccessfulPayment(
    {
      userId: order.userId,
      orderId: order._id,
      amount: order.total,
      status: "success",
      provider: r.provider,
      reference: r.txnRef,
      purpose,
    },
    session,
  );
  await audit(order.userId, `payment.${purpose}`, order._id, session, {
    reference: r.txnRef,
    amount: r.amount,
  });
}
// Bước 2: xử lý kết quả cổng thanh toán gửi về (IPN hoặc return URL, đã kiểm tra chữ ký).
// Gọi nhiều lần với cùng một giao dịch vẫn an toàn.
// Trả về { code } theo mã RspCode mà VNPay yêu cầu cho IPN (MoMo dùng lại để phân loại).
export async function handleGatewayResult(r) {
  const run = () =>
    transaction(async (session) => {
      const order = r.orderId
        ? await Order.findById(r.orderId).session(session)
        : null;
      if (!order) return { code: "01" };
      if (order.total !== r.amount) return { code: "04", order };
      const seen = await Payment.findOne({ reference: r.txnRef }).session(
        session,
      );
      if (!r.success) {
        if (!seen && order.status === "pending")
          await create(
            Payment,
            {
              userId: order.userId,
              orderId: order._id,
              amount: order.total,
              status: "failed",
              provider: r.provider,
              reference: r.txnRef,
              purpose: order.kind,
            },
            session,
          );
        return { code: "00", order };
      }
      if (seen?.status === "success") return { code: "02", order };
      if (order.status === "paid") {
        await recordUnfulfilled(order, r, "duplicate", session);
        return { code: "00", order };
      }
      const items = await OrderItem.find({ orderId: order._id }).session(
        session,
      );
      const held =
        order.status === "pending"
          ? await ShowtimeSeat.countDocuments({
              orderId: order._id,
              status: "held",
            }).session(session)
          : 0;
      if (order.status !== "pending" || order.expiresAt <= now() || held !== items.length) {
        await recordUnfulfilled(order, r, "late-unfulfilled", session);
        return { code: "00", order, late: true };
      }
      if (order.kind !== "snack") await lockShowtime(order.showtimeId, session);
      await settlePaid(
        order,
        items,
        { provider: r.provider, reference: r.txnRef },
        session,
      );
      return { code: "00", order };
    });
  try {
    return await run();
  } catch (e) {
    if (!(e instanceof HttpError) || !r.success) throw e;
    // Tiền đã thu nhưng không phát hành được vé (ví dụ suất chiếu bị hủy).
    return transaction(async (session) => {
      const order = await Order.findById(r.orderId).session(session);
      if (!(await Payment.exists({ reference: r.txnRef, status: "success" }).session(session)))
        await recordUnfulfilled(order, r, "late-unfulfilled", session);
      return { code: "00", order, late: true };
    });
  }
}
export const handleVnpayResult = handleGatewayResult;
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
    await releaseSnacks(order, session);
    order.status = "cancelled";
    await order.save({ session });
    await audit(userId, "order.cancelled", order._id, session);
    return order;
  });
}
export async function cancelTicket(userId, ticketId, snackChanges = []) {
  // Hoàn tiền hiện vẫn là mô phỏng (chưa gọi API hoàn tiền của VNPay).
  if (config.PAYMENT_MODE === "disabled" || config.NODE_ENV === "production")
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
        policy: {...ticket.policy,changeCutoffHours:12},
      },
      session,
    );
    const changes = await selectChanges(ticket,snackChanges,null,session);
    await cancelLines(userId,changes,session,{ticket,requestId:request._id});
    await refundTicket(ticket, amount, request._id, session);
    const show = await Showtime.findById(ticket.showtimeId).session(session);
    await create(RevenueEntry,{orderId:ticket.orderId,cinemaId:show.cinemaId,description:'Hủy vé (hoàn mô phỏng)',ticketNet:-amount,returned:amount},session);
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

export async function holdSnackOrder(userId,{cinemaId,pickupDate,snacks,idempotencyKey}) {
  return transaction(async session=>{
    const existing=await Order.findOne({userId,idempotencyKey}).session(session);
    if(existing) {
      if(existing.kind!=='snack'||!same(existing.cinemaId,cinemaId)||existing.pickupDate!==pickupDate||existing.selectionKey!==selectionKey(snacks)) fail(409,'Khóa yêu cầu đã dùng cho nội dung khác.');
      return existing;
    }
    await lockCustomer(userId,session);
    const today=new Date().toLocaleDateString('en-CA',{timeZone:'Asia/Ho_Chi_Minh'});
    if(pickupDate<today)fail(400,'Ngày nhận không được ở quá khứ.');
    const lines=await reserveSnacks(cinemaId,snacks,session);
    const total=lines.reduce((n,x)=>n+x.price*x.quantity,0);
    return create(Order,{userId,kind:'snack',cinemaId,pickupDate,snacks:lines,snackTotal:total,total,
      selectionKey:selectionKey(snacks),idempotencyKey,policy,expiresAt:new Date(Date.now()+policy.holdMinutes*60000)},session);
  });
}
