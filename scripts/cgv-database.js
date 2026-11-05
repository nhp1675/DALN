import mongoose from 'mongoose';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { createInterface } from 'node:readline/promises';
import { config } from '../server/config.js';
import { Movie, Snack, Cinema, allModels } from '../server/models.js';
const root = path.resolve(import.meta.dirname,'..');
const read = file => JSON.parse(readFileSync(path.join(root,'data',file),'utf8'));
const source = read('movies-cgv.json');
const menu = read('menu-cinego.json');
const EJSON = mongoose.mongo.BSON.EJSON;
const args = process.argv.slice(2);
const mode = args[0] || 'validate';
const apply = args.includes('--apply');
if (!['validate','reset','menu','restore'].includes(mode) || args.slice(1).some(a=>a!=='--apply' && !(mode==='restore' && a.endsWith('.ejson')))) throw Error('Tham số không hợp lệ. Xem HUONG-DAN.md.');
const movies = source.map(m=>({
  title:m.title, genre:m.genre || 'Chưa cập nhật', duration:m.duration,
  ageRating:m.ageRating || 'NO', status:m.status,
  synopsis:m.synopsis || 'Chưa có nội dung tóm tắt trong dữ liệu nguồn đã cung cấp.',
  cast:m.cast || '', director:m.director || '', poster:m.poster || '', trailerUrl:m.trailerUrl || '',
  releaseDate:m.releaseDate ? new Date(m.releaseDate+'T00:00:00.000Z') : null,
}));
async function confirm(text) {
  if (!process.stdin.isTTY) throw Error('Hãy chạy trong terminal tương tác để xác nhận.');
  const rl=createInterface({input:process.stdin,output:process.stdout});
  const answer=await rl.question(`Gõ chính xác "${text}": `); rl.close();
  if(answer!==text) throw Error('Đã hủy; chưa xóa dữ liệu.');
}
async function backupDatabase(db) {
  const cols=await db.listCollections({}, {nameOnly:false}).toArray();
  if(cols.some(c=>c.type!=='collection'||c.name.startsWith('system.'))) throw Error('Database có view/system collection; hãy dùng mongodump chuyên dụng, script không xóa.');
  const collections=[];
  for(const c of cols) collections.push({name:c.name,options:c.options,documents:await db.collection(c.name).find({}).toArray(),indexes:await db.collection(c.name).indexes()});
  const payload={database:db.databaseName,createdAt:new Date(),collections};
  const dir=path.join(root,'backups'); mkdirSync(dir,{recursive:true});
  const file=path.join(dir,`before-cgv-${Date.now()}.ejson`);
  writeFileSync(file,EJSON.stringify(payload,{relaxed:false}),{flag:'wx',mode:0o600});
  const check=EJSON.parse(readFileSync(file,'utf8'),{relaxed:false});
  if(check.collections.length!==collections.length || check.collections.some((c,i)=>c.documents.length!==collections[i].documents.length)) throw Error('Không xác minh được backup; dừng trước khi xóa.');
  console.log('Đã sao lưu đầy đủ collection và index vào:',file);
  return file;
}
try {
  if(source.length!==60 || new Set(source.map(x=>x.sourceUrl)).size!==60) throw Error('Danh sách gốc không đủ 60 URL duy nhất.');
  for(const m of movies) await new Movie(m).validate();
  for(const item of menu) await new Snack({cinemaId:new mongoose.Types.ObjectId(),name:item.name,price:item.price,stock:0,held:0,active:false,image:item.image}).validate();
  console.log(`Hợp lệ: ${movies.length} phim (${movies.filter(x=>x.status==='now').length} đang chiếu, ${movies.filter(x=>x.status==='soon').length} sắp chiếu), ${menu.length} món.`);
  if(mode==='validate') console.log('Chỉ kiểm tra file và schema. Không kết nối database.');
  else {
    if(config.NODE_ENV==='production') throw Error('Không dùng công cụ này ở production.');
    await mongoose.connect(config.MONGODB_URI,{serverSelectionTimeoutMS:10000});
    const db=mongoose.connection.db, name=db.databaseName;
    if(['admin','local','config'].includes(name)) throw Error('Không thao tác database hệ thống.');
    console.log('Database đích:',name);
    if(mode==='reset') {
      const counts=[];
      for(const c of await db.listCollections({}, {nameOnly:true}).toArray()) counts.push({collection:c.name,count:await db.collection(c.name).countDocuments()});
      console.table(counts);
      console.log('Xóa TOÀN BỘ database đích, gồm cả admin, khách, vé, thanh toán, rạp và lịch chiếu. Chỉ giữ bản backup trên máy. Dừng backend và mọi chương trình ghi DB trước khi tiếp tục.');
      if(apply) {
        await confirm(`XOA ${name}`);
        await backupDatabase(db);
        await db.dropDatabase();
        // Explicit createIndexes instead of cached Model.init() after dropping database.
        for(const m of allModels) {await m.createCollection(); await m.createIndexes();}
        await Movie.insertMany(movies);
        await db.collection('cgv_sources').insertMany(source);
        await db.collection('menu_templates').insertMany(menu);
        console.log('Đã tạo database mới. Chưa có admin, rạp, phòng, ghế hoặc suất chiếu. Tạo admin bằng npm run admin.');
      } else console.log('Chỉ xem trước. Thêm --apply để sao lưu rồi xóa/nhập dữ liệu.');
    } else if(mode==='menu') {
      const cinemas=await Cinema.find({active:true}).lean();
      console.table(cinemas.map(c=>({id:String(c._id),name:c.name})));
      if(!cinemas.length) throw Error('Chưa có rạp hoạt động. Tạo rạp thật trong trang admin trước.');
      if(apply) {
        let added=0;
        for(const c of cinemas) for(const item of menu) {
          const r=await Snack.updateOne({cinemaId:c._id,name:item.name},{$setOnInsert:{cinemaId:c._id,name:item.name,price:item.price,image:item.image,stock:0,held:0,active:false}},{upsert:true,runValidators:true});
          added+=r.upsertedCount;
        }
        console.log(`Thêm ${added} món theo rạp; bỏ qua món trùng tên. Tồn kho 0, chưa mở bán. Nhập giá, tồn thực tế và bật bán trong admin.`);
      } else console.log('Thêm --apply để tạo món cho các rạp trên. Không sửa tồn kho/món đã có.');
    } else if(mode==='restore') {
      const file=args.find(a=>a.endsWith('.ejson'));
      if(!file) throw Error('Thiếu đường dẫn file .ejson.');
      const backup=EJSON.parse(readFileSync(path.resolve(file),'utf8'),{relaxed:false});
      if(backup.database!==name || !Array.isArray(backup.collections)) throw Error('Backup không đúng tên database.');
      console.log(`Khôi phục ${backup.collections.length} collection; thay thế toàn bộ dữ liệu hiện tại.`);
      if(apply) {
        await confirm(`KHOI PHUC ${name}`);
        await backupDatabase(db);
        await db.dropDatabase();
        for(const c of backup.collections) {
          const coll=await db.createCollection(c.name,c.options);
          if(c.documents.length) await coll.insertMany(c.documents);
          for(const index of c.indexes) {
            if(index.name==='_id_') continue;
            const {key,v,ns,...options}=index;
            await coll.createIndex(key,options);
          }
        }
        console.log('Đã khôi phục dữ liệu và index từ backup.');
      } else console.log('Chỉ xem trước. Thêm --apply để khôi phục.');
    }
  }
} catch(e) {
  console.error('Không hoàn tất:',e.message);
  process.exitCode=1;
} finally {await mongoose.disconnect();}
