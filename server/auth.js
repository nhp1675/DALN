import {
  randomBytes,
  scrypt as scryptCallback,
  timingSafeEqual,
  createHmac,
} from "node:crypto";
import { promisify } from "node:util";
import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { z } from "zod";
import { config } from "./config.js";
import { isTrustedOrigin } from "./origins.js";
import { User, Session, Audit } from "./models.js";
import { route, body, fail } from "./core.js";
const scrypt = promisify(scryptCallback);
export async function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = await scrypt(password, salt, 64, {
    N: 32768,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  return `${salt}:${hash.toString("hex")}`;
}
export async function checkPassword(password, stored) {
  const [salt, hex] = stored.split(":");
  const hash = await scrypt(password, salt, 64, {
    N: 32768,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  return timingSafeEqual(hash, Buffer.from(hex, "hex"));
}
const digest = (x) =>
  createHmac("sha256", config.SESSION_SECRET).update(x).digest("hex");
const cookieOptions = {
  httpOnly: true,
  sameSite: "strict",
  secure: config.NODE_ENV === "production",
  path: "/",
};
const publicUser = (u) => ({
  id: u._id,
  name: u.name,
  email: u.email,
  phone: u.phone,
  role: u.role,
  points: Math.floor(Math.max(0, u.netSpend) / config.POINTS_PER_VND),
});
export async function authenticate(req, res, next) {
  try {
    const token = req.cookies?.cinego_session;
    if (!token) return next();
    const session = await Session.findOne({
      tokenHash: digest(token),
      expiresAt: { $gt: new Date() },
    });
    if (!session) return next();
    const user = await User.findOne({ _id: session.userId, active: true });
    if (user) {
      req.user = user;
      req.session = session;
    }
    next();
  } catch (e) {
    next(e);
  }
}
export function requireAuth(req, res, next) {
  if (!req.user)
    return next(Object.assign(Error("Vui lòng đăng nhập."), { status: 401 }));
  next();
}
export function requireAdmin(req, res, next) {
  if (req.user?.role !== "admin")
    return next(
      Object.assign(Error("Bạn không có quyền quản trị."), { status: 403 }),
    );
  next();
}
export function csrf(req, res, next) {
  if (["GET", "HEAD", "OPTIONS"].includes(req.method)) return next();
  if (!isTrustedOrigin(req.get("origin")))
    return next(
      Object.assign(Error("Nguồn yêu cầu không hợp lệ."), { status: 403 }),
    );
  if (req.session && req.get("x-csrf-token") !== req.session.csrf)
    return next(
      Object.assign(Error("Phiên bảo mật đã thay đổi. Hãy tải lại trang."), {
        status: 403,
      }),
    );
  next();
}
async function loginSession(user, req, res) {
  if (req.session) await Session.deleteOne({ _id: req.session._id });
  const token = randomBytes(32).toString("base64url"),
    csrf = randomBytes(32).toString("base64url");
  await Session.create({
    tokenHash: digest(token),
    userId: user._id,
    csrf,
    expiresAt: new Date(Date.now() + 8 * 3600000),
  });
  res.cookie("cinego_session", token, {
    ...cookieOptions,
    maxAge: 8 * 3600000,
  });
  res.json({ user: publicUser(user), csrf });
}
const password = z.string().min(12, "Mật khẩu cần ít nhất 12 ký tự").max(128);
const email = z
  .string()
  .trim()
  .email()
  .max(254)
  .transform((x) => x.toLowerCase());
const phone = z
  .string()
  .trim()
  .regex(/^(\+?[0-9]{9,15})?$/, "Số điện thoại không hợp lệ")
  .default("");
export const authRouter = Router();
const loginLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Thử quá nhiều lần. Vui lòng đợi 15 phút." },
});
authRouter.get("/me", requireAuth, (req, res) =>
  res.json({ user: publicUser(req.user), csrf: req.session.csrf }),
);
authRouter.post(
  "/register",
  loginLimit,
  body(
    z
      .object({
        name: z.string().trim().min(2).max(80),
        email,
        password,
        phone,
      })
      .strict(),
  ),
  route(async (req, res) => {
    const data = req.data;
    if (await User.exists({ email: data.email }))
      fail(409, "Không thể tạo tài khoản với email này.");
    const user = await User.create({
      name: data.name,
      email: data.email,
      phone: data.phone,
      passwordHash: await hashPassword(data.password),
    });
    await loginSession(user, req, res);
  }),
);
authRouter.post(
  "/login",
  loginLimit,
  body(z.object({ email, password: z.string().min(1).max(128) }).strict()),
  route(async (req, res) => {
    const user = await User.findOne({ email: req.data.email });
    const dummy = "00000000000000000000000000000000:" + "00".repeat(64);
    const valid = await checkPassword(
      req.data.password,
      user?.passwordHash || dummy,
    );
    if (!valid || !user?.active) fail(401, "Email hoặc mật khẩu không đúng.");
    await loginSession(user, req, res);
  }),
);
authRouter.post(
  "/logout",
  requireAuth,
  route(async (req, res) => {
    await Session.deleteOne({ _id: req.session._id });
    res.clearCookie("cinego_session", cookieOptions).json({ ok: true });
  }),
);
authRouter.patch(
  "/profile",
  requireAuth,
  body(z.object({ name: z.string().trim().min(2).max(80), phone }).strict()),
  route(async (req, res) => {
    req.user.set(req.data);
    await req.user.save();
    res.json({ user: publicUser(req.user) });
  }),
);
authRouter.post(
  "/password",
  requireAuth,
  loginLimit,
  body(z.object({ oldPassword: z.string().max(128), password }).strict()),
  route(async (req, res) => {
    if (!(await checkPassword(req.data.oldPassword, req.user.passwordHash)))
      fail(400, "Mật khẩu hiện tại không đúng.");
    req.user.passwordHash = await hashPassword(req.data.password);
    await req.user.save();
    await Session.deleteMany({ userId: req.user._id });
    await Audit.create({
      userId: req.user._id,
      action: "password.changed",
      entityId: req.user._id,
    });
    res.clearCookie("cinego_session", cookieOptions).json({ ok: true });
  }),
);
