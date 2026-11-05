import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {buildNetworkPlan,classifySlot,summarizePlan,validateNetwork,vnDay} from '../scripts/network-planner.js';
const config=JSON.parse(readFileSync(new URL('../data/cinego-network-november.json',import.meta.url),'utf8'));
const catalog=JSON.parse(readFileSync(new URL('../data/movies-cgv.json',import.meta.url),'utf8')).map((m,i)=>({...m,_id:String(i)}));
const now=new Date('2026-11-05T00:00:00+07:00');
const plan=buildNetworkPlan(catalog,config,now);
test('Five cinema names map to four city groups and Long Bien is Hanoi',()=>{
 validateNetwork(config);assert.equal(new Set(config.cinemas.map(c=>c.city)).size,4);
 assert.equal(config.cinemas.find(c=>c.name==='CineGo Long Biên').city,'Hà Nội');
 assert.equal(config.cinemas.filter(c=>c.city==='Hà Nội').length,2);
 assert.throws(()=>validateNetwork({...config,cinemas:config.cinemas.map(c=>({...c,name:'duplicate'}))}));
});
test('Every date through November 30 has future shows at all five cinemas',()=>{
 const days=summarizePlan(plan);assert.equal(days.length,26);assert.equal(days[0].date,'2026-11-05');assert.equal(days.at(-1).date,'2026-11-30');
 for(const row of days)assert.equal(Object.keys(row.cinemas).length,5);
 for(const row of plan){assert.ok(+new Date(row.startAt)>+now);assert.ok(row.date<='2026-11-30');assert.equal(row.date,vnDay(row.startAt));}
});
test('Rooms have no overlapping shows and include 20 minute cleanup time',()=>{
 const groups=new Map();
 for(const s of plan){const key=s.cinemaName+'|'+s.roomName;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(s);}
 for(const shows of groups.values()){
  shows.sort((a,b)=>a.startAt.localeCompare(b.startAt));
  for(let i=1;i<shows.length;i++)assert.ok(+new Date(shows[i].startAt)-+new Date(shows[i-1].endAt)>=config.breakMinutes*60000);
 }
});
test('Every movie respects release date, duration, age rating, open and close time',()=>{
 for(const show of plan){
  const movie=catalog.find(m=>m._id===show.movieId);
  assert.ok(movie.releaseDate<=show.date);assert.ok(!movie.endDate||movie.endDate>=show.date);
  assert.notEqual(movie.ageRating,'NO');assert.equal(+new Date(show.endAt)-+new Date(show.startAt),movie.duration*60000);
  const start=+new Date(show.startAt)-+new Date(show.date+'T00:00:00+07:00');
  const end=+new Date(show.endAt)-+new Date(show.date+'T00:00:00+07:00');
  assert.ok(start>=config.openHour*3600000);assert.ok(end<=config.closeHour*3600000);
 }
});
test('Advancing time does not reshuffle still-future cinema/movie/room slots',()=>{
 const later=new Date('2026-11-08T17:00:00+07:00');
 assert.deepEqual(buildNetworkPlan(catalog,config,later),plan.filter(s=>+new Date(s.startAt)>+later));
});
test('Exact rerun is existing; conflicting movie/time is occupied; cleanup boundary is allowed',()=>{
 const candidate=plan[0];
 assert.equal(classifySlot(candidate,[],20),'new');
 assert.equal(classifySlot(candidate,[{...candidate,status:'active'}],20),'existing');
 assert.equal(classifySlot(candidate,[{...candidate,status:'active',movieId:'different'}],20),'occupied');
 assert.equal(classifySlot(candidate,[{...candidate,status:'cancelled'}],20),'new');
 const preceding={status:'active',movieId:'other',startAt:new Date(+new Date(candidate.startAt)-140*60000),endAt:new Date(+new Date(candidate.startAt)-20*60000)};
 assert.equal(classifySlot(candidate,[preceding],20),'new');
 assert.equal(classifySlot(candidate,[{...preceding,endAt:new Date(+preceding.endAt+1)}],20),'occupied');
});
test('Hidden, deleted, missing metadata and December movies never get scheduled',()=>{
 const valid={_id:'a',title:'A',status:'now',duration:100,ageRating:'P',releaseDate:'2026-11-01',endDate:'2026-11-10'};
 const movies=[valid,{...valid,_id:'b',title:'B',status:'archived'},{...valid,_id:'c',title:'C',deletedAt:new Date()},
 {...valid,_id:'d',title:'D',duration:null},{...valid,_id:'e',title:'E',ageRating:'NO'},
 {...valid,_id:'f',title:'F',releaseDate:'2026-12-01'}, {...valid,_id:'g',title:'G',releaseDate:null}];
 const selected=buildNetworkPlan(movies,config,now);assert.ok(selected.length>0);
 assert.ok(selected.every(s=>s.movieId==='a'&&s.date<='2026-11-10'));
});
test('After November no historical shows are produced; money stays integer VND',()=>{
 assert.deepEqual(buildNetworkPlan(catalog,config,new Date('2026-12-01T00:00:00+07:00')),[]);
 assert.ok(plan.every(s=>s.standardPrice===80000&&s.vipPrice===110000));
});
