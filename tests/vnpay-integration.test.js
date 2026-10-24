import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { MongoMemoryReplSet } from "mongodb-memory-server";
import request from "supertest";
import mongoose from "mongoose";
process.env.NODE_ENV = "test";
process.env.SESSION_SECRET = "test-only-" + "a".repeat(64);
process.env.PAYMENT_MODE = "vnpay";
process.env.APP_ORIGIN = "http://localhost:5173";
process.env.MONGODB_URI = "mongodb://placeholder";
process.env.VNP_TMN_CODE = "TESTCODE";
process.env.VNP_HASH_SECRET = "test-hash-secret";
process.env.VNP_RETURN_URL = "http://localhost:4000/api/payments/vnpay-return";
process.env.MOMO_PARTNER_CODE = "MOMOTEST";
process.env.MOMO_ACCESS_KEY = "access-key-test";
process.env.MOMO_SECRET_KEY = "secret-key-test";
process.env.MOMO_RETURN_URL = "http://localhost:4000/api/payments/momo-return";
const origin = "http://localhost:5173";
const cfg = {
  tmnCode: "TESTCODE",
  hashSecret: "test-hash-secret",
  payUrl: "x",
  returnUrl: "x",
};
const mcfg = {
  partnerCode: "MOMOTEST",
  accessKey: "access-key-test",
  secretKey: "secret-key-test",
};
let repl, app, M, booking, vnpay, momo, admin, seats, n = 0;

async function register(email) {
  const client = request.agent(app);
  const originalLog = console.log;
  let activationMail = "";
  console.log = (...args) => {
    activationMail += `${args.join(" ")}\n`;
  };
  let registered;
  try {
    registered = await client
      .post("/api/auth/register")
      .set("Origin", origin)
      .send({
        email,
        name: email.split("@")[0],
        password: "Long-test-password-123",
        phone: "",
      });
  } finally {
    console.log = originalLog;
  }
  assert.equal(registered.status, 202, JSON.stringify(registered.body));
  const activationToken = activationMail.match(
    /#\/verify-email\?token=([A-Za-z0-9_-]+)/,
  )?.[1];
  assert.ok(activationToken, activationMail);
  const activation = await client
    .post("/api/auth/verify-email")
    .set("Origin", origin)
    .send({ token: activationToken });
  assert.equal(activation.status, 200, JSON.stringify(activation.body));

  const originalOtpLog = console.log;
  let otpMail = "";
  console.log = (...args) => {
    otpMail += `${args.join(" ")}\n`;
  };
  let login;
  try {
    login = await client
      .post("/api/auth/login")
      .set("Origin", origin)
      .send({ email, password: "Long-test-password-123" });
  } finally {
    console.log = originalOtpLog;
  }
  assert.equal(login.status, 202, JSON.stringify(login.body));
  const code = otpMail.match(/Mã xác thực đăng nhập của bạn là: (\d{6})/)?.[1];
  assert.ok(code, otpMail);
  const verified = await client
    .post("/api/auth/verify-login")
    .set("Origin", origin)
    .send({ challengeId: login.body.challengeId, code });
  assert.equal(verified.status, 200, JSON.stringify(verified.body));
  return {
    client,
    csrf: verified.body.csrf,
    user: verified.body.user,
    email,
  };
}
async function call(agent, method, url, body, expected = 200) {
  const r = await agent.client[method]("/api" + url)
    .set("Origin", origin)
    .set("x-csrf-token", agent.csrf || "")
    .send(body);
  assert.equal(r.status, expected, JSON.stringify(r.body));
  return r.body;
}
// Mỗi test dùng người dùng và ghế riêng để không ảnh hưởng nhau.
async function newOrder(seatCount = 2) {
  const user = await register(`vnp${++n}@example.test`);
  const mine = seats.slice((n - 1) * 2, (n - 1) * 2 + seatCount).map((s) => String(s._id));
  const order = await call(
    user,
    "post",
    "/orders",
    { showtimeId: String(seats[0].showtimeId), seatIds: mine, idempotencyKey: randomUUID() },
    201,
  );
  return { user, order, seatIds: mine };
}
// Giả lập VNPay gọi IPN (không cookie, không Origin).
const ipn = (order, extra = {}, txnRef) =>
  request(app)
    .get("/api/payments/vnpay-ipn")
    .query(
      vnpay.signParams(cfg, {
        vnp_TxnRef: txnRef || vnpay.makeTxnRef(order._id),
        vnp_Amount: String(order.total * 100),
        vnp_ResponseCode: "00",
        vnp_TransactionStatus: "00",
        vnp_TransactionNo: "14000001",
        ...extra,
      }),
    );
