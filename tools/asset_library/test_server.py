"""Integration checks use disposable assets only, never the game's files."""
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
import server

class LibraryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory()
        server.ROOT=Path(cls.temp.name).resolve()
        server.BACKUPS=server.ROOT/'.asset-library-backups'
        (server.ROOT/'assets').mkdir()
        (server.ROOT/'scripts').mkdir()
        (server.ROOT/'assets/example.json').write_text('{"before":true}')
        (server.ROOT/'scripts/game.gd').write_text('var x=load("res://assets/example.json")\nvar folder="res://assets/"+name')
        server.snapshot()
        cls.http=server.ThreadingHTTPServer(('127.0.0.1',0),server.Handler)
        cls.thread=threading.Thread(target=cls.http.serve_forever,daemon=True);cls.thread.start()
        cls.base='http://127.0.0.1:'+str(cls.http.server_port)
    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown();cls.http.server_close();cls.temp.cleanup()
    def call(self,path,body=None,headers=None):
        req=urllib.request.Request(self.base+path,data=body,headers=headers or {})
        try:
            with urllib.request.urlopen(req) as r:return r.status,r.read(),r.headers
        except urllib.error.HTTPError as e:return e.code,e.read(),e.headers
    def test_index_and_references(self):
        status,body,_=self.call('/api/refresh');d=json.loads(body)
        self.assertEqual(status,200)
        a=next(a for a in d['assets'] if a['name']=='example.json')
        self.assertEqual(a['frequency'],1);self.assertEqual(len(a['dynamic']),1)
        self.assertIsInstance(a['modified'],str)
    def test_new_and_deleted_file(self):
        p=server.ROOT/'assets/new.txt';p.write_text('new')
        self.assertTrue(any(a['name']=='new.txt' for a in json.loads(self.call('/api/refresh')[1])['assets']))
        p.unlink()
        self.assertFalse(any(a['name']=='new.txt' for a in json.loads(self.call('/api/refresh')[1])['assets']))
    def test_range(self):
        status,body,headers=self.call('/file?path=assets/example.json',headers={'Range':'bytes=0-3'})
        self.assertEqual(status,206);self.assertEqual(len(body),4);self.assertIn('bytes 0-3/',headers['Content-Range'])
    def test_traversal_and_unindexed(self):
        self.assertEqual(self.call('/file?path=../../etc/passwd')[0],404)
        self.assertEqual(self.call('/file?path=scripts/game.gd')[0],404)
    def test_unauthorized_write(self):
        self.assertEqual(self.call('/api/replace?path=assets/example.json',b'{}')[0],403)
    def test_host(self):
        self.assertEqual(self.call('/api/assets',headers={'Host':'evil.example'})[0],403)
    def test_replace_backup_and_conflict(self):
        p=server.ROOT/'assets/example.json';old=p.read_bytes();stamp=str(p.stat().st_mtime_ns)
        headers={'X-Asset-Token':server.TOKEN,'X-Filename':'replacement.json','X-Modified':stamp}
        status,body,_=self.call('/api/replace?path=assets/example.json',b'{"after":true}',headers)
        self.assertEqual(status,200,body);self.assertEqual(p.read_bytes(),b'{"after":true}')
        backup=server.ROOT/json.loads(body)['backup'];self.assertEqual(backup.read_bytes(),old)
        self.assertEqual(self.call('/api/replace?path=assets/example.json',b'{}',headers)[0],409)
        headers['X-Modified']=str(p.stat().st_mtime_ns);headers['X-Filename']='bad.png'
        self.assertEqual(self.call('/api/replace?path=assets/example.json',b'xx',headers)[0],400)
    def test_symlink_excluded(self):
        (server.ROOT/'assets/link.txt').symlink_to(server.ROOT/'assets/example.json')
        self.assertFalse(any(a['name']=='link.txt' for a in server.snapshot()['assets']))

if __name__=='__main__':unittest.main()
