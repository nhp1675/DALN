const DAY=86400000, MIN=60000;
export function planSchedule(movies,cfg,now=new Date()) {
  if(!/^\d{4}-\d{2}-\d{2}$/.test(cfg.startDate)||!Number.isInteger(cfg.days)||cfg.days<1||cfg.days>62) throw Error('Ngày bắt đầu hoặc số ngày không hợp lệ.');
  if(!cfg.rooms.length || cfg.rooms.length>20 || cfg.rooms.some(r=>!r.name||!Number.isInteger(r.rows)||r.rows<1||r.rows>26||!Number.isInteger(r.columns)||r.columns<1||r.columns>40)) throw Error('Cấu hình phòng không hợp lệ.');
  if(new Set(cfg.rooms.map(r=>r.name)).size!==cfg.rooms.length)throw Error('Tên phòng trùng.');
  if(!Number.isInteger(cfg.openHour)||!Number.isInteger(cfg.closeHour)||cfg.openHour<0||cfg.closeHour>24||cfg.openHour>=cfg.closeHour||!Number.isInteger(cfg.breakMinutes)||cfg.breakMinutes<20) throw Error('Khung giờ/khoảng nghỉ không hợp lệ.');
  if(![cfg.standardPrice,cfg.vipPrice].every(n=>Number.isSafeInteger(n)&&n>=0))throw Error('Giá vé không hợp lệ.');
  const date0=new Date(cfg.startDate+'T00:00:00Z');
  if(!Number.isFinite(+date0)||date0.toISOString().slice(0,10)!==cfg.startDate)throw Error('Ngày không tồn tại.');
  const list=[...movies].filter(m=>!m.deletedAt&&['now','soon'].includes(m.status)&&Number.isInteger(m.duration)&&m.duration>0&&['P','K','T13','T16','T18'].includes(m.ageRating)&&m.releaseDate).sort((a,b)=>a.title.localeCompare(b.title,'vi'));
  const plans=[],counts=new Map(list.map(m=>[m.title,0]));
  for(let d=0;d<cfg.days;d++) {
    const day=new Date(+date0+d*DAY).toISOString().slice(0,10);
    const opening=+new Date(day+'T00:00:00+07:00')+cfg.openHour*60*MIN, closing=opening+(cfg.closeHour-cfg.openHour)*60*MIN;
    const eligible=list.filter(m=>new Date(m.releaseDate).toISOString().slice(0,10)<=day&&(!m.endDate||new Date(m.endDate).toISOString().slice(0,10)>=day));
    for(const room of cfg.rooms) {
      let t=opening;
      while(t<closing) {
        const choices=eligible.filter(m=>t+m.duration*MIN<=closing).sort((a,b)=>counts.get(a.title)-counts.get(b.title)||a.title.localeCompare(b.title,'vi'));
        if(!choices.length)break;
        const m=choices[0], end=t+m.duration*MIN;
        if(t>+now) {
          plans.push({roomName:room.name,movieTitle:m.title,movieId:m._id?String(m._id):undefined,startAt:new Date(t).toISOString(),endAt:new Date(end).toISOString(),standardPrice:cfg.standardPrice,vipPrice:cfg.vipPrice});
          counts.set(m.title,counts.get(m.title)+1);
        }
        t=end+cfg.breakMinutes*MIN;
      }
    }
  }
  return plans;
}
