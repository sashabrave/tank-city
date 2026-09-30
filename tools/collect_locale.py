from pathlib import Path
import re,json
values=set()
Path("tmp").mkdir(exist_ok=True)
for p in Path('scripts').rglob('*.gd'):
 if '/balance/' in str(p) or '/editor/' in str(p):continue
 for m in re.finditer(r'"((?:[^"\\]|\\.)*)"',p.read_text()):
  v=m[1]
  if re.search('[а-яА-ЯёЁ]',v) and not any(x in v for x in ['[А-Я','[а-я','(?','res://']):
   if v not in {"е","ё","задани","телеграм"}:values.add(v)
for a in json.loads(Path('data/encyclopedia.json').read_text())['articles']:
 for k in ['category','section','title','text']:values.add(a[k])
Path('tmp/locale-candidates.json').write_text(json.dumps(sorted(values),ensure_ascii=False))
