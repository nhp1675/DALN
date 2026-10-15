import mongoose from 'mongoose';
import { readFile } from 'node:fs/promises';
import { config } from '../server/config.js';
import { Movie, Cinema, Room, Showtime, allModels } from '../server/models.js';
import { saveRoom, saveShowtime } from '../server/services/catalog.js';

const bundle = JSON.parse(await readFile(new URL('./data/movies-2026-10-07.json', import.meta.url), 'utf8'));
const flags = new Set(process.argv.slice(2));
if ([...flags].some(f => !['--apply', '--demo-showtimes'].includes(f))) throw new Error('Chỉ dùng --apply và --demo-showtimes.');
const moviesToImport = bundle.movies.filter(movie => movie.template !== true);
const templates = bundle.movies.filter(movie => movie.template === true);
const invalidSources = moviesToImport
  .filter(({ source }) => typeof source !== 'string' || !source.startsWith('https://'))
  .map(({ title }) => title);
if (invalidSources.length) {
  throw new Error(`Nguồn phim phải là URL HTTPS. Bổ sung nguồn cho: ${invalidSources.join(', ')}`);
}
for (const { source, template, ...data } of moviesToImport) {
  await new Movie(data).validate();
}
console.log(`Dữ liệu đối chiếu ${bundle.checkedAt}: ${moviesToImport.length} phim${templates.length ? `; bỏ qua ${templates.length} mẫu` : ''}.`);
if (templates.length) console.log(`Mẫu không nhập: ${templates.map(({ title }) => title).join(', ')}.`);
console.table(moviesToImport.map(({ title, duration, ageRating }) => ({ title, duration, ageRating })));
if (!flags.has('--apply')) {
  console.log('Chỉ xem trước; chưa kết nối database. Thêm --apply để nhập; --demo-showtimes để thêm lịch mô phỏng.');
} else {
  try {
    await mongoose.connect(config.MONGODB_URI);
    await Promise.all(allModels.map(m => m.init()));
    const movies = [];
    for (const { source, template, ...data } of moviesToImport) {
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
      const activeMovies = [...new Map(movies
        .filter(movie => movie.status === 'now')
        .map(movie => [String(movie._id), movie])).values()];
      const showtimeHours = [10, 13, 16, 19, 22];
      const roomCount = Math.ceil(activeMovies.length / showtimeHours.length);
      const rooms = [];
      for (let i = 0; i < roomCount; i++) {
        const roomName = `Phòng Demo ${String(i + 1).padStart(2, '0')}`;
        let room = await Room.findOne({ cinemaId: cinema._id, name: roomName });
        if (!room) room = await saveRoom(undefined, { cinemaId: String(cinema._id), name: roomName, rows: 7, columns: 10 });
        rooms.push(room);
      }
      const vnToday = new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10);
      let added = 0;
      for (let day = 0; day < 7; day++) {
        const date = new Date(Date.parse(`${vnToday}T00:00:00Z`) + day * 86400000).toISOString().slice(0, 10);
        for (let i = 0; i < activeMovies.length; i++) {
          const room = rooms[Math.floor(i / showtimeHours.length)];
          const startAt = new Date(`${date}T${showtimeHours[i % showtimeHours.length]}:00:00+07:00`);
          if (startAt <= new Date() || await Showtime.exists({ roomId: room._id, startAt })) continue;
          await saveShowtime(undefined, { movieId: String(activeMovies[i]._id), roomId: String(room._id), startAt: startAt.toISOString(), standardPrice: 80000, vipPrice: 110000 });
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
