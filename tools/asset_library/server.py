#!/usr/bin/env python3
"""Local, dependency-free asset browser. Run from any directory."""
import argparse
from model_routes import classify
import errno
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote
import webbrowser
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
UI = Path(__file__).resolve().parent
BACKUPS = ROOT / '.asset-library-backups'
EXCLUDE = {'.git', '.godot', '.agents', '.codex', '.asset-library-backups', 'tmp', 'output', 'release', 'build', 'node_modules', '__pycache__', 'asset_library'}
GROUPS = {'graphics': {'.png','.jpg','.jpeg','.webp','.svg','.gif','.bmp','.tga','.exr','.hdr'}, 'models': {'.glb','.gltf','.blend','.obj','.fbx','.dae','.stl'}, 'audio': {'.wav','.mp3','.ogg','.flac','.m4a','.aiff'}}
OTHER = {'.tres','.res','.gdshader','.ttf','.otf','.json','.csv','.txt','.md','.pdf','.mp4','.webm'}
SOURCE = {'.gd','.tscn','.tres','.godot','.json','.gdshader'}
TOKEN = secrets.token_urlsafe(32)
LOCK = threading.RLock()
CACHE = None

def files():
    for folder, dirs, names in os.walk(ROOT, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in EXCLUDE and not d.startswith('.') and not (Path(folder)/d).is_symlink())
        for name in sorted(names):
            p = Path(folder)/name
            if not name.startswith('.') and not p.is_symlink():
                yield p

def kind(p):
    for group, extensions in GROUPS.items():
        if p.suffix.lower() in extensions: return group
    if p.suffix.lower() in OTHER: return 'other'

def snapshot():
    global CACHE
    with LOCK:
        all_files = list(files())
        assets = [p for p in all_files if kind(p)]
        exact_index, catalog_index, dynamic_index = {}, {}, {}
        for source in all_files:
            if source.suffix not in SOURCE or source.stat().st_size >= 2_000_000: continue
            src = source.relative_to(ROOT).as_posix()
            for n, line in enumerate(source.read_text(errors='replace').splitlines(), 1):
                ref = {'file':src, 'line':n, 'snippet':line.strip()[:220]}
                literals = re.findall(r'["\']([^"\']+)["\']', line)
                for literal in literals:
                    key = literal.removeprefix('res://')
                    exact_index.setdefault(key, []).append(ref)
                    if src.endswith('.json'):
                        catalog_index.setdefault((str(Path(src).parent), literal), []).append(ref)
                    if src.startswith('scripts/') and literal.startswith('res://') and literal.endswith('/') and ('+' in line or 'ROOT=' in line):
                        dynamic_index.setdefault(key, []).append(ref)
        routes = classify(ROOT, [p.relative_to(ROOT).as_posix() for p in assets])
        result = []
        for p in assets:
            rel = p.relative_to(ROOT).as_posix()
            parent = str(Path(rel).parent)
            matches = exact_index.get(rel, []) + catalog_index.get((parent,p.name), []) + catalog_index.get((parent,p.stem), [])
            direct = list({(r['file'],r['line']):r for r in matches if r['file']!=rel}.values())
            inferred = dynamic_index.get(parent+'/', [])
            live_direct = sum(1 for r in direct if r['file'].startswith(('scripts/','scenes/','assets/')) or r['file']=='project.godot')
            scope = 'game' if rel.startswith('assets/') else 'demo' if rel.startswith(('art_demo/','audio_demo/','3d-sources_testmy/')) else 'reference'
            score = (70 if live_direct else 45 if inferred else 25) if scope=='game' else (15 if scope=='demo' else 5)
            category = str(Path(rel).parent)
            stat = p.stat()
            result.append({'path':rel,'name':p.name,'kind':kind(p),'category':category if category!='.' else 'Корень проекта','format':p.suffix[1:].upper(),'size':stat.st_size,'modified':str(stat.st_mtime_ns),'scope':scope,'references':direct,'dynamic':inferred,'frequency':len(direct),'importance':score+min(live_direct,20),'importanceLabel':'Используется в игре' if live_direct else 'Динамическая загрузка' if inferred else 'Игровой ресурс' if scope=='game' else 'Демо / исходник' if scope=='demo' else 'Справочный материал'})
        for asset in result:
            if asset['kind'] != 'models': continue
            status, label, replacement = routes.get(asset['path'], ('unknown','Исходник / использование не подтверждено',''))
            asset.update(modelStatus=status, importanceLabel=label, currentModel=replacement)
            if status=='current': asset['importance']=120
            elif status=='legacy': asset['importance']=0
        CACHE = {'assets':result, 'scanned':time.time(), 'root':str(ROOT)}
        return CACHE

