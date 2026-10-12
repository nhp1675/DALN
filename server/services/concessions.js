import {config} from '../config.js';
import { randomBytes } from 'node:crypto';
import { Snack, SnackLine, Order, Ticket, Showtime, Cinema, Allocation, Refund, RevenueEntry, User } from '../models.js';
import { create, fail, same, transaction, audit } from '../core.js';
export const cutoffMs = 12 * 3600000;
export function ensureChangeTime(startAt, now = Date.now()) {
  if (!startAt || !Number.isFinite(new Date(startAt).getTime()) || new Date(startAt).getTime() - now < cutoffMs)
    fail(409, 'Không thể hủy hoặc đổi vé khi còn dưới 12 tiếng trước suất chiếu.');
}
export const selectionKey = (snacks = [], changes = []) => JSON.stringify([
  [...snacks].sort((a,b)=>a.snackId.localeCompare(b.snackId)),
  [...changes].sort((a,b)=>a.lineId.localeCompare(b.lineId)),
]);
export async function reserveSnacks(cinemaId, selections, session, reusable = []) {
  const cinema = await Cinema.findOne({ _id: cinemaId, active: true }).session(session);
  if (!cinema) fail(409, 'Rạp không còn hoạt động.');
  const lines = [];
  for (const x of selections) {
    const reused = Math.min(x.quantity,reusable.filter(l=>same(l.snackId,x.snackId)).reduce((n,l)=>n+l.quantity,0));
    const heldQuantity=x.quantity-reused;
    const snack = await Snack.findOneAndUpdate(
      {_id:x.snackId, cinemaId, active:true, $expr:{$gte:[{$subtract:['$stock','$held']},heldQuantity]}},
      {$inc:{held:heldQuantity}}, {new:true,session});
    if (!snack) fail(409, 'Bỏng nước không đủ tồn hoặc đã ngừng bán. Vui lòng chọn lại.');
    lines.push({snackId:snack._id, name:snack.name, price:snack.price, quantity:x.quantity, heldQuantity});
  }
  return lines;
}
export async function releaseSnacks(order, session) {
  for (const x of order.snacks || []) {
    const r = await Snack.updateOne({_id:x.snackId, held:{$gte:x.heldQuantity??x.quantity}}, {$inc:{held:-(x.heldQuantity??x.quantity)}}, {session});
    if (r.matchedCount !== 1) fail(409, 'Tồn kho giữ chỗ không khớp.');
  }
  await SnackLine.updateMany({reservedBy:order._id},{$unset:{reservedBy:1}},{session});
}
export async function linkedLines(ticket, session) {
  return SnackLine.find({userId:ticket.userId, remaining:{$gt:0}, collected:false,
    $or:[{ticketId:ticket._id},{orderId:ticket.orderId,ticketId:{$exists:false},showtimeId:ticket.showtimeId}]}).session(session);
}
export async function selectChanges(ticket, selections, orderId, session, autoLast=true) {
  // Serialize edits to shared concessions of a multi-ticket order.
  await Order.updateOne({_id:ticket.orderId},{$set:{updatedAt:new Date()}},{session});
  const available = await linkedLines(ticket,session);
  const others = await Ticket.countDocuments({orderId:ticket.orderId,_id:{$ne:ticket._id},status:'valid',showtimeId:ticket.showtimeId}).session(session);
  const sharedAvailable = available.filter(l=>l.ticketId || same(l.showtimeId,ticket.showtimeId));
  const wanted = autoLast && !others ? sharedAvailable.map(l=>({lineId:String(l._id),quantity:l.remaining})) : selections;
  const result=[];
  for (const x of wanted) {
    const l=sharedAvailable.find(a=>same(a._id,x.lineId));
    if (!l || x.quantity>l.remaining || l.collected) fail(409,'Phần bỏng nước đã thay đổi hoặc đã nhận.');
    if (l.reservedBy) fail(409,'Bỏng nước đang được giữ cho yêu cầu đổi khác. Hãy hoàn tất hoặc hủy yêu cầu đó.');
    if(orderId) {l.reservedBy=orderId;await l.save({session});}
    result.push({lineId:l._id,quantity:x.quantity,price:l.price,name:l.name,snackId:l.snackId});
  }
  return result;
}
// Move funding between items without pretending that credit transfers are cash receipts.
export async function takeCredit(filter, amount, session) {
  let left=amount; const funds=[];
  for(const a of await Allocation.find(filter).sort({createdAt:1}).session(session)) {
    const n=Math.min(left,a.amount-a.refunded); if(n<=0) continue;
    a.amount-=n; await a.save({session}); funds.push({paymentId:a.paymentId,amount:n}); left-=n;
  }
  if(left) fail(409,'Không đủ số tiền phân bổ để hoàn/đổi.');
  return funds;
}
export async function allocate(funds, filter, amount, session) {
  let left=amount;
  for(const f of funds) {
    const n=Math.min(left,f.amount);if(!n)continue;
    await Allocation.findOneAndUpdate({...filter,paymentId:f.paymentId},
      {$inc:{amount:n},$setOnInsert:{refunded:0}},{upsert:true,new:true,session,runValidators:true});
    f.amount-=n;left-=n;
  }
  if(left)fail(409,'Số tiền thanh toán không khớp.');
}
export async function refundCredit(funds, entity, requestId, session) {
  let total=0;
  for(const f of funds) if(f.amount>0) {
    await create(Refund,{...entity,paymentId:f.paymentId,requestId,amount:f.amount,status:'success',provider:'demo',reportVersion:1},session);
    total+=f.amount;f.amount=0;
  }
  return total;
}
export async function removeLines(order, session) {
  const funds=[];
  for(const x of order.snackChanges || []) {
    const l=await SnackLine.findOne({_id:x.lineId,userId:order.userId,collected:false,remaining:{$gte:x.quantity},reservedBy:order._id}).session(session);
    if(!l)fail(409,'Bỏng nước cũ không còn đủ điều kiện đổi.');
    funds.push(...await takeCredit({snackLineId:l._id},l.price*x.quantity,session));
    l.remaining-=x.quantity;l.reservedBy=undefined;await l.save({session});
    await Snack.updateOne({_id:l.snackId},{$inc:{stock:x.quantity}},{session});
  }
  return funds;
}
export async function fulfillSnacks(order, funds, session) {
  for(const x of order.snacks || []) {
    const r=await Snack.updateOne({_id:x.snackId,held:{$gte:x.heldQuantity??x.quantity},stock:{$gte:x.quantity}},{$inc:{held:-(x.heldQuantity??x.quantity),stock:-x.quantity}},{session});
    if(r.modifiedCount!==1)fail(409,'Không thể xuất kho bỏng nước.');
    const l=await create(SnackLine,{userId:order.userId,orderId:order._id,cinemaId:order.cinemaId,
      snackId:x.snackId,name:x.name,price:x.price,quantity:x.quantity,remaining:x.quantity,pickupDate:order.pickupDate,showtimeId:order.showtimeId,
      ...(order.exchangeTicketId?{ticketId:order.exchangeTicketId}:{}),pickupCode:randomBytes(8).toString('hex').toUpperCase()},session);
    await allocate(funds,{ticketId:l._id,snackLineId:l._id},x.price*x.quantity,session);
  }
}
export async function cancelLines(userId, selections, session, {ticket=null,requestId=null}={}) {
  let total=0;
  for(const x of selections) {
    const l=await SnackLine.findOne({_id:x.lineId,userId}).session(session);
    if(!l || l.collected || l.remaining<x.quantity || l.reservedBy)fail(409,'Bỏng nước đã nhận, đang đổi hoặc không đủ số lượng để hủy.');
    if(l.showtimeId && !ticket) {
      const show=await Showtime.findById(l.showtimeId).session(session);ensureChangeTime(show?.startAt);
    }
    const amount=l.price*x.quantity;
    const funds=await takeCredit({snackLineId:l._id},amount,session);
    await refundCredit(funds,{snackLineId:l._id},requestId||l._id,session);
    l.remaining-=x.quantity;await l.save({session});
    await Snack.updateOne({_id:l.snackId},{$inc:{stock:x.quantity}},{session});
    await create(RevenueEntry,{cinemaId:l.cinemaId,description:'Hủy bỏng nước (hoàn mô phỏng)',orderId:l.orderId,snackNet:-amount,returned:amount},session);
    total+=amount;
  }
  if(total)await User.updateOne({_id:userId},{$inc:{netSpend:-total}},{session});
  return total;
}
export async function cancelStandalone(userId,selections) {
  if(config.NODE_ENV==="production" || config.PAYMENT_MODE==="disabled")fail(503,"Hoàn tiền mô phỏng chỉ dùng trong môi trường thử nghiệm.");
  return transaction(async session=>{
    await User.updateOne({_id:userId},{$inc:{bookingRevision:1}},{session});
    const refunded=await cancelLines(userId,selections,session);
    await audit(userId,'snacks.cancelled',null,session,{refunded});return {refunded};
  });
}
