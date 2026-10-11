import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import {
  buildCreateRequest,
  createPayment,
  signCallback,
  verifyCallback,
  parseCallback,
} from "../server/payments/momo.js";
import { makeTxnRef } from "../server/payments/vnpay.js";

const cfg = {
  partnerCode: "MOMOTEST",
  accessKey: "access-key-test",
  secretKey: "secret-key-test",
  apiUrl: "https://test-payment.momo.vn/v2/gateway/api/create",
  returnUrl: "http://localhost:4000/api/payments/momo-return",
  ipnUrl: "http://localhost:4000/api/payments/momo-ipn",
};
const orderId = "64b7f0c2a1b2c3d4e5f60718";
const txnRef = makeTxnRef(orderId);

test("yêu cầu tạo giao dịch ký đúng định dạng MoMo (HMAC-SHA256, khóa xếp theo chữ cái)", () => {
  const body = buildCreateRequest(cfg, {
    txnRef,
    amount: 110000,
    orderInfo: "Thanh toan ve CineGo",
  });
  const raw =
    `accessKey=access-key-test&amount=110000&extraData=&ipnUrl=${cfg.ipnUrl}` +
    `&orderId=${txnRef}&orderInfo=Thanh toan ve CineGo&partnerCode=MOMOTEST` +
    `&redirectUrl=${cfg.returnUrl}&requestId=${txnRef}&requestType=captureWallet`;
  assert.equal(
    body.signature,
    createHmac("sha256", "secret-key-test").update(raw).digest("hex"),
  );
  assert.equal(body.requestType, "captureWallet");
  assert.equal(body.orderId, txnRef);
  assert.equal(body.amount, 110000);
});

test("requestType cấu hình được và nằm trong chữ ký; body có accessKey như mẫu MoMo", () => {
  const input = { txnRef, amount: 50000, orderInfo: "pay" };
  const atm = buildCreateRequest({ ...cfg, requestType: "payWithATM" }, input);
  const raw =
    `accessKey=access-key-test&amount=50000&extraData=&ipnUrl=${cfg.ipnUrl}` +
    `&orderId=${txnRef}&orderInfo=pay&partnerCode=MOMOTEST` +
    `&redirectUrl=${cfg.returnUrl}&requestId=${txnRef}&requestType=payWithATM`;
  assert.equal(atm.requestType, "payWithATM");
  assert.equal(
    atm.signature,
    createHmac("sha256", "secret-key-test").update(raw).digest("hex"),
  );
  assert.equal(atm.accessKey, "access-key-test");
});

const callback = (extra = {}) => {
  const data = {
    partnerCode: "MOMOTEST",
    orderId: txnRef,
    requestId: txnRef,
    amount: 110000,
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
  return { ...data, signature: signCallback(cfg, data) };
};

test("callback hợp lệ được chấp nhận; sửa số tiền, sai khóa hoặc sai partner thì bị từ chối", () => {
  assert.equal(verifyCallback(cfg, callback()), true);
  assert.equal(verifyCallback(cfg, { ...callback(), amount: 1000 }), false);
  assert.equal(
    verifyCallback({ ...cfg, secretKey: "khac" }, callback()),
    false,
  );
  assert.equal(
    verifyCallback(cfg, callback({ partnerCode: "KHAC" })),
    false,
  );
  const { signature, ...noSig } = callback();
  assert.equal(verifyCallback(cfg, noSig), false);
  assert.equal(verifyCallback(cfg, undefined), false);
});

test("giá trị dạng chuỗi (return URL) và dạng số (IPN JSON) ký giống nhau", () => {
  const asString = Object.fromEntries(
    Object.entries(callback()).map(([k, v]) => [k, String(v)]),
  );
  assert.equal(verifyCallback(cfg, asString), true);
});

test("đọc kết quả: resultCode 0 là thành công, mã khác là thất bại", () => {
  const ok = parseCallback(callback());
  assert.equal(ok.success, true);
  assert.equal(ok.provider, "momo");
  assert.equal(ok.orderId, orderId);
  assert.equal(ok.amount, 110000);
  assert.equal(parseCallback(callback({ resultCode: 1006 })).success, false);
});

test("createPayment trả payUrl khi MoMo báo thành công, ném lỗi khi thất bại", async () => {
  let sent;
  const good = async (url, init) => {
    sent = { url, body: JSON.parse(init.body) };
    return {
      ok: true,
      json: async () => ({ resultCode: 0, payUrl: "https://test-payment.momo.vn/pay/abc" }),
    };
  };
  const input = { txnRef, amount: 110000, orderInfo: "Thanh toan ve CineGo" };
  const r = await createPayment(cfg, input, good);
  assert.equal(r.payUrl, "https://test-payment.momo.vn/pay/abc");
  assert.equal(sent.url, cfg.apiUrl);
  assert.equal(sent.body.partnerCode, "MOMOTEST");
  const failed = async () => ({
    ok: true,
    json: async () => ({ resultCode: 1001, message: "Insufficient" }),
  });
  await assert.rejects(createPayment(cfg, input, failed), /resultCode=1001/);
  const insecure = async () => ({
    ok: true,
    json: async () => ({ resultCode: 0, payUrl: "http://evil.example/x" }),
  });
  await assert.rejects(createPayment(cfg, input, insecure), /https/);
});
