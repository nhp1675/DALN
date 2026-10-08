import {Router} from 'express';
import {z} from 'zod';
import {ChatRoom, ChatBan, Message, Showtime, Movie, Cinema, User} from '../models.js';
import {route, body, parseId, fail, transaction, audit} from '../core.js';
// Mounted exclusively after requireAuth + requireAdmin. Mutations also inherit CSRF.
export const moderationRouter = Router();
const pageSchema = z.coerce.number().int().min(1).max(100000).default(1);
const reason = z.string().trim().min(3).max(500);
export const moderationSchema = z.object({value: z.boolean(), reason}).strict();
async function room(id, session = null) {
 const r = await ChatRoom.findById(parseId(id)).session(session);
 if (!r) fail(404, 'Không tìm thấy phòng chat.');
 return r;
}
moderationRouter.get('/rooms', route(async(req,res)=>{
 const page=pageSchema.parse(req.query.page), limit=30;
 const [items,total]=await Promise.all([ChatRoom.find().sort({_id:-1}).skip((page-1)*limit).limit(limit).lean(),ChatRoom.countDocuments()]);
 const shows=await Showtime.find({_id:{$in:items.map(r=>r.showtimeId)}}).lean();
 const [movies,cinemas]=await Promise.all([Movie.find({_id:{$in:shows.map(s=>s.movieId)}}).select('title').lean(),Cinema.find({_id:{$in:shows.map(s=>s.cinemaId)}}).select('name').lean()]);
 res.json({items,total,page,pages:Math.max(1,Math.ceil(total/limit)),shows,movies,cinemas});
}));
moderationRouter.get('/rooms/:id/messages',route(async(req,res)=>{
 const r=await room(req.params.id), page=pageSchema.parse(req.query.page),filter={chatRoomId:r._id};
 const [items,total,bans]=await Promise.all([Message.find(filter).sort({_id:-1}).skip((page-1)*50).limit(50).lean(),Message.countDocuments(filter),ChatBan.find(filter).select('userId reason').lean()]);
 const users=await User.find({_id:{$in:bans.map(b=>b.userId)}}).select('name').lean();
 const names=new Map(users.map(u=>[String(u._id),u.name]));
 res.json({room:r,items,total,page,pages:Math.max(1,Math.ceil(total/50)),bans:bans.map(b=>({...b,name:names.get(String(b.userId)) || 'Tài khoản đã xóa'}))});
}));
moderationRouter.patch('/rooms/:id/lock',body(moderationSchema),route(async(req,res)=>{
 await transaction(async session=>{
  const r=await room(req.params.id,session);
  await ChatRoom.updateOne({_id:r._id},{$set:{locked:req.data.value},$inc:{revision:1}},{session});
  await audit(req.user._id,'chat.room.lock',r._id,session,req.data);
 });res.json({ok:true});
}));
moderationRouter.patch('/rooms/:id/messages/:messageId',body(moderationSchema),route(async(req,res)=>{
 await transaction(async session=>{
  const r=await room(req.params.id,session);
  const m=await Message.findOneAndUpdate({_id:parseId(req.params.messageId),chatRoomId:r._id},{$set:{hidden:req.data.value}},{session,new:true});
  if(!m)fail(404,'Không tìm thấy tin nhắn trong phòng này.');
  await audit(req.user._id,'chat.message.hide',m._id,session,{...req.data,roomId:r._id});
 });res.json({ok:true});
}));
moderationRouter.patch('/rooms/:id/users/:userId/ban',body(moderationSchema),route(async(req,res)=>{
 await transaction(async session=>{
  const r=await room(req.params.id,session),userId=parseId(req.params.userId);
  const user=await User.findOne({_id:userId,role:'customer'}).session(session);
  if(!user)fail(400,'Chỉ có thể chặn tài khoản khách hàng.');
  // Same room write as join/send serializes moderation with concurrent posting.
  await ChatRoom.updateOne({_id:r._id},{$inc:{revision:1}},{session});
  if(req.data.value)await ChatBan.updateOne({chatRoomId:r._id,userId},{$set:{reason:req.data.reason}},{upsert:true,session});
  else await ChatBan.deleteOne({chatRoomId:r._id,userId},{session});
  await audit(req.user._id,'chat.member.ban',userId,session,{...req.data,roomId:r._id});
 });res.json({ok:true});
}));

// Hard delete is distinct from hiding: content is removed, audit keeps metadata only.
moderationRouter.delete(
  '/rooms/:id/messages/:messageId',
  body(z.object({reason}).strict()),
  route(async (req, res) => {
    await transaction(async session => {
      const r = await room(req.params.id, session);
      const message = await Message.findOneAndDelete({
        _id: parseId(req.params.messageId), chatRoomId: r._id,
      }, {session});
      if (!message) fail(404, 'Tin nhắn không tồn tại trong phòng này hoặc đã bị xóa.');
      await audit(req.user._id, 'chat.message.delete', message._id, session, {
        roomId: r._id, authorId: message.userId, reason: req.data.reason,
      });
    });
    res.json({ok: true});
  }),
);
