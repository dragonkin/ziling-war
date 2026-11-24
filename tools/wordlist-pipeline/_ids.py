# -*- coding: utf-8 -*-
"""下载 cjkvi-ids 的 ids.txt，查看格式，并试拆几个字。"""
import os, io, re, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, 'cache')
os.makedirs(CACHE, exist_ok=True)
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

DST = os.path.join(CACHE, 'ids.txt')
URLS = [
    'https://raw.githubusercontent.com/cjkvi/cjkvi-ids/master/ids.txt',
    'https://gh-proxy.com/https://raw.githubusercontent.com/cjkvi/cjkvi-ids/master/ids.txt',
]
if not os.path.exists(DST) or os.path.getsize(DST) < 500000:
    for u in URLS:
        try:
            w('下载 ' + u)
            req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
            d = urllib.request.urlopen(req, timeout=180).read()
            open(DST, 'wb').write(d)
            w('  %d bytes' % len(d))
            if len(d) > 500000:
                break
        except Exception as e:
            w('  失败 %s' % e)
else:
    w('缓存命中')
w('文件 %d bytes' % os.path.getsize(DST))

txt = open(DST, encoding='utf-8', errors='replace').read()
lines = txt.split('\n')
w('行数 %d' % len(lines))
w('--- 前 6 行 ---')
for ln in lines[:6]:
    w(repr(ln[:80]))
w('--- 含「江」「清」「桥」「想」「明」的行 ---')
for i, ln in enumerate(lines):
    if ln[:1] in ('江', '清', '桥', '想', '明') and '\t' in ln:
        w('%r' % ln[:80])

OPEN = '⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻⿼⿽⿾⿿'

def build():
    m = {}
    for ln in lines:
        if ln.startswith('#'):
            continue
        f = ln.split('\t')
        if len(f) < 3:
            continue
        ch, ids = f[1].strip(), f[2].strip()
        if len(ch) == 1 and ids:
            m[ch] = ids
    return m

m = build()
w()
w('可拆解汉字数: %d' % len(m))
for c in '江清桥想明花草':
    ids = m.get(c, '(无)')
    comps = [x for x in ids if x not in OPEN]
    w('  %s -> %s   部件: %s' % (c, ids, ' '.join(comps)))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
