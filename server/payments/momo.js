import { createHmac, timingSafeEqual } from "node:crypto";
import { orderIdFromTxnRef } from "./vnpay.js";

// MoMo (API v2). cfg = { partnerCode, accessKey, secretKey, apiUrl, returnUrl, ipnUrl }
// Chữ ký: HMAC-SHA256 (hex) trên chuỗi "khóa=giá trị" nối bằng "&",
// các khóa xếp theo thứ tự bảng chữ cái, có kèm accessKey.
const hmac = (secret, raw) =>
  createHmac("sha256", secret).update(raw, "utf8").digest("hex");
const str = (v) => (v === undefined || v === null ? "" : String(v));

// captureWallet: ví MoMo (quét QR / mở app MoMo). payWithATM: thẻ ATM nội địa ngay
// trên web MoMo (không cần app). Chọn bằng cfg.requestType (biến MOMO_REQUEST_TYPE).
const DEFAULT_REQUEST_TYPE = "captureWallet";

export function buildCreateRequest(cfg, { txnRef, amount, orderInfo }) {
  const extraData = "";
  const requestType = cfg.requestType || DEFAULT_REQUEST_TYPE;
  const raw =
    `accessKey=${cfg.accessKey}&amount=${amount}&extraData=${extraData}` +
    `&ipnUrl=${cfg.ipnUrl}&orderId=${txnRef}&orderInfo=${orderInfo}` +
    `&partnerCode=${cfg.partnerCode}&redirectUrl=${cfg.returnUrl}` +
    `&requestId=${txnRef}&requestType=${requestType}`;
  return {
    partnerCode: cfg.partnerCode,
    accessKey: cfg.accessKey, // mẫu chính thức của MoMo cũng gửi kèm trường này
    partnerName: "CineGo",
    storeId: "CineGo",
    requestId: txnRef,
    amount,
    orderId: txnRef,
    orderInfo,
    redirectUrl: cfg.returnUrl,
    ipnUrl: cfg.ipnUrl,
    lang: "vi",
    requestType,
    autoCapture: true,
    extraData,
    signature: hmac(cfg.secretKey, raw),
  };
}

// Gọi API tạo giao dịch của MoMo, trả về { payUrl } để chuyển khách sang.
export async function createPayment(
  cfg,
  input,
  fetchImpl = (...args) => globalThis.fetch(...args),
) {
  const res = await fetchImpl(cfg.apiUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(buildCreateRequest(cfg, input)),
    // Tài liệu MoMo yêu cầu timeout tối thiểu 30 giây khi gọi API.
    signal: AbortSignal.timeout(30000),
  });
  const data = await res.json();
  if (!res.ok || Number(data.resultCode) !== 0 || typeof data.payUrl !== "string")
    throw new Error(`MoMo resultCode=${data.resultCode} ${data.message ?? ""}`.trim());
  if (new URL(data.payUrl).protocol !== "https:")
    throw new Error("MoMo payUrl is not https");
  return { payUrl: data.payUrl };
}

const CALLBACK_FIELDS = [
  "amount",
  "extraData",
  "message",
  "orderId",
  "orderInfo",
  "orderType",
  "partnerCode",
  "payType",
  "requestId",
  "responseTime",
  "resultCode",
  "transId",
];
// Tính chữ ký cho dữ liệu MoMo gửi về (cũng dùng trong test để giả lập MoMo).
export const signCallback = (cfg, data) =>
  hmac(
    cfg.secretKey,
    [
      `accessKey=${cfg.accessKey}`,
      ...CALLBACK_FIELDS.map((k) => `${k}=${str(data[k])}`),
    ].join("&"),
  );

// Dùng cho cả IPN (body JSON) và return URL (query string).
export function verifyCallback(cfg, data) {
  if (
    !data ||
    typeof data.signature !== "string" ||
    data.partnerCode !== cfg.partnerCode
  )
    return false;
  const a = Buffer.from(signCallback(cfg, data));
  const b = Buffer.from(data.signature.toLowerCase());
  return a.length === b.length && timingSafeEqual(a, b);
}

// Chỉ gọi sau khi verifyCallback trả true. resultCode 0 = thành công.
export const parseCallback = (data) => ({
  provider: "momo",
  txnRef: str(data.orderId),
  orderId: orderIdFromTxnRef(str(data.orderId)),
  amount: Number(data.amount),
  transactionNo: str(data.transId),
  success: Number(data.resultCode) === 0,
});
