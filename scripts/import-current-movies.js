import mongoose from 'mongoose';
import { readFile } from 'node:fs/promises';
import { config } from '../server/config.js';
import { Movie, Cinema, Room, Showtime, allModels } from '../server/models.js';
import { saveRoom, saveShowtime } from '../server/services/catalog.js';

const bundle = JSON.parse(await readFile(new URL('./data/movies-2026-10-07.json', import.meta.url), 'utf8'));
const flags = new Set(process.argv.slice(2));
if ([...flags].some(f => !['--apply', '--demo-showtimes'].includes(f))) throw new Error('Chỉ dùng --apply và --demo-showtimes.');
for (const { source, ...data } of bundle.movies) {
  if (!source.startsWith('https://')) throw new Error('Thiếu nguồn phim');
  await new Movie(data).validate();
}
console.log(`Dữ liệu đối chiếu ${bundle.checkedAt}: ${bundle.movies.length} phim.`);
console.table(bundle.movies.map(({ title, duration, ageRating }) => ({ title, duration, ageRating })));
if (!flags.has('--apply')) {
  console.log('Chỉ xem trước; chưa kết nối database. Thêm --apply để nhập; --demo-showtimes để thêm lịch mô phỏng.');
} else {
  try {
    await mongoose.connect(config.MONGODB_URI);
    await Promise.all(allModels.map(m => m.init()));
    const movies = [];
    for (const { source, ...data } of bundle.movies) {
      // Insert-only: reruns preserve admin edits and IDs, never delete old data.
      let movie = await Movie.findOne({ title: data.title });
      if (!movie) movie = await Movie.create(data);
      movies.push(movie);
    }
    console.log('Đã nhập phim. Phim trùng tên được giữ nguyên; không xóa tài khoản, phim cũ hoặc vé.');
    if (flags.has('--demo-showtimes')) {
      const name = 'CineGo Hà Đông · Demo';
      let cinema = await Cinema.findOne({ name });
      if (!cinema) cinema = await Cinema.create({ name, city: 'Hà Nội', address: 'Khu vực Văn Phú, Hà Đông (địa điểm mô phỏng)', latitude: 20.963, longitude: 105.766, active: true });
      let room = await Room.findOne({ cinemaId: cinema._id, name: 'Phòng Demo 01' });
      if (!room) room = await saveRoom(undefined, { cinemaId: String(cinema._id), name: 'Phòng Demo 01', rows: 7, columns: 10 });
      const vnToday = new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10);
      let added = 0;
      for (let day = 0; day < 7; day++) {
        const date = new Date(Date.parse(`${vnToday}T00:00:00Z`) + day * 86400000).toISOString().slice(0, 10);
        for (let i = 0; i < movies.length; i++) {
          if (movies[i].status !== 'now') continue;
          const startAt = new Date(`${date}T${10 + i * 3}:00:00+07:00`);
          if (startAt <= new Date() || await Showtime.exists({ roomId: room._id, startAt })) continue;
          await saveShowtime(undefined, { movieId: String(movies[i]._id), roomId: String(room._id), startAt: startAt.toISOString(), standardPrice: 80000, vipPrice: 110000 });
          added++;
        }
      }
      console.log(`Đã tạo ${added} suất mô phỏng; ghế thường 80.000đ, VIP 110.000đ. Không phải lịch/giá rạp thật.`);
    }
  } catch (error) {
    console.error('Nhập chưa hoàn tất:', error.name, error.code ?? '');
    console.error('Kiểm tra kết nối Atlas và quyền ghi. Có thể chạy lại; các bản ghi đã tạo sẽ được giữ.');
    process.exitCode = 1;
  } finally { await mongoose.disconnect(); }
}
