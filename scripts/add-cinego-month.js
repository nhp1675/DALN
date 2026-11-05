import mongoose from 'mongoose';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import {config} from '../server/config.js';
import {Movie,Cinema,Room,Seat,Showtime,ShowtimeSeat} from '../server/models.js';
import {saveRoom} from '../server/services/catalog.js';
import {transaction,create,audit} from '../server/core.js';
import {planSchedule} from './cinego-planner.js';
const root=path.resolve(import.meta.dirname,'..');
const read=f=>JSON.parse(readFileSync(path.join(root,'data',f),'utf8'));
const cfg=read('cinego-schedule.json'), posters=read('cgv-posters.json');
const args=process.argv.slice(2), mode=args[0]||'preview', apply=args.includes('--apply');
if(!['preview','posters','schedule'].includes(mode)||args.slice(1).some(x=>x!=='--apply'))throw Error('Dùng preview | posters [--apply] | schedule [--apply].');
function backup(name,objects) {
 const dir=path.join(root,'backups');mkdirSync(dir,{recursive:true});
 writeFileSync(path.join(dir,name+'-'+Date.now()+'.ejson'),mongoose.mongo.BSON.EJSON.stringify(objects,{relaxed:false}),{flag:'wx',mode:0o600});
}
try {
 await mongoose.connect(config.MONGODB_URI,{serverSelectionTimeoutMS:10000});
 const movies=await Movie.find({title:{$in:posters.map(p=>p.title)},deletedAt:null}).lean();
 const byTitle=new Map();
 for(const m of movies){if(byTitle.has(m.title))throw Error('Trùng tên phim: '+m.title);byTitle.set(m.title,m);}
 const missing=posters.filter(p=>!byTitle.has(p.title));
 if(missing.length)throw Error(`Thiếu ${missing.length} phim trong DB. Cần nhập bộ 60 phim trước; không tự thêm/xóa phim ở bước này.`);
 console.log('Database:',mongoose.connection.name);
 if(mode==='posters') {
   for(const p of posters)readFileSync(path.join(root,'frontend/assets/posters',p.poster.split('/').at(-1)));
   if(apply) {
     backup('before-poster-update',movies.map(m=>({_id:m._id,title:m.title,poster:m.poster})));
     for(const p of posters)await Movie.updateOne({_id:byTitle.get(p.title)._id},{$set:{poster:p.poster}},{runValidators:true});
     console.log('Đã cập nhật poster cho 60 phim. Không đổi nội dung khác.');
   } else console.log('Sẽ cập nhật 60 đường dẫn poster. Thêm --apply để ghi.');
 } else {
   const plan=planSchedule(movies,cfg);
   if(!plan.length)throw Error('Không có suất tương lai. Kiểm tra startDate, thời lượng, phân loại và ngày khởi chiếu.');
   const cinemas=await Cinema.find({name:cfg.cinema.name}).lean();
   if(cinemas.length>1)throw Error('Có nhiều rạp trùng tên; chỉnh tên cấu hình cho duy nhất.');
   let cinema=cinemas[0];
   if(cinema&&!cinema.active)throw Error('Rạp đang ngừng hoạt động.');
   const rooms=cinema?await Room.find({cinemaId:cinema._id}).lean():[];
   const roomMap=new Map(rooms.map(r=>[r.name,r]));
   const existing=rooms.length?await Showtime.find({roomId:{$in:rooms.map(r=>r._id)},status:'active',endAt:{$gte:new Date(plan[0].startAt)}}).lean():[];
   const overlaps=(a,b)=>+new Date(a.startAt)<+new Date(b.endAt)+cfg.breakMinutes*60000 && +new Date(a.endAt)+cfg.breakMinutes*60000>+new Date(b.startAt);
   let exact=0;
   for(const p of plan) {
     const room=roomMap.get(p.roomName); if(!room)continue;
     const conflicts=existing.filter(e=>String(e.roomId)===String(room._id)&&overlaps(p,e));
     if(conflicts.length===1 && +new Date(conflicts[0].startAt)===+new Date(p.startAt)&&String(conflicts[0].movieId)===p.movieId&&+new Date(conflicts[0].endAt)===+new Date(p.endAt)){exact++;continue;}
     if(conflicts.length)throw Error(`Trùng lịch có sẵn tại ${p.roomName}, ${p.startAt}. Chưa tạo suất mới.`);
   }
   writeFileSync(path.join(root,'data/cinego-schedule-preview.json'),JSON.stringify({generatedAt:new Date(),timezone:'Asia/Ho_Chi_Minh',configuration:cfg,total:plan.length,existing:exact,shows:plan},null,2));
   console.log(`Lịch đề xuất: ${plan.length} suất / ${cfg.days} ngày / ${cfg.rooms.length} phòng. Đã có ${exact} suất; thêm ${plan.length-exact}.`);
   console.log('Rạp:',cfg.cinema.name,'| Địa chỉ:',cfg.cinema.address,'| Giá: 80.000đ thường / 110.000đ VIP (theo cấu hình).');
   console.log('Xem data/cinego-schedule-preview.json. Lịch CineGo tự sắp xếp, không phải lịch CGV.');
   if(mode==='schedule'&&apply) {
     const hello=await mongoose.connection.db.admin().command({hello:1});
     if(!hello.setName&&hello.msg!=='isdbgrid')throw Error('MongoDB cần replica set/Atlas để tạo suất và ghế bằng transaction.');
     if(!cinema)cinema=await Cinema.create(cfg.cinema);
     for(const r of cfg.rooms)if(!roomMap.has(r.name))roomMap.set(r.name,await saveRoom(undefined,{...r,cinemaId:String(cinema._id)}));
     let created=0,skipped=0;
     for(const p of plan) {
       const room=roomMap.get(p.roomName);
       const added=await transaction(async session=>{
         await Room.updateOne({_id:room._id},{$inc:{revision:1}},{session});
         const m=await Movie.findOneAndUpdate({_id:p.movieId,deletedAt:null,status:{$in:['now','soon']}},{$inc:{revision:1}},{session,new:true});
         const c=await Cinema.findOneAndUpdate({_id:cinema._id,active:true},{$inc:{revision:1}},{session,new:true});
         if(!m||!c)throw Error('Phim hoặc rạp đã ngừng hoạt động.');
         const day=new Date(+new Date(p.startAt)+7*3600000).toISOString().slice(0,10);
         if(!m.releaseDate||day<new Date(m.releaseDate).toISOString().slice(0,10)||(m.endDate&&day>new Date(m.endDate).toISOString().slice(0,10))||!['P','K','T13','T16','T18'].includes(m.ageRating)||!Number.isInteger(m.duration)||m.duration<1||+new Date(p.endAt)-+new Date(p.startAt)!==m.duration*60000)throw Error('Thông tin phim đã thay đổi; chạy lại preview.');
         const duplicate=await Showtime.findOne({roomId:room._id,status:'active',startAt:new Date(p.startAt)}).session(session);
         if(duplicate&&String(duplicate.movieId)===p.movieId&&+duplicate.endAt===+new Date(p.endAt))return false;
         if(+new Date(p.startAt)<=Date.now())throw Error('Suất đã đến giờ; chạy lại preview.');
         if(await Showtime.exists({roomId:room._id,status:'active',startAt:{$lt:new Date(+new Date(p.endAt)+cfg.breakMinutes*60000)},endAt:{$gt:new Date(+new Date(p.startAt)-cfg.breakMinutes*60000)}}).session(session))throw Error('Trùng lịch phòng; dừng để giữ nguyên lịch đã có.');
         const seats=await Seat.find({roomId:room._id,active:true}).session(session);
         if(!seats.length)throw Error('Phòng chưa có ghế.');
         const show=await create(Showtime,{movieId:m._id,roomId:room._id,cinemaId:cinema._id,startAt:new Date(p.startAt),endAt:new Date(p.endAt),standardPrice:p.standardPrice,vipPrice:p.vipPrice,status:'active'},session);
         await ShowtimeSeat.insertMany(seats.map(s=>({showtimeId:show._id,seatId:s._id,label:s.label,type:s.type,price:s.type==='vip'?p.vipPrice:p.standardPrice})),{session});
         await audit(undefined,'showtime.created',show._id,session,{source:'cinego-month-planner'});
         return true;
       });
       if(added)created++;else skipped++;
       if((created+skipped)%50===0)console.log(`Đã xử lý ${created+skipped}/${plan.length} suất...`);
     }
     console.log(`Hoàn tất: thêm ${created}, giữ nguyên ${skipped}. Không xóa dữ liệu/tài khoản/vé.`);
   } else console.log('Chưa ghi lịch. Chạy schedule --apply để tạo rạp/phòng/ghế/suất chiếu.');
 }
} catch(e){console.error('Không hoàn tất:',e.message);process.exitCode=1;}
finally{await mongoose.disconnect();}
