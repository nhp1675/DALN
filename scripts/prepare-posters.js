import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const file=path.join(root,'frontend/lib/widgets/common.dart');
const before=`      image = SvgPicture.asset(
        'assets/posters/\${url.split('/').last}',
        key: ValueKey(url),
        fit: BoxFit.cover,
      );`;
const after=`      final asset = 'assets/posters/\${url.split('/').last}';
      image = url.toLowerCase().endsWith('.svg')
          ? SvgPicture.asset(asset, key: ValueKey(url), fit: BoxFit.cover)
          : Image.asset(asset, key: ValueKey(url), fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _fallback());`;
const text=readFileSync(file,'utf8').replaceAll('\r\n','\n');
if(text.includes(after))console.log('Đã hỗ trợ poster JPG/PNG.');
else {
  if(!text.includes(before))throw Error('Widget Poster đã khác bản ZIP. Chưa sửa; cần đối chiếu common.dart.');
  const dir=path.join(root,'backups','poster-widget-'+Date.now());mkdirSync(dir,{recursive:true});
  writeFileSync(path.join(dir,'common.dart'),readFileSync(file));
  writeFileSync(file,text.replace(before,after));
  console.log('Đã hỗ trợ poster JPG/PNG. Hãy khởi động lại Flutter.');
}
