import { Router } from "express";
import { config, vnpay, momo, paymentMethods } from "../config.js";
import * as vnp from "../payments/vnpay.js";
import * as mm from "../payments/momo.js";
import { handleGatewayResult } from "../services/booking.js";
import { Order } from "../models.js";

// Router này được gắn TRƯỚC authenticate/csrf trong app.js vì cổng thanh toán
// gọi vào không có cookie đăng nhập; độ tin cậy dựa hoàn toàn vào chữ ký.
export const paymentsRouter = Router();
const notEnabled = (res) =>
  res.status(404).json({ message: "Cổng thanh toán chưa được bật." });
paymentsRouter.use((req, res, next) => {
  res.set("Cache-Control", "no-store");
  if (config.PAYMENT_MODE !== "online") return notEnabled(res);
  next();
});
const enabled = (method) => (req, res, next) =>
  paymentMethods.includes(method) ? next() : notEnabled(res);
const log = (level, path, extra = {}) =>
  console[level === "error" ? "error" : "warn"](
    JSON.stringify({ level, path, ...extra }),
  );

// Trình duyệt của khách quay lại. Cookie SameSite=Strict không được gửi ở
// request này nên route không đòi đăng nhập; chỉ xử lý rồi chuyển hướng.
const appBase = () => new URL(vnpay.returnUrl || momo.returnUrl).origin;
async function finishReturn(res, name, valid, parse) {
  const to = (hash) => res.redirect(`${appBase()}/#${hash}`);
  if (!valid) {
    log("warn", name, { reason: "invalid-signature" });
    return to("/?payment=invalid");
  }
  const r = parse();
  let paid = false;
  try {
    await handleGatewayResult(r);
    paid =
      r.success && !!(await Order.exists({ _id: r.orderId, status: "paid" }));
  } catch (e) {
    log("error", name, { name: e.name });
  }
  if (!r.orderId) return to("/tickets");
  // Thanh toán xong và vé đã phát hành: đưa thẳng tới "Vé của tôi".
  if (paid) return to(`/tickets?payment=success&order=${r.orderId}`);
  to(`/checkout/${r.orderId}?payment=${r.success ? "success" : "failed"}`);
}

// ---------- VNPay ----------
const vnpMessages = {
  "00": "Confirm Success",
  "01": "Order not found",
  "02": "Order already confirmed",
  "04": "Invalid amount",
  "97": "Invalid signature",
  "99": "Unknown error",
};
// VNPay gọi từ server của họ. Luôn trả JSON {RspCode, Message}.
paymentsRouter.get("/vnpay-ipn", enabled("vnpay"), async (req, res) => {
  if (!vnp.verifyCallback(vnpay, req.query))
    return res.json({ RspCode: "97", Message: vnpMessages["97"] });
  try {
    const { code } = await handleGatewayResult(vnp.parseCallback(req.query));
    res.json({ RspCode: code, Message: vnpMessages[code] });
  } catch (e) {
    log("error", "vnpay-ipn", { name: e.name });
    res.json({ RspCode: "99", Message: vnpMessages["99"] });
  }
});
paymentsRouter.get("/vnpay-return", enabled("vnpay"), (req, res) =>
  finishReturn(
    res,
    "vnpay-return",
    vnp.verifyCallback(vnpay, req.query),
    () => vnp.parseCallback(req.query),
  ),
);

// ---------- MoMo ----------
// MoMo gọi IPN bằng POST JSON và mong nhận HTTP 204 khi đã xử lý xong.
paymentsRouter.post("/momo-ipn", enabled("momo"), async (req, res) => {
  const data = req.body;
  if (!mm.verifyCallback(momo, data)) {
    log("warn", "momo-ipn", { reason: "invalid-signature" });
    return res.status(400).end();
  }
  try {
    const { code } = await handleGatewayResult(mm.parseCallback(data));
    res.status(code === "00" || code === "02" ? 204 : 400).end();
  } catch (e) {
    log("error", "momo-ipn", { name: e.name });
    res.status(500).end();
  }
});
paymentsRouter.get("/momo-return", enabled("momo"), (req, res) =>
  finishReturn(
    res,
    "momo-return",
    mm.verifyCallback(momo, req.query),
    () => mm.parseCallback(req.query),
  ),
);
