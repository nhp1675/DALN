import { Router } from 'express';
import { z } from 'zod';
import { rateLimit } from 'express-rate-limit';
import { Movie, Review, Ticket, Showtime } from '../models.js';
import { requireAuth, requireAdmin } from '../auth.js';
import { route, body, parseId, fail, transaction, audit } from '../core.js';

export const reviewInput = z.object({
  rating: z.number().int().min(1).max(5),
  comment: z.string().trim().max(1000).default(''),
}).strict();
export const reviewVisibility = z.object({ hidden: z.boolean() }).strict();
const paging = z.object({page: z.coerce.number().int().min(1).max(100000).default(1)});
export async function canReview(userId, movieId) {
  if (!userId) return false;
  const shows = await Showtime.distinct('_id', {
    movieId, status: 'active', endAt: { $lte: new Date() },
  });
  if (!shows.length) return false;
  return !!await Ticket.exists({userId, showtimeId: {$in: shows}, status: {$in: ['valid', 'used']}});
}
async function movie(id) {
  const found = await Movie.exists({_id:id, deletedAt:null});
  if (!found) fail(404, 'Không tìm thấy phim.');
}
const writeLimit = rateLimit({windowMs:60000, limit:15, keyGenerator:req=>String(req.user._id),
  standardHeaders:'draft-8', legacyHeaders:false,
  message:{message:'Bạn thao tác quá nhanh. Vui lòng thử lại sau.'}});
export const reviewsRouter = Router();
reviewsRouter.get('/movies/:id/reviews', route(async(req,res)=>{
  const movieId = parseId(req.params.id);
  await movie(movieId);
  const {page} = paging.parse(req.query);
  const filter = {movieId, hidden:false};
  const [items, total, distribution, mine, eligible] = await Promise.all([
    Review.find(filter).sort({createdAt:-1,_id:-1}).skip((page-1)*10).limit(10).select('-userId').lean(),
    Review.countDocuments(filter),
    Review.aggregate([{$match:{movieId:new Movie.base.Types.ObjectId(movieId), hidden:false}},
      {$group:{_id:'$rating', count:{$sum:1}}}]),
    req.user ? Review.findOne({movieId,userId:req.user._id}).lean() : null,
    canReview(req.user?._id,movieId),
  ]);
  const counts = Object.fromEntries([1,2,3,4,5].map(n=>[n,0]));
  for (const row of distribution) counts[row._id]=row.count;
  const average = total ? distribution.reduce((sum,row)=>sum+row._id*row.count,0)/total : 0;
  res.json({items,total,page,pages:Math.max(1,Math.ceil(total/10)),counts,average,mine,canReview:eligible});
}));
reviewsRouter.put('/movies/:id/reviews/mine', requireAuth, writeLimit, body(reviewInput), route(async(req,res)=>{
  const movieId = parseId(req.params.id);
  await movie(movieId);
  if (!await canReview(req.user._id,movieId))
    fail(403,'Chỉ khách có vé chưa bị hủy của suất chiếu đã kết thúc mới được đánh giá.');
  // Sửa nội dung không tự bỏ ẩn một đánh giá đã được quản trị viên kiểm duyệt.
  const review = await Review.findOneAndUpdate({movieId,userId:req.user._id},
    {$set:{...req.data,name:req.user.name},$setOnInsert:{hidden:false}},
    {upsert:true,new:true,runValidators:true});
  res.json(review);
}));
reviewsRouter.delete('/movies/:id/reviews/mine', requireAuth, writeLimit, route(async(req,res)=>{
  await Review.deleteOne({movieId:parseId(req.params.id),userId:req.user._id});
  res.json({ok:true});
}));
export const reviewAdminRouter = Router();
reviewAdminRouter.use(requireAuth,requireAdmin);
reviewAdminRouter.get('/reviews',route(async(req,res)=>{
  const {page}=paging.parse(req.query);
  const [items,total]=await Promise.all([
    Review.find().sort({createdAt:-1,_id:-1}).skip((page-1)*20).limit(20).lean(),
    Review.countDocuments(),
  ]);
  const movies=await Movie.find({_id:{$in:items.map(x=>x.movieId)}}).select('title').lean();
  res.json({items,movies,total,page,pages:Math.max(1,Math.ceil(total/20))});
}));
reviewAdminRouter.patch('/reviews/:id',body(reviewVisibility),route(async(req,res)=>{
  const result=await transaction(async session=>{
    const review=await Review.findByIdAndUpdate(parseId(req.params.id),{$set:req.data},{new:true,session});
    if(!review) fail(404,'Không tìm thấy đánh giá.');
    await audit(req.user._id,req.data.hidden?'review.hidden':'review.restored',review._id,session);
    return review;
  });
  res.json(result);
}));
