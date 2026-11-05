import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
const root = path.resolve(import.meta.dirname, '..');
const changes = JSON.parse(readFileSync(path.join(root,'data/compatibility-patch.json'),'utf8'));
const outputs = new Map();
for (const c of changes) {
  const file = path.join(root,c.path);
  let text = outputs.get(file) ?? readFileSync(file,'utf8').replaceAll('\r\n','\n');
  if (text.includes(c.after)) continue;
  if (!text.includes(c.before)) throw Error(`File đã khác bản ZIP đã duyệt: ${c.path}. Chưa ghi file nào; cần đối chiếu trước.`);
  outputs.set(file,text.replace(c.before,c.after));
}
const backup = path.join(root,'backups','code-before-cgv-'+Date.now());
for (const [file,text] of outputs) {
  const target = path.join(backup,path.relative(root,file));
  mkdirSync(path.dirname(target),{recursive:true});
  writeFileSync(target,readFileSync(file));
  writeFileSync(file,text);
}
console.log(`Đã cập nhật ${outputs.size} file. Bản sao mã nguồn: ${backup}`);
