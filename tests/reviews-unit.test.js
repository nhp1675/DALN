import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
process.env.NODE_ENV='test';process.env.SESSION_SECRET='reviews-'+ 'x'.repeat(64);
process.env.MONGODB_URI='mongodb://placeholder';process.env.PAYMENT_MODE='demo';
const {reviewInput,reviewVisibility,canReview}=await import('../server/routes/reviews.js');
const {Review,Movie,Showtime,Ticket}=await import('../server/models.js');
const {app}=await import('../server/app.js');
const movieId='a'.repeat(24), userId='b'.repeat(24),showId='c'.repeat(24);
test('Review accepts integer 1..5 only, trims comment, rejects privilege injection',()=>{
 for(const rating of [1,2,3,4,5])assert.equal(reviewInput.parse({rating}).rating,rating);
 for(const rating of [0,6,1.5,'5',true])assert.equal(reviewInput.safeParse({rating}).success,false);
 assert.equal(reviewInput.parse({rating:5,comment:'  Hay  '}).comment,'Hay');
 assert.equal(reviewInput.safeParse({rating:5,comment:'x'.repeat(1001)}).success,false);
 for(const field of ['userId','movieId','hidden','name'])assert.equal(reviewInput.safeParse({rating:5,[field]:userId}).success,false);
 assert.equal(reviewVisibility.safeParse({hidden:true}).success,true);
 assert.equal(reviewVisibility.safeParse({hidden:'true'}).success,false);
});
test('Anonymous user never qualifies and makes no ticket lookup',async(t)=>{
 t.mock.method(Showtime,'distinct',()=>{throw Error('must not query');});
 assert.equal(await canReview(null,movieId),false);
});
test('Eligibility restricts show to matching movie, active status and ended time',async(t)=>{
 t.mock.method(Showtime,'distinct',async(field,filter)=>{
  assert.equal(field,'_id');assert.equal(filter.movieId,movieId);assert.equal(filter.status,'active');
  assert.ok(filter.endAt.$lte instanceof Date);assert.ok(filter.endAt.$lte<=new Date());return [];
 });
 t.mock.method(Ticket,'exists',()=>{throw Error('must not query without ended shows');});
 assert.equal(await canReview(userId,movieId),false);
});
test('Only the authenticated owner with valid or used ticket of an ended show qualifies',async(t)=>{
 t.mock.method(Showtime,'distinct',async()=>[showId]);
 t.mock.method(Ticket,'exists',async filter=>{
  assert.equal(filter.userId,userId);assert.deepEqual(filter.showtimeId,{$in:[showId]});
  assert.deepEqual(filter.status,{$in:['valid','used']});return {_id:'ticket'};
 });
 assert.equal(await canReview(userId,movieId),true);
});
test('Ended show alone is insufficient without a qualifying ticket',async(t)=>{
 t.mock.method(Showtime,'distinct',async()=>[showId]);t.mock.method(Ticket,'exists',async()=>null);
 assert.equal(await canReview(userId,movieId),false);
});
test('Review schema enforces one review per user/movie and integer star count',()=>{
 assert.ok(Review.schema.indexes().some(([keys,o])=>keys.movieId===1&&keys.userId===1&&o.unique));
 for(const rating of [0,6,1.5])assert.ok(new Review({movieId,userId,name:'A',rating}).validateSync());
 assert.equal(new Review({movieId,userId,name:'A',rating:5}).validateSync(),undefined);
});
test('Anonymous writes and admin reads are protected before database access',async()=>{
 for(const method of ['put','delete'])assert.equal((await request(app)[method](`/api/movies/${movieId}/reviews/mine`).set('Origin','http://localhost:4000').send({rating:5})).status,401);
 assert.equal((await request(app).get('/api/admin/reviews')).status,401);
 assert.equal((await request(app).get('/api/movies/not-id/reviews')).status,400);
});
test('Public list excludes hidden ratings from both list and average, paginates and conceals user IDs',async(t)=>{
 t.mock.method(Movie,'exists',async()=>({_id:movieId}));
 t.mock.method(Review,'find',filter=>{
  assert.deepEqual(filter,{movieId,hidden:false});
  return {sort:()=>({skip:n=>{assert.equal(n,10);return {limit:n=>{assert.equal(n,10);return {select:selection=>{assert.equal(selection,'-userId');return {lean:async()=>[{name:'A',rating:5,comment:'Hay'}]};}};}};}})};
 });
 t.mock.method(Review,'countDocuments',async()=>3);
 t.mock.method(Review,'aggregate',async pipeline=>{assert.equal(pipeline[0].$match.hidden,false);return [{_id:5,count:2},{_id:2,count:1}];});
 const res=await request(app).get(`/api/movies/${movieId}/reviews?page=2`);
 assert.equal(res.status,200);assert.equal(res.body.average,4);assert.equal(res.body.total,3);
 assert.equal(res.body.counts['5'],2);assert.equal(res.body.counts['1'],0);assert.equal(res.body.canReview,false);assert.equal(res.body.mine,null);
 const bad=await request(app).get(`/api/movies/${movieId}/reviews?page=0`);assert.equal(bad.status,400);
});

test('Authenticated save uses session owner, denies unwatched movie and preserves moderation',async(t)=>{
 const {Session,User}=await import('../server/models.js');
 t.mock.method(Session,'findOne',async()=>({userId,csrf:'csrf'}));
 t.mock.method(User,'findOne',async()=>({_id:userId,name:'Owner',role:'customer'}));
 let eligible=false,updates=0;
 t.mock.method(Showtime,'distinct',async()=>[showId]);
 t.mock.method(Ticket,'exists',async()=>eligible?{_id:'ticket'}:null);
 t.mock.method(Movie,'exists',async()=>({_id:movieId}));
 t.mock.method(Review,'findOneAndUpdate',async(filter,update,options)=>{
  updates++;assert.deepEqual(filter,{movieId,userId});
  assert.equal(update.$set.hidden,undefined);assert.deepEqual(update.$setOnInsert,{hidden:false});
  assert.equal(update.$set.name,'Owner');assert.equal(options.upsert,true);
  return {_id:'review',rating:update.$set.rating,hidden:true};
 });
 const save=data=>request(app).put(`/api/movies/${movieId}/reviews/mine`).set('Cookie','cinego_session=token')
  .set('Origin','http://localhost:4000').set('X-CSRF-Token','csrf').send(data);
 assert.equal((await save({rating:5})).status,403);assert.equal(updates,0);
 eligible=true;
 const ok=await save({rating:4,comment:'Hay'});assert.equal(ok.status,200);assert.equal(ok.body.hidden,true);assert.equal(updates,1);
 assert.equal((await save({rating:4,userId:'attacker'})).status,400);assert.equal(updates,1);
});
test('Delete targets only session owner; customer cannot open admin reviews',async(t)=>{
 const {Session,User}=await import('../server/models.js');
 t.mock.method(Session,'findOne',async()=>({userId,csrf:'csrf'}));
 t.mock.method(User,'findOne',async()=>({_id:userId,name:'Owner',role:'customer'}));
 t.mock.method(Review,'deleteOne',async filter=>{assert.deepEqual(filter,{movieId,userId});return {deletedCount:1};});
 const res=await request(app).delete(`/api/movies/${movieId}/reviews/mine`).set('Cookie','cinego_session=token')
  .set('Origin','http://localhost:4000').set('X-CSRF-Token','csrf');
 assert.equal(res.status,200);
 assert.equal((await request(app).get('/api/admin/reviews').set('Cookie','cinego_session=token')).status,403);
});
