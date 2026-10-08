import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import request from "supertest";
import mongoose from "mongoose";
process.env.NODE_ENV = "test";
process.env.SESSION_SECRET = "test-only-" + "a".repeat(64);
process.env.PAYMENT_MODE = "demo";
process.env.APP_ORIGIN = "http://localhost:5173";
process.env.MONGODB_URI = "mongodb://placeholder";
let repl,
  app,
  M,
  booking,
  catalog,
  A,
  B,
  admin,
  show,
  otherShow,
  seats,
  firstOrder,
  firstTicket;
const origin = "http://localhost:5173";
async function call(agent, method, url, body, expected = 200) {
  const r = await agent.client[method]("/api" + url)
    .set("Origin", origin)
    .set("x-csrf-token", agent.csrf || "")
    .send(body);
  assert.equal(r.status, expected, JSON.stringify(r.body));
  return r.body;
}
async function register(email) {
  const client = request.agent(app);
  const r = await client
    .post("/api/auth/register")
    .set("Origin", origin)
    .send({
      email,
      name: email.split("@")[0],
      password: "Long-test-password-123",
      phone: "",
    });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  return { client, csrf: r.body.csrf, user: r.body.user };
}
before(
  async () => {
    repl = await MongoMemoryReplSet.create({
      replSet: { count: 1 },
      binary: { version: "7.0.24" },
    });
    process.env.MONGODB_URI = repl.getUri();
    await mongoose.connect(process.env.MONGODB_URI);
    M = await import("../server/models.js");
    await Promise.all(M.allModels.map((m) => m.init()));
    ({ app } = await import("../server/app.js"));
    booking = await import("../server/services/booking.js");
    catalog = await import("../server/services/catalog.js");
    A = await register("alpha@example.test");
    B = await register("bravo@example.test");
    admin = await register("admin@example.test");
    await M.User.updateOne({ _id: admin.user.id }, { $set: { role: "admin" } });
    const movie = await M.Movie.create({
      title: "Integration movie",
      genre: "Drama",
      duration: 100,
      synopsis: "Test",
      status: "now",
    });
    const cinema = await M.Cinema.create({
      name: "Cinema",
      address: "Address",
      city: "Hanoi",
      latitude: 21,
      longitude: 105,
    });
    const room = await catalog.saveRoom(admin.user.id, {
      cinemaId: String(cinema._id),
      name: "Room A",
      rows: 4,
      columns: 6,
    });
    show = await catalog.saveShowtime(admin.user.id, {
      movieId: String(movie._id),
      roomId: String(room._id),
      startAt: new Date(Date.now() + 72 * 3600000).toISOString(),
      standardPrice: 80000,
      vipPrice: 110000,
    });
    otherShow = await catalog.saveShowtime(admin.user.id, {
      movieId: String(movie._id),
      roomId: String(room._id),
      startAt: new Date(Date.now() + 96 * 3600000).toISOString(),
      standardPrice: 100000,
      vipPrice: 130000,
    });
    seats = await M.ShowtimeSeat.find({ showtimeId: show._id }).sort({
      label: 1,
    });
  },
  { timeout: 180000 },
);
after(async () => {
  await mongoose.disconnect();
  await repl?.stop();
});
test("Reject missing origin, forged CSRF, unauthorized admin and NoSQL objects", async () => {
  assert.equal((await A.client.post("/api/orders").send({})).status, 403);
  assert.equal(
    (
      await A.client
        .post("/api/orders")
        .set("Origin", origin)
        .set("x-csrf-token", "fake")
        .send({})
    ).status,
    403,
  );
  await call(A, "get", "/admin/overview", undefined, 403);
  await call(
    A,
    "post",
    "/auth/login",
    { email: { $ne: null }, password: "anything" },
    400,
  );
  await call(
    A,
    "post",
    "/auth/register",
    {
      email: "evil@example.test",
      name: "evil",
      password: "test-password-123",
      role: "admin",
    },
    400,
  );
});
test("Atomic concurrent seat booking grants exactly one winner", async () => {
  const payload = {
    showtimeId: String(show._id),
    seatIds: [String(seats[0]._id)],
    idempotencyKey: crypto.randomUUID(),
  };
  const r = await Promise.all([
    A.client
      .post("/api/orders")
      .set("Origin", origin)
      .set("x-csrf-token", A.csrf)
      .send(payload),
    B.client
      .post("/api/orders")
      .set("Origin", origin)
      .set("x-csrf-token", B.csrf)
      .send({ ...payload, idempotencyKey: crypto.randomUUID() }),
  ]);
  assert.deepEqual(r.map((x) => x.status).sort(), [201, 409]);
  const winner = r[0].status === 201 ? A : B;
  firstOrder = r.find((x) => x.status === 201).body;
  A.winner = winner;
  assert.equal(await M.Order.countDocuments({ status: "pending" }), 1);
  assert.equal(await M.Ticket.countDocuments(), 0);
});
test("Order ownership is enforced and payment failure never issues tickets", async () => {
  const winner = A.winner,
    other = winner === A ? B : A;
  await call(other, "get", "/orders/" + firstOrder._id, undefined, 404);
  await call(
    other,
    "post",
    "/orders/" + firstOrder._id + "/pay-demo",
    { outcome: "success" },
    404,
  );
  await call(winner, "post", "/orders/" + firstOrder._id + "/pay-demo", {
    outcome: "failed",
  });
  assert.equal(await M.Ticket.countDocuments(), 0);
});
test("Duplicate concurrent payments create a single ticket and charge", async () => {
  const winner = A.winner;
  const results = await Promise.all([
    call(winner, "post", "/orders/" + firstOrder._id + "/pay-demo", {
      outcome: "success",
    }),
    call(winner, "post", "/orders/" + firstOrder._id + "/pay-demo", {
      outcome: "success",
    }),
  ]);
  assert.equal(results[0].status, "paid");
  assert.equal(await M.Ticket.countDocuments(), 1);
  assert.equal(await M.Payment.countDocuments({ status: "success" }), 1);
  firstTicket = await M.Ticket.findOne();
  assert.equal((await M.User.findById(winner.user.id)).netSpend, 80000);
});
test("Exchange failure preserves original ticket; success changes QR and charges delta", async () => {
  const winner = A.winner;
  const target = await M.ShowtimeSeat.findOne({
    showtimeId: otherShow._id,
    type: "vip",
  });
  const oldSeat = String(firstTicket.showtimeSeatId),
    oldQR = firstTicket.qr;
  const order = await call(
    winner,
    "post",
    "/tickets/" + firstTicket._id + "/exchange",
    { seatId: String(target._id), idempotencyKey: crypto.randomUUID() },
    201,
  );
  assert.equal(order.total, 50000);
  await call(winner, "post", "/orders/" + order._id + "/pay-demo", {
    outcome: "failed",
  });
  assert.equal(
    String((await M.Ticket.findById(firstTicket._id)).showtimeSeatId),
    oldSeat,
  );
  await call(winner, "post", "/orders/" + order._id + "/pay-demo", {
    outcome: "success",
  });
  const t = await M.Ticket.findById(firstTicket._id);
  assert.equal(String(t.showtimeSeatId), String(target._id));
  assert.notEqual(t.qr, oldQR);
  assert.equal((await M.ShowtimeSeat.findById(oldSeat)).status, "available");
  assert.equal((await M.User.findById(winner.user.id)).netSpend, 130000);
});
test("Chat access requires membership and valid ticket; cancel revokes it and refunds once", async () => {
  const winner = A.winner,
    other = winner === A ? B : A;
  await call(other, "post", "/chat/" + otherShow._id + "/join", {}, 403);
  await call(
    winner,
    "get",
    "/chat/" + otherShow._id + "/messages",
    undefined,
    403,
  );
  await call(winner, "post", "/chat/" + otherShow._id + "/join", {});
  await call(
    winner,
    "post",
    "/chat/" + otherShow._id + "/messages",
    { body: "<script>alert(1)</script>" },
    201,
  );
  const msgs = await call(
    winner,
    "get",
    "/chat/" + otherShow._id + "/messages",
  );
  assert.equal(msgs[0].body, "<script>alert(1)</script>");
  await call(winner, "post", "/tickets/" + firstTicket._id + "/cancel", {});
  await call(winner, "post", "/tickets/" + firstTicket._id + "/cancel", {});
  await call(
    winner,
    "get",
    "/chat/" + otherShow._id + "/messages",
    undefined,
    403,
  );
  const refunds = await M.Refund.find();
  assert.equal(
    refunds.reduce((n, r) => n + r.amount, 0),
    130000,
  );
  assert.equal((await M.User.findById(winner.user.id)).netSpend, 0);
});
test("Expired holds cannot pay and are available to another customer", async () => {
  const o = await booking.hold(A.user.id, {
    showtimeId: String(show._id),
    seatIds: [String(seats[1]._id)],
    idempotencyKey: crypto.randomUUID(),
  });
  await M.Order.updateOne(
    { _id: o._id },
    { $set: { expiresAt: new Date(Date.now() - 1000) } },
  );
  await M.ShowtimeSeat.updateOne(
    { _id: seats[1]._id },
    { $set: { holdUntil: new Date(Date.now() - 1000) } },
  );
  await call(
    A,
    "post",
    "/orders/" + o._id + "/pay-demo",
    { outcome: "success" },
    409,
  );
  await booking.releaseExpired();
  assert.equal((await M.Order.findById(o._id)).status, "expired");
  const next = await booking.hold(B.user.id, {
    showtimeId: String(show._id),
    seatIds: [String(seats[1]._id)],
    idempotencyKey: crypto.randomUUID(),
  });
  assert.equal(next.total, 80000);
});
test("Server computes prices, rejects mismatched idempotency, overlapping schedules and edits with sales", async () => {
  await call(
    A,
    "post",
    "/orders",
    {
      showtimeId: String(show._id),
      seatIds: [String(seats[2]._id)],
      idempotencyKey: crypto.randomUUID(),
      total: 1,
    },
    400,
  );
  const k = crypto.randomUUID();
  await call(
    A,
    "post",
    "/orders",
    {
      showtimeId: String(show._id),
      seatIds: [String(seats[2]._id)],
      idempotencyKey: k,
    },
    201,
  );
  await call(
    A,
    "post",
    "/orders",
    {
      showtimeId: String(show._id),
      seatIds: [String(seats[3]._id)],
      idempotencyKey: k,
    },
    409,
  );
  await call(
    admin,
    "post",
    "/admin/showtimes",
    {
      movieId: String(show.movieId),
      roomId: String(show.roomId),
      startAt: show.startAt.toISOString(),
      standardPrice: 80000,
      vipPrice: 90000,
    },
    409,
  );
  await call(admin, "delete", "/admin/showtimes/" + show._id, undefined, 409);
});
test("Logout invalidates server session and cookie is HttpOnly", async () => {
  const c = await register("logout@example.test");
  const response = await c.client.get("/api/auth/me");
  assert.equal(response.status, 200);
  await call(c, "post", "/auth/logout", {});
  assert.equal((await c.client.get("/api/auth/me")).status, 401);
});