const tickets = (order) => M.Ticket.countDocuments({ orderId: order._id });
const payments = (order) => M.Payment.find({ orderId: order._id }).lean();

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
    vnpay = await import("../server/payments/vnpay.js");
    momo = await import("../server/payments/momo.js");
    const catalog = await import("../server/services/catalog.js");
    admin = await register("admin-vnp@example.test");
    await M.User.updateOne({ _id: admin.user.id }, { $set: { role: "admin" } });
    const movie = await M.Movie.create({
      title: "VNPay movie",
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
      rows: 15,
      columns: 6,
    });
    const show = await catalog.saveShowtime(admin.user.id, {
      movieId: String(movie._id),
      roomId: String(room._id),
      startAt: new Date(Date.now() + 72 * 3600000).toISOString(),
      standardPrice: 80000,
      vipPrice: 110000,
    });
    seats = await M.ShowtimeSeat.find({ showtimeId: show._id }).sort({ label: 1 });
  },
  { timeout: 180000 },
);
after(async () => {
  await mongoose.disconnect();
  await repl?.stop();
});

test("pay trả về URL VNPay (ATM -> VNBANK) và pay-demo bị tắt", async () => {
  const { user, order } = await newOrder();
  const r = await call(user, "post", `/orders/${order._id}/pay`, { method: "atm" });
  const url = new URL(r.paymentUrl);
  assert.equal(url.searchParams.get("vnp_BankCode"), "VNBANK");
  assert.equal(url.searchParams.get("vnp_Amount"), String(order.total * 100));
  await call(user, "post", `/orders/${order._id}/pay`, { method: "zalopay" }, 400);
  await call(user, "post", `/orders/${order._id}/pay-demo`, { outcome: "success" }, 503);
});

test("IPN: sai chữ ký -> 97, sai số tiền -> 04, không thấy đơn -> 01", async () => {
  const { order } = await newOrder();
  const bad = await request(app)
    .get("/api/payments/vnpay-ipn")
    .query({ vnp_TxnRef: vnpay.makeTxnRef(order._id), vnp_Amount: "1", vnp_SecureHash: "abc" });
  assert.equal(bad.body.RspCode, "97");
  assert.equal((await ipn(order, { vnp_Amount: "100" })).body.RspCode, "04");
  assert.equal(
    (await ipn(order, {}, "f".repeat(24) + "abc")).body.RspCode,
    "01",
  );
  assert.equal(await tickets(order), 0);
});

test("IPN thành công phát hành vé; gọi lại chỉ trả 02, không tạo thêm", async () => {
  const { order, seatIds } = await newOrder();
  const txn = String(order._id) + "ok1";
  assert.equal((await ipn(order, {}, txn)).body.RspCode, "00");
  assert.equal((await M.Order.findById(order._id)).status, "paid");
  assert.equal(await tickets(order), seatIds.length);
  assert.equal((await ipn(order, {}, txn)).body.RspCode, "02");
  assert.equal(await tickets(order), seatIds.length);
  const list = await payments(order);
  assert.equal(list.length, 1);
  assert.equal(list[0].provider, "vnpay");
});

test("Thanh toán thất bại giữ nguyên đơn; thử lại bằng mã giao dịch mới thì thành công", async () => {
  const { order } = await newOrder();
  const failed = await ipn(
    order,
    { vnp_ResponseCode: "24", vnp_TransactionStatus: "02" },
    String(order._id) + "fail1",
  );
  assert.equal(failed.body.RspCode, "00");
  assert.equal((await M.Order.findById(order._id)).status, "pending");
  assert.equal(await tickets(order), 0);
  assert.equal((await ipn(order, {}, String(order._id) + "ok2")).body.RspCode, "00");
  assert.equal((await M.Order.findById(order._id)).status, "paid");
});

test("Trả tiền hai lần: chỉ một bộ vé, lần hai ghi nhận để đối soát", async () => {
  const { order, seatIds } = await newOrder();
  await ipn(order, {}, String(order._id) + "ok3");
  await ipn(order, {}, String(order._id) + "ok4");
  assert.equal(await tickets(order), seatIds.length);
  const list = await payments(order);
  assert.equal(list.length, 2);
  assert.ok(list.some((p) => p.purpose === "duplicate"));
});

