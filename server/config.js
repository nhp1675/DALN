import "dotenv/config";
import { z } from "zod";
const env = z
  .object({
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
    PORT: z.coerce.number().int().min(1).max(65535).default(4000),
    APP_ORIGIN: z.string().url().default("http://localhost:4000"),
    MONGODB_URI: z.string().min(1),
    SESSION_SECRET: z.string().min(48),
    PAYMENT_MODE: z.enum(["demo", "disabled"]).default("disabled"),
    HOLD_MINUTES: z.coerce.number().int().min(1).max(30).default(10),
    CHANGE_CUTOFF_HOURS: z.coerce.number().min(0).max(168).default(24),
    REFUND_PERCENT: z.coerce.number().int().min(0).max(100).default(100),
    POINTS_PER_VND: z.coerce.number().int().positive().default(10000),
  })
  .parse(process.env);
if (
  env.NODE_ENV === "production" &&
  (env.PAYMENT_MODE === "demo" ||
    !env.APP_ORIGIN.startsWith("https://") ||
    env.SESSION_SECRET.includes("replace-with"))
)
  throw Error(
    "Production requires HTTPS, random session secret, and a real payment integration. Demo payments are prohibited.",
  );
export const config = env;
export const policy = {
  version: "proposal-1",
  holdMinutes: env.HOLD_MINUTES,
  changeCutoffHours: env.CHANGE_CUTOFF_HOURS,
  refundPercent: env.REFUND_PERCENT,
  pointsPerVnd: env.POINTS_PER_VND,
};
