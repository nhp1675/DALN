import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
process.env.NODE_ENV='test';process.env.SESSION_SECRET='commerce-test-'+ 'x'.repeat(64);
process.env.MONGODB_URI='mongodb://placeholder';process.env.PAYMENT_MODE='demo';
const {ensureChangeTime,selectionKey}=await import('../server/services/concessions.js');
const {snackSelections,snackChanges}=await import('../server/routes/concessions.js');
const {app}=await import('../server/app.js');
const {Snack,SnackLine}=await import('../server/models.js');
test('12h boundary: exactly 12h allowed, 1ms less blocked, old show blocked',()=>{
 const now=Date.UTC(2026,9,12,1);
 assert.doesNotThrow(()=>ensureChangeTime(new Date(now+12*3600000),now));
 assert.throws(()=>ensureChangeTime(new Date(now+12*3600000-1),now),/12 tiếng/);
 assert.throws(()=>ensureChangeTime(new Date(now-1),now),/12 tiếng/);
 assert.throws(()=>ensureChangeTime('invalid',now),/12 tiếng/);
});
test('Concession input rejects fractions, negative counts, duplicates and price injection',()=>{
 const id='a'.repeat(24);assert.equal(snackSelections.safeParse([{snackId:id,quantity:2}]).success,true);
 for(const quantity of [0,-1,1.5,51])assert.equal(snackSelections.safeParse([{snackId:id,quantity}]).success,false);
 assert.equal(snackSelections.safeParse([{snackId:id,quantity:1,price:1}]).success,false);
 assert.equal(snackSelections.safeParse([{snackId:id,quantity:1},{snackId:id,quantity:2}]).success,false);
 assert.equal(snackChanges.safeParse([{lineId:id,quantity:1.2}]).success,false);
});
test('Idempotency compares quantities and normalizes product ordering',()=>{
 const a={snackId:'a',quantity:1},b={snackId:'b',quantity:2};
 assert.equal(selectionKey([a,b]),selectionKey([b,a]));assert.notEqual(selectionKey([a]),selectionKey([{...a,quantity:2}]));
});
test('Inventory schema rejects negative or fractional stock',()=>{
 for(const stock of [-1,1.5]){const p=new Snack({cinemaId:'a'.repeat(24),name:'Popcorn',price:50000,stock});assert.ok(p.validateSync());}
});
test('New order, stock, pickup and revenue endpoints require authentication',async()=>{
 for(const path of ['/api/snack-orders','/api/admin/snacks','/api/admin/snack-pickups','/api/admin/revenue?from=2026-10-01&to=2026-10-12'])assert.equal((await request(app).get(path)).status,401);
});
test('Đổi vé: tín dụng cũ + tiền trả thêm chỉ phân bổ một lần; phần dư mới được hoàn',async(t)=>{
 const {allocate,refundCredit}=await import('../server/services/concessions.js');
 const {Allocation,Refund}=await import('../server/models.js');
 const assigned=[],refunds=[];
 t.mock.method(Allocation,'findOneAndUpdate',async(filter,update)=>{assigned.push({...filter,amount:update.$inc.amount});return {};});
 t.mock.method(Refund,'create',async(rows)=>{refunds.push(...rows);return rows;});
 const funds=[{paymentId:'cash',amount:20000},{paymentId:'old-ticket',amount:80000},{paymentId:'old-snack',amount:40000}];
 await allocate(funds,{ticketId:'new-ticket'},100000,null);
 await allocate(funds,{ticketId:'new-line',snackLineId:'new-line'},20000,null);
 assert.equal(assigned.reduce((n,x)=>n+x.amount,0),120000);
 const returned=await refundCredit(funds,{ticketId:'new-ticket'},'exchange',null);
 assert.equal(returned,20000);assert.equal(refunds.length,1);assert.equal(refunds[0].reportVersion,1);
 assert.equal(funds.reduce((n,x)=>n+x.amount,0),0);
 assert.equal(await refundCredit(funds,{ticketId:'new-ticket'},'exchange',null),0);
});
test('Không sử dụng lại phần tiền đã được hoàn trước đó',async(t)=>{
 const {takeCredit}=await import('../server/services/concessions.js');
 const {Allocation}=await import('../server/models.js');
 const old={paymentId:'old',amount:100000,refunded:20000,save:async()=>{}};
 t.mock.method(Allocation,'find',()=>({sort:()=>({session:async()=>[old]})}));
 const credit=await takeCredit({ticketId:'ticket'},80000,null);
 assert.equal(credit[0].amount,80000);assert.equal(old.amount-old.refunded,0);
 await assert.rejects(()=>takeCredit({ticketId:'ticket'},1,null),/Không đủ/);
});