test("Tiền về sau khi đơn đã hủy: không phát vé, ghi nhận late-unfulfilled", async () => {
  const { user, order } = await newOrder();
  await booking.cancelOrder(user.user.id, String(order._id));
  assert.equal((await ipn(order, {}, String(order._id) + "ok5")).body.RspCode, "00");
  assert.equal(await tickets(order), 0);
  const list = await payments(order);
  assert.equal(list.length, 1);
  assert.equal(list[0].purpose, "late-unfulfilled");
});

test("Return URL: chữ ký đúng chuyển tới trang thanh toán, sai chữ ký thì báo invalid", async () => {
  const { order } = await newOrder();
  const ok = await request(app)
    .get("/api/payments/vnpay-return")
    .redirects(0)
    .query(
      vnpay.signParams(cfg, {
        vnp_TxnRef: String(order._id) + "ok6",
        vnp_Amount: String(order.total * 100),
        vnp_ResponseCode: "00",
        vnp_TransactionStatus: "00",
      }),
    );
  assert.equal(ok.status, 302);
  assert.equal(
    ok.headers.location,
    `${origin}/#/tickets?payment=success&order=${order._id}`,
  );
  assert.equal((await M.Order.findById(order._id)).status, "paid");
  const other = (await newOrder()).order;
  const failed = await request(app)
    .get("/api/payments/vnpay-return")
    .redirects(0)
    .query(
      vnpay.signParams(cfg, {
        vnp_TxnRef: String(other._id) + "fail9",
        vnp_Amount: String(other.total * 100),
        vnp_ResponseCode: "24",
        vnp_TransactionStatus: "02",
      }),
    );
  assert.equal(
    failed.headers.location,
    `${origin}/#/checkout/${other._id}?payment=failed`,
  );
  const bad = await request(app)
    .get("/api/payments/vnpay-return")
    .redirects(0)
    .query({ vnp_TxnRef: "x", vnp_SecureHash: "abc" });
  assert.equal(bad.headers.location, `${origin}/#/?payment=invalid`);
});

// ---------------- MoMo ----------------
// Giả lập MoMo gọi IPN (POST JSON, không cookie, không Origin).
const momoData = (order, extra = {}, txnRef) => {
  const data = {
    partnerCode: mcfg.partnerCode,
    orderId: txnRef || vnpay.makeTxnRef(order._id),
    requestId: "req-1",
    amount: order.total,
    orderInfo: "Thanh toan ve CineGo",
    orderType: "momo_wallet",
    transId: 2820000001,
    resultCode: 0,
    message: "Successful.",
    payType: "qr",
    responseTime: 1790000000000,
    extraData: "",
    ...extra,
  };
  return { ...data, signature: momo.signCallback(mcfg, data) };
};
const momoIpn = (order, extra, txnRef) =>
  request(app).post("/api/payments/momo-ipn").send(momoData(order, extra, txnRef));

test("pay bằng MoMo gọi API MoMo, trả payUrl và lưu phương thức", async () => {
  const { user, order } = await newOrder();
  const realFetch = globalThis.fetch;
  let sent;
  globalThis.fetch = async (url, init) => {
    sent = { url, body: JSON.parse(init.body) };
    return {
      ok: true,
      json: async () => ({ resultCode: 0, payUrl: "https://test-payment.momo.vn/pay/xyz" }),
    };
  };
  try {
    const r = await call(user, "post", `/orders/${order._id}/pay`, { method: "momo" });
    assert.equal(r.paymentUrl, "https://test-payment.momo.vn/pay/xyz");
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.equal(sent.body.amount, order.total);
  assert.ok(sent.body.orderId.startsWith(String(order._id)));
  assert.equal(sent.body.requestType, "captureWallet");
  assert.equal((await M.Order.findById(order._id)).paymentMethod, "momo");
});

test("MoMo báo lỗi khi tạo giao dịch thì trả 502, đơn vẫn chờ thanh toán", async () => {
  const { user, order } = await newOrder();
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({ resultCode: 1001, message: "error" }),
  });
  try {
    await call(user, "post", `/orders/${order._id}/pay`, { method: "momo" }, 502);
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.equal((await M.Order.findById(order._id)).status, "pending");
});

test("MoMo IPN: sai chữ ký -> 400; thành công -> 204 và phát vé; gọi lại không tạo thêm", async () => {
  const { order, seatIds } = await newOrder();
  const bad = await request(app)
    .post("/api/payments/momo-ipn")
    .send({ ...momoData(order), amount: 1 });
  assert.equal(bad.status, 400);
  assert.equal(await tickets(order), 0);
  const txn = String(order._id) + "mm1";
  assert.equal((await momoIpn(order, {}, txn)).status, 204);
  assert.equal((await M.Order.findById(order._id)).status, "paid");
  assert.equal(await tickets(order), seatIds.length);
  assert.equal((await momoIpn(order, {}, txn)).status, 204);
  assert.equal(await tickets(order), seatIds.length);
  const list = await payments(order);
  assert.equal(list.length, 1);
  assert.equal(list[0].provider, "momo");
});

