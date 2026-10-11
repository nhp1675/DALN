import { createHmac, timingSafeEqual } from "node:crypto";

// Module thuần (không đụng database, không đọc config) để dễ kiểm thử.
// cfg = { tmnCode, hashSecret, payUrl, returnUrl }

// VNPay yêu cầu: sắp xếp tham số theo tên, mã hóa như encodeURIComponent
// nhưng khoảng trắng phải là "+".
const enc = (v) => encodeURIComponent(v).replace(/%20/g, "+");

function sign(params, secret) {
  const data = Object.keys(params)
    .sort()
    .map((k) => `${enc(k)}=${enc(params[k])}`)
    .join("&");
  const hash = createHmac("sha512", secret)
    .update(Buffer.from(data, "utf-8"))
    .digest("hex");
  return { data, hash };
}

// VNPay dùng giờ Việt Nam (GMT+7), định dạng yyyyMMddHHmmss.
export function vnTime(date) {
  const t = new Date(date.getTime() + 7 * 3600000);
  return t.toISOString().replace(/[-:T]/g, "").slice(0, 14);
}

// Mã giao dịch phải khác nhau ở mỗi lần thanh toán, nên ghép thêm thời gian.
// 24 ký tự đầu luôn là orderId (ObjectId) để suy ngược ra đơn hàng.
export const makeTxnRef = (orderId) =>
  `${orderId}${Date.now().toString(36)}`;
export const orderIdFromTxnRef = (txnRef) =>
  /^[a-f0-9]{24}/i.test(txnRef) ? txnRef.slice(0, 24) : null;

// Phương thức hiển thị ở Flutter -> mã ngân hàng gửi sang VNPay.
// undefined = để khách tự chọn trên trang VNPay (QR, thẻ ATM, thẻ quốc tế...).
// Không ép "VNPAYQR" vì sandbox của merchant có thể báo "Ngân hàng thanh toán
// không được hỗ trợ".
export const bankCodeFor = (method) => ({ atm: "VNBANK" })[method];

export function createPaymentUrl(
  cfg,
  { txnRef, amount, orderInfo, ipAddr, bankCode, createdAt = new Date(), expiresAt },
) {
  const params = {
    vnp_Version: "2.1.0",
    vnp_Command: "pay",
    vnp_TmnCode: cfg.tmnCode,
    vnp_Amount: String(amount * 100), // VNPay tính đơn vị = đồng x 100
    vnp_CurrCode: "VND",
    vnp_TxnRef: txnRef,
    vnp_OrderInfo: orderInfo, // nên là tiếng Việt không dấu
    vnp_OrderType: "other",
    vnp_Locale: "vn",
    vnp_ReturnUrl: cfg.returnUrl,
    vnp_IpAddr: ipAddr,
    vnp_CreateDate: vnTime(createdAt),
    vnp_ExpireDate: vnTime(expiresAt), // trùng hạn giữ ghế của đơn
  };
  if (bankCode) params.vnp_BankCode = bankCode;
  const { data, hash } = sign(params, cfg.hashSecret);
  return `${cfg.payUrl}?${data}&vnp_SecureHash=${hash}`;
}

// Ký một bộ tham số (dùng trong test để giả lập callback của VNPay).
export const signParams = (cfg, params) => ({
  ...params,
  vnp_SecureHash: sign(params, cfg.hashSecret).hash,
});

// Dùng cho cả IPN và return URL: kiểm tra chữ ký của tham số VNPay gửi về.
export function verifyCallback(cfg, query) {
  const { vnp_SecureHash, vnp_SecureHashType, ...rest } = query;
  if (typeof vnp_SecureHash !== "string") return false;
  const params = Object.fromEntries(
    Object.entries(rest).filter(
      ([k, v]) => k.startsWith("vnp_") && typeof v === "string",
    ),
  );
  const { hash } = sign(params, cfg.hashSecret);
  const a = Buffer.from(hash);
  const b = Buffer.from(vnp_SecureHash.toLowerCase());
  return a.length === b.length && timingSafeEqual(a, b);
}

// Chỉ gọi sau khi verifyCallback trả true.
export function parseCallback(query) {
  return {
    provider: "vnpay",
    txnRef: query.vnp_TxnRef,
    orderId: orderIdFromTxnRef(query.vnp_TxnRef),
    amount: Number(query.vnp_Amount) / 100,
    transactionNo: query.vnp_TransactionNo,
    success:
      query.vnp_ResponseCode === "00" && query.vnp_TransactionStatus === "00",
  };
}
