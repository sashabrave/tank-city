#!/usr/bin/env python3
"""Collect Russian strings that have no English line in data/locales/en.tsv.

Scans string literals in scripts/**/*.gd and text fields of registries (assets/balance/**/*.tres,
data/*.json except the changelog, which carries its own English). Strings translated as a whole or
covered by a template/fragment row (placeholders %d, %s) are skipped. Writes data/locales/missing.tsv
("russian<TAB>" rows) for translation and prints a summary. Usage: tools/localization/missing_strings.py
"""
import json, os, re, sys
ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
CYR = re.compile('[А-Яа-яЁё]')
IGNORE_FILE = os.path.join(os.path.dirname(__file__), 'ignore.txt')
IGNORE = {l.rstrip('\n') for l in open(IGNORE_FILE, encoding='utf-8')} if os.path.exists(IGNORE_FILE) else set()
def load_tsv(path):
    rows = {}
    for line in open(path, encoding='utf-8'):
        parts = line.rstrip('\n').split('\t')
        if len(parts) == 2 and parts[0]:
            rows[parts[0].replace('\\n', '\n')] = parts[1]
    return rows
def compile_rows(rows):
    result = []
    for ru in rows:
        pattern = ''
        cursor = 0
        for m in re.finditer(r'%(?:[0-9]+)?(?:\.[0-9]+)?[dsf]', ru):
            pattern += re.escape(ru[cursor:m.start()].replace('%%', '%'))
            pattern += '(.+?)' if m.group().endswith('s') else r'(-?[0-9]+(?:[.,][0-9]+)?)'
            cursor = m.end()
        pattern += re.escape(ru[cursor:].replace('%%', '%'))
        result.append((len(ru), re.compile(pattern, re.I)))
    result.sort(key=lambda r: -r[0])
    return result
def covered(text, exact, patterns):
    if text.lower() in exact:
        return True
    rest = text
    for _, regex in patterns:
        rest = regex.sub(' ', rest)
        if not CYR.search(rest):
            return True
    return not CYR.search(rest)
def literals():
    for base, _, files in os.walk(os.path.join(ROOT, 'scripts')):
        for name in files:
            if not name.endswith('.gd'):
                continue
            path = os.path.join(base, name)
            rel = os.path.relpath(path, ROOT)
            # Inspector-only text (editor tools, @export_group labels) is never shown to players.
            if rel.startswith(os.path.join('scripts', 'editor')):
                continue
            for number, line in enumerate(open(path, encoding='utf-8'), 1):
                if '@export_group' in line or '@export_category' in line or '@export_enum' in line or 'push_error' in line or 'push_warning' in line:
                    continue
                code = line.split('#', 1)[0] if not line.lstrip().startswith('##') else ''
                for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', code):
                    value = m.group(1).replace('\\n', '\n').replace('\\"', '"')
                    if CYR.search(value) and value.strip() not in IGNORE and len(value.strip()) > 2:
                        yield value, os.path.relpath(path, ROOT) + ':' + str(number)
    for base, _, files in os.walk(os.path.join(ROOT, 'assets', 'balance')):
        for name in files:
            if name.endswith('.tres'):
                path = os.path.join(base, name)
                for m in re.finditer(r'^(?:title|detail|description) = "((?:[^"\\]|\\.)*)"', open(path, encoding='utf-8').read(), re.M):
                    if CYR.search(m.group(1)):
                        yield m.group(1), os.path.relpath(path, ROOT)
def main():
    tsv = os.path.join(ROOT, 'data', 'locales', 'en.tsv')
    rows = load_tsv(tsv)
    exact = {k.lower() for k in rows}
    patterns = compile_rows(rows)
    missing = {}
    for text, where in literals():
        if not covered(text, exact, patterns):
            missing.setdefault(text, where)
    out = os.path.join(ROOT, 'data', 'locales', 'missing.tsv')
    with open(out, 'w', encoding='utf-8') as f:
        for text, where in sorted(missing.items(), key=lambda x: x[1]):
            f.write(text.replace('\n', '\\n') + '\t\t# ' + where + '\n')
    print(f'{len(missing)} strings without English -> data/locales/missing.tsv')
    return 1 if missing and '--strict' in sys.argv else 0
if __name__ == '__main__':
    sys.exit(main())