test("MoMo thất bại giữ nguyên đơn; return URL chuyển đúng trang", async () => {
  const { order } = await newOrder();
  const failedIpn = await momoIpn(order, { resultCode: 1006, message: "Denied" }, String(order._id) + "mm2");
  assert.equal(failedIpn.status, 204);
  assert.equal((await M.Order.findById(order._id)).status, "pending");
  const failedRet = await request(app)
    .get("/api/payments/momo-return")
    .redirects(0)
    .query(momoData(order, { resultCode: 1006, message: "Denied" }, String(order._id) + "mm3"));
  assert.equal(failedRet.headers.location, `${origin}/#/checkout/${order._id}?payment=failed`);
  const ok = await request(app)
    .get("/api/payments/momo-return")
    .redirects(0)
    .query(momoData(order, {}, String(order._id) + "mm4"));
  assert.equal(ok.headers.location, `${origin}/#/tickets?payment=success&order=${order._id}`);
  assert.equal((await M.Order.findById(order._id)).status, "paid");
  const bad = await request(app)
    .get("/api/payments/momo-return")
    .redirects(0)
    .query({ orderId: "x", signature: "abc" });
  assert.equal(bad.headers.location, `${origin}/#/?payment=invalid`);
});


test("Cùng mã: thất bại rồi thành công phát vé đúng một lần", async () => {
  const { order, seatIds } = await newOrder();
  const txn = String(order._id) + "recover";
  await ipn(order, { vnp_ResponseCode: "24", vnp_TransactionStatus: "02" }, txn);
  const previous = (await payments(order))[0];
  assert.equal(previous.status, "failed");
  assert.equal((await ipn(order, {}, txn)).body.RspCode, "00");
  assert.equal((await ipn(order, {}, txn)).body.RspCode, "02");
  await ipn(order, { vnp_ResponseCode: "24", vnp_TransactionStatus: "02" }, txn);
  const list = await payments(order);
  assert.equal(list.length, 1);
  assert.equal(String(list[0]._id), String(previous._id));
  assert.equal(list[0].status, "success");
  assert.equal(await tickets(order), seatIds.length);
});

test("Cùng mã: thất bại, hủy đơn, rồi thành công được ghi đối soát", async () => {
  const { user, order } = await newOrder();
  const txn = String(order._id) + "late-recover";
  await ipn(order, { vnp_ResponseCode: "24", vnp_TransactionStatus: "02" }, txn);
  await booking.cancelOrder(user.user.id, String(order._id));
  assert.equal((await ipn(order, {}, txn)).body.RspCode, "00");
  assert.equal((await ipn(order, {}, txn)).body.RspCode, "02");
  const list = await payments(order);
  assert.equal(list.length, 1);
  assert.equal(list[0].status, "success");
  assert.equal(list[0].purpose, "late-unfulfilled");
  assert.equal(await tickets(order), 0);
});

