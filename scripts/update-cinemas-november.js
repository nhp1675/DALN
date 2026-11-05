import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {buildNetworkPlan,classifySlot,summarizePlan,vnDay} from './network-planner.js';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=name=>JSON.parse(readFileSync(path.join(root,name),'utf8'));
const args=process.argv.slice(2);
if(args.some(a=>!['--apply','--database'].includes(a))) throw Error('Dùng: node scripts/update-cinemas-november.js [--database | --apply]');
const apply=args.includes('--apply'), useDatabase=apply||args.includes('--database');
const config=read('data/cinego-network-november.json');
const now=new Date();
function report(plan, counts={}) {
  const daily=summarizePlan(plan);
  writeFileSync(path.join(root,'data/cinego-network-preview.json'),JSON.stringify({generatedAt:now.toISOString(),timezone:'Asia/Ho_Chi_Minh',source:useDatabase?'database':'offline-catalog',...counts,total:plan.length,days:daily,shows:plan},null,2));
  console.table(daily.map(d=>({Ngày:d.date,'Số suất':d.total,...d.cinemas})));
  console.log(`Tổng ${plan.length} suất, ${daily.length} ngày. Chi tiết: data/cinego-network-preview.json`);
}
function assertCoverage(plan) {
  if(!plan.length) throw Error('Không có suất tương lai đủ điều kiện. Kiểm tra phim, ngày mở bán và cấu hình tháng 11/2026.');
  if(!plan.some(p=>p.date===config.endDate)) throw Error('Không có phim đủ điều kiện chiếu đến 30/11/2026. Hãy cập nhật ngày kết thúc bán vé của phim trong Quản trị rồi chạy lại.');
}
if(!useDatabase) {
  const movies=read('data/movies-cgv.json').map((m,i)=>({...m,_id:'offline-'+i}));
  const plan=buildNetworkPlan(movies,config,now);
  assertCoverage(plan);report(plan);
  console.log('Xem trước bằng danh mục trong file; chưa kết nối hoặc ghi database. Dùng --database để xem trước theo database, --apply để cập nhật.');
} else {
  const mongoose=(await import('mongoose')).default;
  const {config:env}=await import('../server/config.js');
  const {Movie,Cinema,Room,Seat,Showtime,ShowtimeSeat}=await import('../server/models.js');
  const {transaction,create,audit}=await import('../server/core.js');
  const {saveRoom}=await import('../server/services/catalog.js');
  try {
    await mongoose.connect(env.MONGODB_URI,{serverSelectionTimeoutMS:10000});
    const movies=await Movie.find({deletedAt:null,status:{$in:['now','soon']}}).lean();
    const plan=buildNetworkPlan(movies,config,now); assertCoverage(plan);
    const cinemas=new Map(), roomMaps=new Map(), existingMaps=new Map();
    // Read and validate all five cinemas before changing any data.
    for(const data of config.cinemas) {
      const matches=await Cinema.find({name:data.name}).lean();
      if(matches.length>1) throw Error('Trùng tên rạp trong database: '+data.name+'. Cần xử lý bản trùng trước.');
      const cinema=matches[0];
      if(cinema && !cinema.active) throw Error('Rạp đang ngừng hoạt động: '+data.name+'. Hãy mở lại trong Quản trị trước.');
      cinemas.set(data.name,cinema);
      const rooms=cinema?await Room.find({cinemaId:cinema._id}).lean():[];
      roomMaps.set(data.name,new Map(rooms.map(r=>[r.name,r])));
      const existing=rooms.length?await Showtime.find({roomId:{$in:rooms.map(r=>r._id)},status:'active',endAt:{$gte:now},startAt:{$lt:new Date('2026-12-01T00:00:00+07:00')}}).lean():[];
      existingMaps.set(data.name,existing);
    }
    const prepared=plan.map(p=>{
      const room=roomMaps.get(p.cinemaName).get(p.roomName);
      const existing=room?existingMaps.get(p.cinemaName).filter(s=>String(s.roomId)===String(room._id)):[];
      return {...p,action:classifySlot(p,existing,config.breakMinutes)};
    });
    const counts={newShows:prepared.filter(p=>p.action==='new').length,existing:prepared.filter(p=>p.action==='existing').length,occupied:prepared.filter(p=>p.action==='occupied').length};
    report(prepared,counts);console.log(counts);
    if(!apply) {console.log('Chưa ghi dữ liệu. Thêm --apply để cập nhật.');}
    else {
      const hello=await mongoose.connection.db.admin().command({hello:1});
      if(!hello.setName&&hello.msg!=='isdbgrid') throw Error('Cần MongoDB replica set/Atlas để tạo lịch và ghế bằng transaction.');
      await Promise.all([Cinema,Room,Seat,Showtime,ShowtimeSeat].map(m=>m.init()));
      const backupDir=path.join(root,'backups');mkdirSync(backupDir,{recursive:true});
      writeFileSync(path.join(backupDir,`cinemas-before-november-${Date.now()}.json`),JSON.stringify([...cinemas.values()].filter(Boolean),null,2),{flag:'wx',mode:0o600});
      // Update same-name cinema documents in place so old rooms, orders and tickets keep their IDs.
      for(const entry of config.cinemas) {
        const {name,city,address,latitude,longitude}=entry;
        const cinema=await transaction(async session=>{
          const found=await Cinema.findOneAndUpdate({name},{$set:{city,address,latitude,longitude},$inc:{revision:1},$setOnInsert:{name,active:true}}, {upsert:true,new:true,runValidators:true,session});
          if(!found.active)throw Error('Rạp đã ngừng hoạt động: '+name);
          await audit(undefined,'cinema.november-updated',found._id,session);
          return found;
        });
        cinemas.set(name,cinema);
        for(const shape of config.rooms) {
          if(!roomMaps.get(name).has(shape.name))roomMaps.get(name).set(shape.name,await saveRoom(undefined,{...shape,cinemaId:String(cinema._id)}));
        }
      }
      let added=0,retained=0,occupied=0,past=0;
      for(const p of prepared) {
        const cinema=cinemas.get(p.cinemaName),room=roomMaps.get(p.cinemaName).get(p.roomName);
        const outcome=await transaction(async session=>{
          const roomLock=await Room.updateOne({_id:room._id},{$inc:{revision:1}},{session});
          if(roomLock.matchedCount!==1)throw Error('Phòng đã bị xóa; chạy lại lệnh để lập lịch.');
          if(+new Date(p.startAt)<=Date.now()) return 'past';
          const current=await Showtime.find({roomId:room._id,status:'active',startAt:{$lt:new Date(+new Date(p.endAt)+config.breakMinutes*60000)},endAt:{$gt:new Date(+new Date(p.startAt)-config.breakMinutes*60000)}}).session(session).lean();
          const action=classifySlot(p,current,config.breakMinutes);
          if(action!=='new')return action;
          const movie=await Movie.findOneAndUpdate({_id:p.movieId,deletedAt:null,status:{$in:['now','soon']}},{$inc:{revision:1}},{new:true,session});
          const liveCinema=await Cinema.findOneAndUpdate({_id:cinema._id,active:true},{$inc:{revision:1}},{new:true,session});
          if(!movie||!liveCinema)throw Error('Phim hoặc rạp đã ngừng hoạt động.');
          if(!movie.releaseDate||vnDay(new Date(p.startAt))<new Date(movie.releaseDate).toISOString().slice(0,10)||
             (movie.endDate&&p.date>new Date(movie.endDate).toISOString().slice(0,10))||
             !Number.isInteger(movie.duration)||movie.duration<1||!['P','K','T13','T16','T18'].includes(movie.ageRating)||
             +new Date(p.endAt)-+new Date(p.startAt)!==movie.duration*60000)throw Error('Dữ liệu phim đã đổi; chạy lại lệnh để lập lịch mới.');
          const seats=await Seat.find({roomId:room._id,active:true}).session(session);
          if(!seats.length)throw Error('Phòng chưa có ghế: '+room.name);
          const show=await create(Showtime,{movieId:movie._id,cinemaId:cinema._id,roomId:room._id,startAt:new Date(p.startAt),endAt:new Date(p.endAt),standardPrice:p.standardPrice,vipPrice:p.vipPrice,status:'active'},session);
          await ShowtimeSeat.insertMany(seats.map(s=>({showtimeId:show._id,seatId:s._id,label:s.label,type:s.type,price:s.type==='vip'?p.vipPrice:p.standardPrice})),{session});
          await audit(undefined,'showtime.created',show._id,session,{source:'cinego-network-november'});
          return 'new';
        });
        if(outcome==='new')added++;else if(outcome==='existing')retained++;else if(outcome==='past')past++;else occupied++;
        if((added+retained+occupied+past)%100===0)console.log(`Đã xử lý ${added+retained+occupied+past}/${prepared.length} suất.`);
      }
      console.log({added,retained,occupied,past});
      console.log('Hoàn tất. Lịch/vé/đơn cũ được giữ nguyên; suất chồng lịch được bỏ qua.');
    }
  } catch(error){console.error('Chưa hoàn tất:',error.message);process.exitCode=1;}
  finally{await mongoose.disconnect();}
}