def asset_path(rel):
    raw = ROOT / rel
    if any(part.is_symlink() for part in [raw, *raw.parents] if part != ROOT and ROOT in part.parents): raise ValueError('Симлинки недоступны')
    p = raw.resolve()
    if not p.is_relative_to(ROOT) or not p.is_file(): raise ValueError('Файл не найден в проекте')
    # Only indexed assets may be read or overwritten.
    if not any(a['path']==rel for a in (CACHE or snapshot())['assets']): raise ValueError('Файл не входит в библиотеку')
    if any(part in EXCLUDE or part.startswith('.') for part in Path(rel).parts): raise ValueError('Недоступный путь')
    return p

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def json(self, data, status=200):
        body=json.dumps(data,ensure_ascii=False).encode()
        self.send_response(status); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Content-Length',str(len(body))); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(body)
    def valid_host(self):
        return self.headers.get('Host') in {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'}
    def do_GET(self):
        if not self.valid_host(): return self.json({'error':'Invalid host'},403)
        u=urlparse(self.path); q=parse_qs(u.query)
        try:
            if u.path=='/api/assets': return self.json(dict(CACHE or snapshot(), token=TOKEN))
            if u.path=='/api/refresh': return self.json(dict(snapshot(), token=TOKEN))
            if u.path=='/file': return self.send_file(asset_path(q.get('path',[''])[0]))
            path = (UI / ('index.html' if u.path=='/' else unquote(u.path).lstrip('/'))).resolve()
            if not path.is_relative_to(UI) or path.suffix not in {'.html','.css','.js'}: raise ValueError('Недоступно')
            self.send_file(path)
        except (ValueError, OSError) as e: self.json({'error':str(e)},404)
    def send_file(self,p):
        size=p.stat().st_size; start=0; end=size-1; status=200
        range_header=self.headers.get('Range')
        if range_header:
            m=re.fullmatch(r'bytes=(\d*)-(\d*)',range_header)
            if not m or not any(m.groups()): return self.json({'error':'Invalid range'},416)
            if m[1]: start=int(m[1]); end=min(int(m[2]),end) if m[2] else end
            else: start=max(0,size-int(m[2]))
            if start>=size or start>end: return self.json({'error':'Invalid range'},416)
            status=206
        mime=mimetypes.guess_type(p.name)[0] or 'application/octet-stream'
        if p.suffix=='.glb': mime='model/gltf-binary'
        self.send_response(status); self.send_header('Content-Type',mime); self.send_header('Content-Length',str(max(0,end-start+1))); self.send_header('Accept-Ranges','bytes'); self.send_header('Cache-Control','no-store'); self.send_header('X-Content-Type-Options','nosniff')
        if p.suffix=='.svg': self.send_header('Content-Security-Policy',"sandbox; default-src 'none'; style-src 'unsafe-inline'")
        if status==206: self.send_header('Content-Range',f'bytes {start}-{end}/{size}')
        self.end_headers()
        with p.open('rb') as f:
            f.seek(start); remaining=end-start+1
            while remaining>0:
                chunk=f.read(min(65536,remaining))
                if not chunk: break
                self.wfile.write(chunk); remaining-=len(chunk)
    def do_POST(self):
        if not self.valid_host() or self.headers.get('X-Asset-Token')!=TOKEN: return self.json({'error':'Invalid request'},403)
        u=urlparse(self.path); q=parse_qs(u.query)
        try:
            with LOCK:
                p=asset_path(q.get('path',[''])[0])
                if u.path=='/api/reveal':
                    command=['open','-R',str(p)] if sys.platform=='darwin' else ['explorer','/select,',str(p)] if sys.platform=='win32' else ['xdg-open',str(p.parent)]
                    subprocess.run(command,check=True,timeout=10); return self.json({'ok':True})
                if u.path!='/api/replace': return self.json({'error':'Unknown action'},404)
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=256*1024*1024: raise ValueError('Допустимый размер: от 1 байта до 256 МБ')
                filename=unquote(self.headers.get('X-Filename',''))
                if Path(filename).suffix.lower()!=p.suffix.lower(): raise ValueError('Расширение нового файла должно совпадать')
                if self.headers.get('X-Modified')!=str(p.stat().st_mtime_ns): return self.json({'error':'Файл уже изменился. Обновите данные и повторите.'},409)
                original_stamp=p.stat().st_mtime_ns
                BACKUPS.mkdir(parents=True,exist_ok=True)
                (BACKUPS/'.gdignore').touch(exist_ok=True)
                backup=BACKUPS/time.strftime('%Y%m%d-%H%M%S')/secrets.token_hex(3)/p.relative_to(ROOT)
                backup.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(p,backup)
                temp=None
                try:
                    with tempfile.NamedTemporaryFile(dir=p.parent,prefix='.asset-upload-',delete=False) as f:
                        temp=Path(f.name); remaining=length
                        while remaining:
                            chunk=self.rfile.read(min(65536,remaining))
                            if not chunk: raise ValueError('Загрузка оборвалась')
                            f.write(chunk); remaining-=len(chunk)
                    if p.stat().st_mtime_ns != original_stamp: raise ValueError('Файл изменился во время загрузки. Обновите данные и повторите.')
                    os.chmod(temp,p.stat().st_mode); os.replace(temp,p)
                finally:
                    if temp and temp.exists(): temp.unlink()
                snapshot()
                return self.json({'ok':True,'backup':str(backup.relative_to(ROOT))})
        except (ValueError,OSError,subprocess.SubprocessError) as e: self.json({'error':str(e)},400)

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--port',type=int,default=8765); parser.add_argument('--no-open',action='store_true'); args=parser.parse_args()
    snapshot()
    try:
        server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    except OSError as error:
        if error.errno != errno.EADDRINUSE: raise
        url=f'http://127.0.0.1:{args.port}'
        try:
            with urllib.request.urlopen(url+'/api/assets',timeout=3) as response:
                existing=json.load(response)
            if existing.get('root')!=str(ROOT): raise ValueError('Другой проект')
        except Exception:
            parser.exit(1, f'Порт {args.port} занят. Запустите с --port {args.port+1}\n')
        print(f'Библиотека уже работает: {url}',flush=True)
        if not args.no_open: webbrowser.open(url)
        return
    print(f'Библиотека ассетов: http://127.0.0.1:{server.server_port}',flush=True)
    if not args.no_open: webbrowser.open(f'http://127.0.0.1:{server.server_port}')
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()
if __name__=='__main__': main()