test('Kho: giữ, hết hàng, hủy giữ và hết hạn trả tồn; không gọi database thật',async()=>{
 const sh=await M.Showtime.findById(seats[0].showtimeId);
 const product=await M.Snack.create({cinemaId:sh.cinemaId,name:'Combo test',price:50000,stock:2});
 const u=await register('stock-test@example.test');
 const input={cinemaId:String(sh.cinemaId),pickupDate:'2099-01-01',snacks:[{snackId:String(product._id),quantity:2}],idempotencyKey:randomUUID()};
 const order=await booking.holdSnackOrder(u.user.id,input);
 assert.equal((await M.Snack.findById(product._id)).held,2);
 assert.equal(String((await booking.holdSnackOrder(u.user.id,input))._id),String(order._id));
 await assert.rejects(()=>booking.holdSnackOrder(u.user.id,{...input,idempotencyKey:randomUUID()}),/tồn/);
 await booking.cancelOrder(u.user.id,order._id);
 assert.equal((await M.Snack.findById(product._id)).held,0);
 const next=await booking.holdSnackOrder(u.user.id,{...input,idempotencyKey:randomUUID()});
 await M.Order.updateOne({_id:next._id},{$set:{expiresAt:new Date(0)}});await booking.releaseExpired();
 assert.equal((await M.Snack.findById(product._id)).held,0);
});
test('Bỏng nước riêng: trả tiền, nhận mã, hủy hoàn mô phỏng và trả tồn một lần',async()=>{
 const sh=await M.Showtime.findById(seats[0].showtimeId);
 const p=await M.Snack.create({cinemaId:sh.cinemaId,name:'Nước test',price:30000,stock:3});
 const u=await register('snack-paid@example.test');
 const o=await booking.holdSnackOrder(u.user.id,{cinemaId:String(sh.cinemaId),pickupDate:'2099-01-01',snacks:[{snackId:String(p._id),quantity:2}],idempotencyKey:randomUUID()});
 await ipn(o,{},String(o._id)+'snack');
 const line=await M.SnackLine.findOne({orderId:o._id});assert.ok(line.pickupCode);assert.equal((await M.Snack.findById(p._id)).stock,1);
 const {cancelStandalone}=await import('../server/services/concessions.js');
 await cancelStandalone(u.user.id,[{lineId:String(line._id),quantity:2}]);
 assert.equal((await M.Snack.findById(p._id)).stock,3);
 assert.equal((await M.SnackLine.findById(line._id)).remaining,0);
 await assert.rejects(()=>cancelStandalone(u.user.id,[{lineId:String(line._id),quantity:2}]));
 assert.equal((await M.Refund.find({snackLineId:line._id})).length,1);
});
test('Đổi khác phim sang suất dưới 12h: giữ món khi tồn 0, chuyển tín dụng, hủy vé cũ chỉ khi hoàn tất',async()=>{
 const u=await register('cross-movie@example.test');
 const source=await M.Showtime.findById(seats[0].showtimeId);
 const p=await M.Snack.create({cinemaId:source.cinemaId,name:'Last combo',price:40000,stock:1});
 const mine=seats.slice(60,61);
 const o=await booking.hold(u.user.id,{showtimeId:String(source._id),seatIds:mine.map(s=>String(s._id)),snacks:[{snackId:String(p._id),quantity:1}],idempotencyKey:randomUUID()});
 await ipn(o,{},String(o._id)+'old');
 const t=await M.Ticket.findOne({orderId:o._id});
 const oldLine=await M.SnackLine.findOne({orderId:o._id});
 const movie=await M.Movie.create({title:'Phim khác',genre:'Drama',duration:90,synopsis:'Test'});
 const target=await M.Showtime.create({movieId:movie._id,cinemaId:source.cinemaId,roomId:source.roomId,startAt:new Date(Date.now()+4*3600000),endAt:new Date(Date.now()+6*3600000),standardPrice:50000,vipPrice:50000});
 const seat=await M.ShowtimeSeat.create({showtimeId:target._id,seatId:mine[0].seatId,label:'A1',type:'standard',price:50000});
 const change=await booking.exchange(u.user.id,t._id,{seatId:String(seat._id),snacks:[{snackId:String(p._id),quantity:1}],snackChanges:[{lineId:String(oldLine._id),quantity:1}],idempotencyKey:randomUUID()});
 assert.equal(String((await M.Ticket.findById(t._id)).showtimeId),String(source._id));
 assert.equal((await M.SnackLine.findById(oldLine._id)).remaining,1);
 const result=await booking.startGatewayPayment(u.user.id,change._id,'vnpay','127.0.0.1');assert.equal(result.paid,true);
 assert.equal(String((await M.Ticket.findById(t._id)).showtimeId),String(target._id));
 assert.equal((await M.SnackLine.findById(oldLine._id)).remaining,0);
 assert.equal((await M.Snack.findById(p._id)).stock,0);
 const renewed=await M.SnackLine.findOne({orderId:change._id});assert.equal(renewed.remaining,1);
 await assert.rejects(()=>booking.cancelTicket(u.user.id,t._id),/12 tiếng/);
});
test('Tài khoản bị khóa: đúng mật khẩu có thông báo khóa, sai mật khẩu không tiết lộ trạng thái',async()=>{
 await M.User.create({name:'Blocked',email:'blocked@example.test',passwordHash:(await M.User.findById(admin.user.id)).passwordHash,active:false});
 const good=await request(app).post('/api/auth/login').set('Origin',origin).send({email:'blocked@example.test',password:'Long-test-password-123'});
 assert.equal(good.status,403);assert.match(good.body.message,/bị khóa/);
 const bad=await request(app).post('/api/auth/login').set('Origin',origin).send({email:'blocked@example.test',password:'wrong'});assert.equal(bad.status,401);
});
