import test from "node:test";
import assert from "node:assert/strict";
import {
  createPaymentUrl,
  verifyCallback,
  parseCallback,
  makeTxnRef,
  orderIdFromTxnRef,
  vnTime,
  bankCodeFor,
} from "../server/payments/vnpay.js";

const cfg = {
  tmnCode: "TESTCODE",
  hashSecret: "secret-for-unit-test",
  payUrl: "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
  returnUrl: "http://localhost:4000/api/payments/vnpay-return",
};
const orderId = "64b7f0c2a1b2c3d4e5f60718";
const txnRef = makeTxnRef(orderId);
const url = new URL(
  createPaymentUrl(cfg, {
    txnRef,
    amount: 160000,
    orderInfo: "Thanh toan ve CineGo",
    ipAddr: "127.0.0.1",
    bankCode: bankCodeFor("atm"),
    createdAt: new Date("2026-10-10T01:00:00Z"),
    expiresAt: new Date("2026-10-10T01:10:00Z"),
  }),
);
const query = () => Object.fromEntries(url.searchParams);

test("URL có số tiền x100, giờ GMT+7 và mã ngân hàng ATM", () => {
  assert.equal(query().vnp_Amount, "16000000");
  assert.equal(query().vnp_CreateDate, "20261010080000");
  assert.equal(query().vnp_ExpireDate, "20261010081000");
  assert.equal(query().vnp_BankCode, "VNBANK");
  assert.equal(vnTime(new Date("2026-10-10T17:30:15Z")), "20261011003015");
});

test("chữ ký hợp lệ được chấp nhận", () => {
  assert.equal(verifyCallback(cfg, query()), true);
});

test("sửa số tiền hoặc sai khóa bí mật thì bị từ chối", () => {
  assert.equal(
    verifyCallback(cfg, { ...query(), vnp_Amount: "100" }),
    false,
  );
  assert.equal(
    verifyCallback({ ...cfg, hashSecret: "khac" }, query()),
    false,
  );
  const { vnp_SecureHash, ...noHash } = query();
  assert.equal(verifyCallback(cfg, noHash), false);
});

test("suy ra orderId và đọc kết quả từ callback", () => {
  assert.equal(orderIdFromTxnRef(txnRef), orderId);
  assert.equal(orderIdFromTxnRef("khong-hop-le"), null);
  const ok = parseCallback({
    vnp_TxnRef: txnRef,
    vnp_Amount: "16000000",
    vnp_ResponseCode: "00",
    vnp_TransactionStatus: "00",
  });
  assert.equal(ok.success, true);
  assert.equal(ok.amount, 160000);
  assert.equal(ok.orderId, orderId);
  assert.equal(
    parseCallback({ ...ok, vnp_ResponseCode: "24" }).success,
    false,
  );
});
