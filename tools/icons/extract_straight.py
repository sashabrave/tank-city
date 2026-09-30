#!/usr/bin/env python3
"""Extract single icons from the Uicons «Straight» sheet (Straight.svg, 20×25 grid of 24px icons).

Usage: extract_straight.py SHEET.svg OUT_DIR r1_c18:token r19_c7:merchant ...
Cell rN_cM is row N, column M counted from the top-left icon (0-based). Output SVGs are white,
24×24, same format as assets/icons/interface_straight.
"""
import os, re, sys

X0, Y0, STEP = 164, 181, 56

def cells(sheet: str) -> dict:
    body = sheet[sheet.index('<rect x="74"'):sheet.index('<defs>')]
    result = {}
    for m in re.finditer(r'<g clip-path="url\(#clip\d+_7_22620\)">(.*?)</g>|<path [^>]*/>', body, re.S):
        element = m.group(0)
        start = re.search(r'd="M([\d.]+)[ ,]([\d.]+)', element)
        if not start:
            continue
        x, y = float(start.group(1)), float(start.group(2))
        c, r = round((x - X0 - 12) / STEP), round((y - Y0 - 12) / STEP)
        cx, cy = X0 + STEP * c, Y0 + STEP * r
        if 0 <= c < 20 and 0 <= r < 25 and cx - 2 <= x <= cx + 26 and cy - 2 <= y <= cy + 26:
            result.setdefault((r, c), []).append(re.sub(r'<g clip-path="[^"]*">', '<g>', element))
    return result

def main():
    sheet_path, out_dir, *picks = sys.argv[1:]
    found = cells(open(sheet_path).read())
    os.makedirs(out_dir, exist_ok=True)
    for pick in picks:
        cell, name = pick.split(':')
        r, c = (int(v[1:]) for v in cell.split('_'))
        inner = "\n".join(found[(r, c)]).replace('#374957', '#ffffff')
        box = f'{X0 + STEP * c} {Y0 + STEP * r} 24 24'
        with open(os.path.join(out_dir, name + '.svg'), 'w') as f:
            f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="{box}" fill="none">{inner}</svg>\n')

if __name__ == '__main__':
    main()
