import { test } from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
process.env.NODE_ENV = "test";
process.env.SESSION_SECRET = "unit-only-" + "x".repeat(64);
process.env.APP_ORIGIN = "http://localhost:5173";
process.env.MONGODB_URI = "mongodb://placeholder";
process.env.PAYMENT_MODE = "demo";
const { hashPassword, checkPassword, csrf, requireAdmin } = await import(
  "../server/auth.js"
);
const { app } = await import("../server/app.js");
const { allModels } = await import("../server/models.js");
test("scrypt hashes use independent salts and reject wrong passwords", async () => {
  const a = await hashPassword("long-password-one"),
    b = await hashPassword("long-password-one");
  assert.notEqual(a, b);
  assert(await checkPassword("long-password-one", a));
  assert.equal(await checkPassword("wrong-password", a), false);
});
test("Origin and CSRF middleware blocks external and mismatched tokens", () => {
  function run(origin, token, session) {
    let result;
    csrf(
      {
        method: "POST",
        session,
        get: (k) => (k === "origin" ? origin : token),
      },
      {},
      (e) => {
        result = e || "ok";
      },
    );
    return result;
  }
  assert.equal(
    run("https://evil.test", "valid", { csrf: "valid" }).status,
    403,
  );
  assert.equal(
    run("http://localhost:5173", "wrong", { csrf: "valid" }).status,
    403,
  );
  assert.equal(run("http://localhost:5173", "valid", { csrf: "valid" }), "ok");
});
test("Non-admin role cannot pass authorization middleware", () => {
  let result;
  requireAdmin({ user: { role: "customer" } }, {}, (e) => (result = e));
  assert.equal(result.status, 403);
});
test("HTTP headers prevent framing and disable sniffing", async () => {
  const r = await request(app).get("/api/health");
  assert.equal(r.status, 200);
  assert.equal(r.headers["x-content-type-options"], "nosniff");
  assert(
    r.headers["content-security-policy"].includes("frame-ancestors 'none'"),
  );
  assert.equal(r.headers["x-powered-by"], undefined);
  assert.equal(r.headers["cache-control"], "no-store");
});
test("Unauthenticated protected requests and untrusted origin rejected before database access", async () => {
  assert.equal((await request(app).get("/api/tickets")).status, 401);
  assert.equal(
    (
      await request(app)
        .post("/api/auth/login")
        .set("Origin", "https://evil.test")
        .send({ email: "x", password: "x" })
    ).status,
    403,
  );
});
test("Input schemas reject object injection and privilege escalation", async () => {
  const r = await request(app)
    .post("/api/auth/register")
    .set("Origin", "http://localhost:5173")
    .send({
      email: { $ne: null },
      name: "user",
      password: "long-password",
      role: "admin",
    });
  assert.equal(r.status, 400);
  const malformed = await request(app).get("/api/movies/not-an-objectid");
  assert.equal(malformed.status, 400);
});
test("Database schemas are strict; unique indexes cover seats, tickets, memberships, idempotency", () => {
  for (const m of allModels) assert.equal(m.schema.options.strict, "throw");
  const indexes = Object.fromEntries(
    allModels.map((m) => [m.modelName, m.schema.indexes()]),
  );
  for (const name of [
    "ShowtimeSeat",
    "Ticket",
    "Membership",
    "Order",
    "Session",
    "User",
  ])
    assert(indexes[name].some(([, o]) => o.unique));
});

test('Flutter credentialed CORS permits only the configured origin', async () => {
  const good = await request(app).options('/api/orders').set('Origin', 'http://localhost:5173').set('Access-Control-Request-Method', 'POST');
  assert.equal(good.status, 204);
  assert.equal(good.headers['access-control-allow-origin'], 'http://localhost:5173');
  assert.equal(good.headers['access-control-allow-credentials'], 'true');
  const bad = await request(app).options('/api/orders').set('Origin', 'https://evil.test');
  assert.equal(bad.status, 403);
  assert.equal(bad.headers['access-control-allow-origin'], undefined);
});
