import "dotenv/config";
import { z } from "zod";
// Biến để trống trong .env (KEY=) được coi như chưa đặt.
const blank = (schema) =>
  z.preprocess((v) => (v === "" ? undefined : v), schema);
const env = z
  .object({
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
    PORT: z.coerce.number().int().min(1).max(65535).default(4000),
    APP_ORIGIN: z.string().url().default("http://localhost:4000"),
    MONGODB_URI: z.string().min(1),
    SESSION_SECRET: z.string().min(48),
    PAYMENT_MODE: z
      .enum(["demo", "online", "vnpay", "disabled"])
      .default("disabled"),
    VNP_TMN_CODE: z.string().optional(),
    VNP_HASH_SECRET: z.string().optional(),
    VNP_PAY_URL: z
      .string()
      .url()
      .default("https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"),
    VNP_RETURN_URL: blank(z.string().url().optional()),
    MOMO_PARTNER_CODE: z.string().optional(),
    MOMO_ACCESS_KEY: z.string().optional(),
    MOMO_SECRET_KEY: z.string().optional(),
    MOMO_API_URL: z
      .string()
      .url()
      .default("https://test-payment.momo.vn/v2/gateway/api/create"),
    MOMO_RETURN_URL: blank(z.string().url().optional()),
    MOMO_IPN_URL: blank(z.string().url().optional()),
    MOMO_REQUEST_TYPE: z
      .enum(["captureWallet", "payWithATM", "payWithMethod"])
      .default("captureWallet"),
    SMTP_HOST: blank(z.string().optional()),
    SMTP_PORT: blank(z.coerce.number().int().min(1).max(65535).default(587)),
    SMTP_USER: blank(z.string().optional()),
    SMTP_PASS: blank(z.string().optional()),
    MAIL_FROM: blank(z.string().optional()),
    HOLD_MINUTES: z.coerce.number().int().min(1).max(30).default(10),
    CHANGE_CUTOFF_HOURS: z.coerce.number().min(0).max(168).default(12),
    REFUND_PERCENT: z.coerce.number().int().min(0).max(100).default(100),
    POINTS_PER_VND: z.coerce.number().int().positive().default(10000),
  })
  .parse(process.env);
// "vnpay" là tên cũ của chế độ thanh toán trực tuyến; giữ lại để .env cũ vẫn chạy.
if (env.PAYMENT_MODE === "vnpay") env.PAYMENT_MODE = "online";
if (
  env.NODE_ENV === "production" &&
  (env.PAYMENT_MODE === "demo" ||
    !env.APP_ORIGIN.startsWith("https://") ||
    env.SESSION_SECRET.includes("replace-with"))
)
  throw Error(
    "Production requires HTTPS, random session secret, and a real payment integration. Demo payments are prohibited.",
  );
if (
  env.NODE_ENV === "production" &&
  (!env.SMTP_HOST || !(env.MAIL_FROM || env.SMTP_USER))
)
  throw Error(
    "Production requires SMTP_HOST and either MAIL_FROM or SMTP_USER for account verification and login MFA.",
  );
const vnpayOn = !!(
  env.VNP_TMN_CODE &&
  env.VNP_HASH_SECRET &&
  env.VNP_RETURN_URL
);
const momoOn = !!(
  env.MOMO_PARTNER_CODE &&
  env.MOMO_ACCESS_KEY &&
  env.MOMO_SECRET_KEY &&
  env.MOMO_RETURN_URL
);
if (env.PAYMENT_MODE === "online") {
  if (!vnpayOn && !momoOn)
    throw Error(
      "PAYMENT_MODE=online requires VNPay (VNP_TMN_CODE, VNP_HASH_SECRET, VNP_RETURN_URL) and/or MoMo (MOMO_PARTNER_CODE, MOMO_ACCESS_KEY, MOMO_SECRET_KEY, MOMO_RETURN_URL).",
    );
  if (
    env.NODE_ENV === "production" &&
    ((vnpayOn && env.VNP_PAY_URL.includes("sandbox")) ||
      (momoOn && env.MOMO_API_URL.includes("test-payment")))
  )
    throw Error("Production must not use sandbox payment gateway URLs.");
}
export const config = env;
export const vnpay = {
  tmnCode: env.VNP_TMN_CODE,
  hashSecret: env.VNP_HASH_SECRET,
  payUrl: env.VNP_PAY_URL,
  returnUrl: env.VNP_RETURN_URL,
};
export const momo = {
  partnerCode: env.MOMO_PARTNER_CODE,
  accessKey: env.MOMO_ACCESS_KEY,
  secretKey: env.MOMO_SECRET_KEY,
  apiUrl: env.MOMO_API_URL,
  requestType: env.MOMO_REQUEST_TYPE,
  returnUrl: env.MOMO_RETURN_URL,
  ipnUrl:
    env.MOMO_IPN_URL ||
    (env.MOMO_RETURN_URL
      ? new URL("/api/payments/momo-ipn", env.MOMO_RETURN_URL).href
      : undefined),
};
// Các phương thức khách được chọn ở trang thanh toán (tùy cổng đã cấu hình).
export const paymentMethods =
  env.PAYMENT_MODE === "online"
    ? [...(vnpayOn ? ["vnpay", "atm"] : []), ...(momoOn ? ["momo"] : [])]
    : [];
export const policy = {
  version: "proposal-1",
  holdMinutes: env.HOLD_MINUTES,
  changeCutoffHours: 12,
  refundPercent: env.REFUND_PERCENT,
  pointsPerVnd: env.POINTS_PER_VND,
};
