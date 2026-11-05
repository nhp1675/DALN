import {planSchedule} from './cinego-planner.js';

export const vnDay = value => new Date(+new Date(value) + 7 * 3600000).toISOString().slice(0, 10);
export function validateNetwork(config) {
  if (config.startDate !== '2026-11-01' || config.endDate !== '2026-11-30') throw Error('Cấu hình phải là tháng 11/2026.');
  if (!Array.isArray(config.cinemas) || config.cinemas.length !== 5) throw Error('Cần đúng 5 cụm rạp.');
  if (new Set(config.cinemas.map(c => c.name)).size !== 5) throw Error('Trùng tên rạp trong cấu hình.');
  for (const cinema of config.cinemas) {
    if (!cinema.name || !cinema.city || !cinema.address ||
        !Number.isFinite(cinema.latitude) || Math.abs(cinema.latitude) > 90 ||
        !Number.isFinite(cinema.longitude) || Math.abs(cinema.longitude) > 180 ||
        (cinema.latitude === 0 && cinema.longitude === 0)) throw Error('Thiếu thông tin rạp: ' + cinema.name);
  }
  if (config.cinemas.find(c => c.name === 'CineGo Long Biên')?.city !== 'Hà Nội') throw Error('Long Biên phải thuộc Hà Nội.');
}
export function buildNetworkPlan(movies, config, now = new Date()) {
  validateNetwork(config);
  if (!Number.isFinite(+now)) throw Error('Thời điểm không hợp lệ.');
  // Plan the entire month first: advancing the clock must not reshuffle future slots.
  const full = planSchedule(movies, {...config, days: 30}, new Date('2026-10-31T00:00:00Z'));
  const future = full.filter(show => +new Date(show.startAt) > +now);
  return config.cinemas.flatMap(cinema => future.map(show => ({...show, cinemaName: cinema.name, city: cinema.city, date: vnDay(show.startAt)})))
    .sort((a,b) => a.startAt.localeCompare(b.startAt) || a.cinemaName.localeCompare(b.cinemaName,'vi') || a.roomName.localeCompare(b.roomName));
}
export function classifySlot(candidate, existing, breakMinutes) {
  const buffer = breakMinutes * 60000;
  const matches = existing.filter(s => s.status !== 'cancelled' &&
    +new Date(candidate.startAt) < +new Date(s.endAt) + buffer &&
    +new Date(candidate.endAt) + buffer > +new Date(s.startAt));
  if (!matches.length) return 'new';
  if (matches.length === 1 && +new Date(matches[0].startAt) === +new Date(candidate.startAt) &&
      +new Date(matches[0].endAt) === +new Date(candidate.endAt) && String(matches[0].movieId) === String(candidate.movieId)) return 'existing';
  return 'occupied';
}
export function summarizePlan(plan) {
  const days = new Map();
  for (const show of plan) {
    if (!days.has(show.date)) days.set(show.date, {date:show.date,total:0,cinemas:{}});
    const row = days.get(show.date); row.total++; row.cinemas[show.cinemaName]=(row.cinemas[show.cinemaName]||0)+1;
  }
  return [...days.values()].sort((a,b)=>a.date.localeCompare(b.date));
}
