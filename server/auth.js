import {
  randomBytes,
  randomInt,
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
import {
  User,
  Session,
  Audit,
  PasswordReset,
  EmailVerification,
  LoginChallenge,
} from "./models.js";
import { sendMail } from "./mailer.js";
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
  limit: config.NODE_ENV === "test" ? 1000 : 20,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Thử quá nhiều lần. Vui lòng đợi 15 phút." },
});
const activationLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: config.NODE_ENV === "test" ? 1000 : 8,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Thử quá nhiều lần. Vui lòng đợi 15 phút." },
});
const publicOrigin = new URL(config.APP_ORIGIN).origin;
async function sendVerification(user) {
  const token = randomBytes(32).toString("base64url");
  await EmailVerification.deleteMany({ userId: user._id });
  await EmailVerification.create({
    userId: user._id,
    tokenHash: digest(token),
    expiresAt: new Date(Date.now() + 24 * 3600000),
  });
  const link = `${publicOrigin}/#/verify-email?token=${token}`;
  await sendMail({
    to: user.email,
    subject: "Kích hoạt tài khoản CineGo",
    text: `Xin chào ${user.name},\n\nMở liên kết sau để xác minh email và kích hoạt tài khoản CineGo (có hiệu lực trong 24 giờ):\n${link}\n\nNếu bạn không tạo tài khoản, hãy bỏ qua email này.`,
  });
}
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
      emailVerified: false,
    });
    await sendVerification(user);
    res.status(202).json({ verificationRequired: true });
  }),
);
authRouter.post(
  "/resend-verification",
  activationLimit,
  body(z.object({ email }).strict()),
  route(async (req, res) => {
    const user = await User.findOne({
      email: req.data.email,
      emailVerified: false,
      active: true,
    });
    if (user) await sendVerification(user);
    res.json({ ok: true });
  }),
);
authRouter.post(
  "/verify-email",
  activationLimit,
  body(z.object({ token: z.string().min(20).max(200) }).strict()),
  route(async (req, res) => {
    const verification = await EmailVerification.findOneAndDelete({
      tokenHash: digest(req.data.token),
      expiresAt: { $gt: new Date() },
    });
    if (!verification)
      fail(400, "Liên kết xác minh không hợp lệ hoặc đã hết hạn.");
    const user = await User.findOneAndUpdate(
      { _id: verification.userId, emailVerified: false, active: true },
      { $set: { emailVerified: true } },
      { new: true },
    );
    if (!user) fail(400, "Tài khoản không tồn tại hoặc đã bị khóa.");
    await EmailVerification.deleteMany({ userId: user._id });
    res.json({ ok: true });
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
    if (!valid) fail(401, "Email hoặc mật khẩu không đúng.");
    if (!user.emailVerified)
      fail(403, "Vui lòng xác minh email trước khi đăng nhập.");
    if (!user.active)
      fail(
        403,
        "Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.",
      );
    if (req.session) {
      await Session.deleteOne({ _id: req.session._id });
      res.clearCookie("cinego_session", cookieOptions);
    }
    await LoginChallenge.deleteMany({ userId: user._id });
    const challengeId = randomBytes(32).toString("base64url");
    const code = String(randomInt(0, 1000000)).padStart(6, "0");
    await LoginChallenge.create({
      userId: user._id,
      tokenHash: digest(challengeId),
      codeHash: digest(`${challengeId}:${code}`),
      expiresAt: new Date(Date.now() + 10 * 60000),
    });
    try {
      await sendMail({
        to: user.email,
        subject: "Mã xác thực đăng nhập CineGo",
        text: `Mã xác thực đăng nhập của bạn là: ${code}\n\nMã có hiệu lực trong 10 phút. Nếu bạn không thực hiện đăng nhập, hãy đổi mật khẩu và bỏ qua email này.`,
      });
    } catch (error) {
      await LoginChallenge.deleteOne({ tokenHash: digest(challengeId) });
      throw error;
    }
    res.status(202).json({ mfaRequired: true, challengeId });
  }),
);
authRouter.post(
  "/verify-login",
  loginLimit,
  body(
    z
      .object({
        challengeId: z.string().min(20).max(200),
        code: z.string().regex(/^\d{6}$/),
      })
      .strict(),
  ),
  route(async (req, res) => {
    const tokenHash = digest(req.data.challengeId);
    const challenge = await LoginChallenge.findOne({
      tokenHash,
      expiresAt: { $gt: new Date() },
      attempts: { $lt: 5 },
    });
    if (!challenge) fail(401, "Mã xác thực không hợp lệ hoặc đã hết hạn.");
    const codeHash = digest(`${req.data.challengeId}:${req.data.code}`);
    if (
      !timingSafeEqual(
        Buffer.from(challenge.codeHash, "hex"),
        Buffer.from(codeHash, "hex"),
      )
    ) {
      const updated = await LoginChallenge.findOneAndUpdate(
        { _id: challenge._id, attempts: { $lt: 5 } },
        { $inc: { attempts: 1 } },
        { new: true },
      );
      if (!updated || updated.attempts >= 5)
        await LoginChallenge.deleteOne({ _id: challenge._id });
      const user = await User.findOneAndUpdate(
        {
          _id: challenge.userId,
          role: { $in: ["customer", "admin"] },
          active: true,
        },
        { $inc: { failedOtpAttempts: 1 } },
        { new: true },
      );
      if (user?.failedOtpAttempts >= 5) {
        const locked = await User.findOneAndUpdate(
          {
            _id: user._id,
            role: { $in: ["customer", "admin"] },
            active: true,
            failedOtpAttempts: { $gte: 5 },
          },
          { $set: { active: false } },
        );
        if (locked) {
          await Promise.all([
            Session.deleteMany({ userId: user._id }),
            LoginChallenge.deleteMany({ userId: user._id }),
          ]);
          fail(
            403,
            "Tài khoản đã bị khóa do nhập sai mã OTP 5 lần. Vui lòng liên hệ quản trị viên.",
          );
        }
      }
      fail(401, "Mã xác thực không hợp lệ hoặc đã hết hạn.");
    }
    const claimed = await LoginChallenge.findOneAndDelete({
      _id: challenge._id,
      codeHash,
      expiresAt: { $gt: new Date() },
      attempts: { $lt: 5 },
    });
    if (!claimed) fail(401, "Mã xác thực không hợp lệ hoặc đã hết hạn.");
    const user = await User.findOneAndUpdate(
      {
        _id: claimed.userId,
        $and: [
          {
            $or: [
              { emailVerified: true },
              { emailVerified: { $exists: false } },
            ],
          },
          {
            $or: [
              { active: true },
              { active: { $exists: false } },
            ],
          },
        ],
      },
      {
        $set: {
          active: true,
          emailVerified: true,
          failedOtpAttempts: 0,
        },
      },
      { new: true },
    );
    if (!user) fail(403, "Tài khoản không còn khả dụng.");
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

const resetLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 8,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { message: "Thử quá nhiều lần. Vui lòng đợi 15 phút." },
});
// Luôn trả về cùng một kết quả để không lộ email nào đã đăng ký.
authRouter.post(
  "/forgot-password",
  resetLimit,
  body(z.object({ email }).strict()),
  route(async (req, res) => {
    const user = await User.findOne({ email: req.data.email, active: true });
    if (user) {
      const token = randomBytes(32).toString("base64url");
      await PasswordReset.deleteMany({ userId: user._id });
      await PasswordReset.create({
        userId: user._id,
        tokenHash: digest(token),
        expiresAt: new Date(Date.now() + 30 * 60000),
      });
      const link = `${new URL(config.APP_ORIGIN).origin}/#/reset-password?token=${token}`;
      try {
        await sendMail({
          to: user.email,
          subject: "Đặt lại mật khẩu CineGo",
          text: `Xin chào ${user.name},\n\nBạn vừa yêu cầu đặt lại mật khẩu CineGo. Mở liên kết sau để đặt mật khẩu mới (có hiệu lực trong 30 phút):\n${link}\n\nNếu không phải bạn yêu cầu, hãy bỏ qua email này.`,
        });
      } catch {
        console.error("Không gửi được email đặt lại mật khẩu.");
      }
    }
    res.json({ ok: true });
  }),
);
authRouter.post(
  "/reset-password",
  resetLimit,
  body(z.object({ token: z.string().min(20).max(200), password }).strict()),
  route(async (req, res) => {
    const invalid = "Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.";
    const reset = await PasswordReset.findOne({
      tokenHash: digest(req.data.token),
      expiresAt: { $gt: new Date() },
    });
    if (!reset) fail(400, invalid);
    const user = await User.findById(reset.userId);
    if (!user || !user.active) fail(400, invalid);
    user.passwordHash = await hashPassword(req.data.password);
    await user.save();
    await PasswordReset.deleteMany({ userId: user._id });
    await Session.deleteMany({ userId: user._id });
    await Audit.create({
      userId: user._id,
      action: "password.reset",
      entityId: user._id,
    });
    res.json({ ok: true });
  }),
);
