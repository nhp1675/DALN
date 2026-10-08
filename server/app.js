import express from "express";
import helmet from "helmet";
import cookieParser from "cookie-parser";
import { rateLimit } from "express-rate-limit";
import { ZodError } from "zod";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { existsSync } from "node:fs";
import { isTrustedOrigin } from "./origins.js";
import { authenticate, csrf, authRouter } from "./auth.js";
import { publicRouter } from "./routes/public.js";
import { customerRouter } from "./routes/customer.js";
import { adminRouter } from "./routes/admin.js";
export const app = express();
app.disable("x-powered-by");
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'wasm-unsafe-eval'"],
        workerSrc: ["'self'", "blob:"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'"],
        fontSrc: ["'self'", "data:"],
        objectSrc: ["'none'"],
        frameAncestors: ["'none'"],
        upgradeInsecureRequests:
          process.env.NODE_ENV === "production" ? [] : null,
      },
    },
  }),
);
app.use(
  "/api",
  rateLimit({
    windowMs: 60000,
    limit: 240,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: { message: "Quá nhiều yêu cầu. Vui lòng thử lại sau." },
  }),
);
// Use the same origin policy for credentialed CORS and CSRF checks.
app.use('/api', (req, res, next) => {
  const origin = req.get('origin');
  res.vary('Origin');
  if (isTrustedOrigin(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Credentials', 'true');
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type,X-CSRF-Token');
      return res.sendStatus(204);
    }
  } else if (req.method === 'OPTIONS') {
    return res.status(403).json({message:'Nguồn yêu cầu không hợp lệ.'});
  }
  next();
});
app.use(express.json({ limit: "16kb" }), cookieParser());
app.use("/api", authenticate, csrf, (req, res, next) => {
  res.set("Cache-Control", "no-store");
  next();
});
app.get("/api/health", (req, res) => res.json({ ok: true }));
app.use("/api/auth", authRouter);
app.use("/api", publicRouter);
app.use("/api/admin", adminRouter);
app.use("/api", customerRouter);
app.use("/api", (req, res) =>
  res.status(404).json({ message: "API không tồn tại." }),
);
const dist = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../frontend/build/web",
);
if (existsSync(dist)) {
  app.use(express.static(dist, { index: false }));
  app.get("/{*path}", (req, res) =>
    res.sendFile(path.join(dist, "index.html")),
  );
}
app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);
  if (err instanceof ZodError)
    return res
      .status(400)
      .json({
        message: err.issues
          .map((i) => `${i.path.join(".")}: ${i.message}`)
          .join("; "),
      });
  if (err.code === 11000)
    return res
      .status(409)
      .json({
        message:
          "Dữ liệu trùng hoặc tài nguyên vừa được cập nhật. Hãy thử lại.",
      });
  if (
    err.name === "ValidationError" ||
    err.name === "CastError" ||
    err.name === "StrictModeError"
  )
    return res.status(400).json({ message: "Dữ liệu không hợp lệ." });
  const status = err.status || 500;
  if (status >= 500)
    console.error(
      JSON.stringify({
        level: "error",
        path: req.path,
        name: err.name,
        code: err.code || "internal",
      }),
    );
  res
    .status(status)
    .json({
      message:
        status >= 500
          ? "Dịch vụ tạm thời không sẵn sàng. Vui lòng thử lại."
          : err.message,
    });
});
