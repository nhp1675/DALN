import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
process.env.NODE_ENV = 'test';
process.env.SESSION_SECRET = 'return-unit-' + 'x'.repeat(64);
process.env.MONGODB_URI = 'mongodb://placeholder';
process.env.APP_ORIGIN = 'http://localhost:5173';
process.env.PAYMENT_MODE = 'online';
process.env.VNP_TMN_CODE = 'TESTCODE';
process.env.VNP_HASH_SECRET = 'unit-only-secret';
process.env.VNP_RETURN_URL = 'http://localhost:4000/api/payments/vnpay-return';
const { app } = await import('../server/app.js');
test('Return callback redirects to frontend origin, not backend origin', async () => {
  const response = await request(app).get('/api/payments/vnpay-return')
    .query({ vnp_TxnRef: 'invalid', vnp_SecureHash: 'invalid' });
  assert.equal(response.status, 302);
  assert.equal(response.headers.location, 'http://localhost:5173/#/?payment=invalid');
});
