import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requireAdmin } from '../auth.js';
import { Snack, SnackLine, Cinema, Order, Ticket, Showtime, ShowtimeSeat, ChangeRequest, Payment, Refund, RevenueEntry } from '../models.js';
import { body, objectId, parseId, route, fail, transaction, audit } from '../core.js';
import { holdSnackOrder } from '../services/booking.js';
import { cancelStandalone, linkedLines, withSnackImages } from '../services/concessions.js';
export const snackSelections = z.array(z.object({snackId:objectId,quantity:z.number().int().min(1).max(50)}).strict()).max(30).refine(a=>new Set(a.map(x=>x.snackId)).size===a.length);
export const snackChanges = z.array(z.object({lineId:objectId,quantity:z.number().int().min(1).max(50)}).strict()).max(100).refine(a=>new Set(a.map(x=>x.lineId)).size===a.length);
export const concessionsRouter=Router();
concessionsRouter.get('/snacks',route(async(req,res)=>{
 const cinemaId=parseId(req.query.cinemaId);
 res.json((await Snack.find({cinemaId,active:true}).lean()).map(x=>({...x,available:x.stock-x.held})));
}));
concessionsRouter.use(requireAuth);
concessionsRouter.post('/snack-orders',body(z.object({cinemaId:objectId,pickupDate:z.string().date(),snacks:snackSelections.refine(a=>a.length>0),idempotencyKey:z.string().uuid()}).strict()),route(async(req,res)=>res.status(201).json(await holdSnackOrder(req.user._id,req.data))));
concessionsRouter.get('/snack-orders',route(async(req,res)=>{
 const lines=await SnackLine.find({userId:req.user._id}).sort({createdAt:-1}).limit(500).lean();
 const cinemas=await Cinema.find({_id:{$in:lines.map(l=>l.cinemaId)}}).lean();res.json({lines:await withSnackImages(lines),cinemas});
}));
concessionsRouter.get('/tickets/:id/snacks',route(async(req,res)=>{
 const t=await Ticket.findOne({_id:parseId(req.params.id),userId:req.user._id});if(!t)fail(404,'Không tìm thấy vé.');
 const lines=await linkedLines(t,null);
 const other=await Ticket.countDocuments({orderId:t.orderId,_id:{$ne:t._id},status:'valid',showtimeId:t.showtimeId});
 res.json({lines:await withSnackImages(lines),allRequired:other===0});
}));
concessionsRouter.post('/snack-orders/cancel',body(z.object({items:snackChanges.refine(a=>a.length>0)}).strict()),route(async(req,res)=>res.json(await cancelStandalone(req.user._id,req.data.items))));
export const commerceAdminRouter=Router();
commerceAdminRouter.use(requireAuth,requireAdmin);
const product=z.object({cinemaId:objectId,name:z.string().trim().min(1).max(150),image:z.string().max(2048).refine(x=>x===''||/^https:\/\//.test(x)),price:z.number().int().min(1000).max(1000000),active:z.boolean(),stock:z.number().int().min(0).max(1000000)}).strict();
commerceAdminRouter.get('/snacks',route(async(req,res)=>res.json(await Snack.find().sort({createdAt:-1}).lean())));
commerceAdminRouter.post('/snacks',body(product),route(async(req,res)=>{
 if(!await Cinema.exists({_id:req.data.cinemaId}))fail(404,'Rạp không tồn tại.');
 res.status(201).json(await Snack.create(req.data));
}));
commerceAdminRouter.put('/snacks/:id',body(product),route(async(req,res)=>res.json(await transaction(async session=>{
 const old=await Snack.findById(parseId(req.params.id)).session(session);if(!old)fail(404,'Không có sản phẩm.');
 if(String(old.cinemaId)!==req.data.cinemaId)fail(400,'Không chuyển sản phẩm sang rạp khác; hãy tạo sản phẩm tại rạp mới.');
 if(req.data.stock<old.held)fail(409,'Tồn kho không được nhỏ hơn số lượng đang giữ.');
 Object.assign(old,req.data);await old.save({session});await audit(req.user._id,'stock.updated',old._id,session,{stock:old.stock});return old;
}))));
commerceAdminRouter.get('/snack-pickups',route(async(req,res)=>res.json(await SnackLine.find({remaining:{$gt:0},collected:false}).sort({createdAt:-1}).limit(500).lean())));
commerceAdminRouter.post('/snack-pickups/:id/collect',body(z.object({code:z.string().min(1).max(64)}).strict()),route(async(req,res)=>res.json(await transaction(async session=>{
 const line=await SnackLine.findById(parseId(req.params.id)).session(session);
 if(!line || line.pickupCode!==req.data.code.trim().toUpperCase())fail(400,'Mã nhận hàng không đúng.');
 if(line.collected)return line;
 if(!line.remaining||line.reservedBy)fail(409,'Đơn đã hủy hoặc đang đổi.');
 line.collected=true;await line.save({session});await audit(req.user._id,'snacks.collected',line._id,session);return line;
}))));
commerceAdminRouter.get('/revenue',route(async(req,res)=>{
 const q=z.object({from:z.string().date(),to:z.string().date(),cinemaId:objectId.optional()}).parse(req.query);
 const from=new Date(q.from+'T00:00:00+07:00'), to=new Date(q.to+'T23:59:59.999+07:00');
 if(from>to||to-from>366*86400000)fail(400,'Chọn khoảng báo cáo tối đa 366 ngày.');
 const scope={createdAt:{$gte:from,$lte:to}};
 const entries=await RevenueEntry.find({...scope,...(q.cinemaId?{cinemaId:q.cinemaId}:{})}).lean();
 // Backward compatibility: legacy transactions were ticket-only.
 const ps=await Payment.find({...scope,status:'success'}).lean();
 const orderIds=ps.map(p=>p.orderId);
 const orders=await Order.find({_id:{$in:orderIds}}).lean();
 const shows=await Showtime.find({_id:{$in:orders.map(o=>o.showtimeId).filter(Boolean)}}).lean();
 const cinemaFor=o=>String(o?.cinemaId||shows.find(s=>String(s._id)===String(o?.showtimeId))?.cinemaId||'');
 const mapped=new Set((await RevenueEntry.find({paymentId:{$in:ps.map(p=>p._id)}}).select('paymentId').lean()).map(e=>String(e.paymentId)));
 const reconciliation=[];
 for(const p of ps){const o=orders.find(o=>String(o._id)===String(p.orderId));const cinemaId=cinemaFor(o);if(q.cinemaId&&cinemaId!==q.cinemaId)continue;
  if(['duplicate','late-unfulfilled'].includes(p.purpose)){reconciliation.push(p);continue;}
  if(!mapped.has(String(p._id)))entries.push({createdAt:p.createdAt,cinemaId,description:'Thanh toán vé trước cập nhật',ticketNet:p.amount,snackNet:0,received:p.amount,returned:0});
 }
 // Refunds after the update are represented by RevenueEntry, including partial exchanges.
 const refunds=await Refund.find({...scope,status:'success'}).lean();
 for(const r of refunds){if(r.reportVersion===1)continue;
  const t=r.ticketId?await Ticket.findById(r.ticketId).lean():null;
  const line=r.snackLineId?await SnackLine.findById(r.snackLineId).lean():null;
  const change=await ChangeRequest.findById(r.requestId).lean();
  const oldSeat=change?.oldSeatId?await ShowtimeSeat.findById(change.oldSeatId).lean():null;
  const sh=(oldSeat?.showtimeId||t?.showtimeId)?await Showtime.findById(oldSeat?.showtimeId||t.showtimeId).lean():null;const cinemaId=String(line?.cinemaId||sh?.cinemaId||'');
  if(q.cinemaId&&cinemaId!==q.cinemaId)continue;
  entries.push({createdAt:r.createdAt,cinemaId,description:'Hoàn vé trước cập nhật',ticketNet:-r.amount,snackNet:0,received:0,returned:r.amount});
 }
 entries.sort((a,b)=>new Date(a.createdAt)-new Date(b.createdAt));
 const totals={received:0,returned:0,ticketNet:0,snackNet:0};const days={};
 for(const e of entries){const day=new Date(e.createdAt).toLocaleDateString('en-CA',{timeZone:'Asia/Ho_Chi_Minh'});days[day]??={day,received:0,returned:0,ticketNet:0,snackNet:0};for(const k of Object.keys(totals)){totals[k]+=e[k]||0;days[day][k]+=e[k]||0;}}
 res.json({totals,days:Object.values(days),entries,reconciliation,testMode:true});
}));
