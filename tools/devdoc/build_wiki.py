# -*- coding: utf-8 -*-
"""Builds the developer wiki bundle: guides, game data, model inventory, GLB files and the viewer.

Usage: python3 tools/devdoc/build_wiki.py <out_dir>
The bundle is a static site: index.html + guides/**/*.md + data.json + models.json + assets/**/*.glb
+ vendor/model-viewer.min.js. Publish it as a multi-file page (or open it through any static server).
"""
import datetime, json, os, re, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))


def run(script, out):
    subprocess.run([sys.executable, os.path.join(HERE, script), out], check=True, cwd=ROOT)


def guide_entry(path):
    text = open(os.path.join(ROOT, path), encoding='utf-8').read()
    title = next((l[2:].strip() for l in text.splitlines() if l.startswith('# ')), os.path.basename(path))
    lead = next((l.strip() for l in text.splitlines()[1:] if l.strip() and not l.startswith(('#', '|', '-', '`', '>'))), '')
    group = path.split('/')[1]
    num = re.match(r'(\d+)_', os.path.basename(path))
    return {'path': path, 'title': title.replace('Хендбук · ', ''), 'lead': lead[:160], 'group': group, 'num': num.group(1) if num else ''}


def main(out):
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)
    run('inventory.py', os.path.join(out, 'models.json'))
    run('extract_data.py', os.path.join(out, 'data.json'))
    guides = []
    for dirpath, _, files in os.walk(os.path.join(ROOT, 'guides')):
        for f in sorted(files):
            if f.endswith('.md'):
                rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
                guides.append(rel)
                os.makedirs(os.path.join(out, os.path.dirname(rel)), exist_ok=True)
                shutil.copy(os.path.join(ROOT, rel), os.path.join(out, rel))
    guides.sort()
    models = json.load(open(os.path.join(out, 'models.json'), encoding='utf-8'))
    # GLB ships base64-encoded as .txt: hosts that refuse binary model types still serve text;
    # the page decodes it into a Blob for model-viewer.
    import base64
    for m in models:
        m['blob'] = m['path'] + '.b64.txt'
        dest = os.path.join(out, m['blob'])
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, 'w').write(base64.b64encode(open(os.path.join(ROOT, m['path']), 'rb').read()).decode('ascii'))
    json.dump(models, open(os.path.join(out, 'models.json'), 'w', encoding='utf-8'), ensure_ascii=False)
    os.makedirs(os.path.join(out, 'vendor'), exist_ok=True)
    shutil.copy(os.path.join(ROOT, 'tools/asset_library/vendor/model-viewer.min.js'), os.path.join(out, 'vendor/model-viewer.min.js'))
    data = json.load(open(os.path.join(out, 'data.json'), encoding='utf-8'))
    version = open(os.path.join(ROOT, 'BUILD_VERSION.txt'), encoding='utf-8').read().strip().replace('alpha-', '')
    build = re.search(r'config/build="(\d+)"', open(os.path.join(ROOT, 'project.godot'), encoding='utf-8').read())
    manifest = {
        'version': version, 'build': build.group(1) if build else '?',
        'generated': datetime.date.today().strftime('%d.%m.%Y'),
        'guides': [guide_entry(g) for g in guides],
        'stats': {'models': len(models), 'animated': sum(1 for m in models if m['animations']),
                  'cards': len([c for c in data['cards'] if (c.get('weight') or 0) > 0]), 'stats': len(data['stats']),
                  'enemies': len(data['enemies']), 'biomes': len(data['biomes']), 'guides': len(guides)},
    }
    html = open(os.path.join(HERE, 'wiki_template.html'), encoding='utf-8').read()
    html = html.replace('/*MANIFEST*/{}', json.dumps(manifest, ensure_ascii=False))
    open(os.path.join(out, 'index.html'), 'w', encoding='utf-8').write(html)
    total = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(out) for f in fs)
    count = sum(len(fs) for _, _, fs in os.walk(out))
    print(f'wiki bundle: {count} files, {total // 1024} KB -> {out}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build', 'devdoc'))
