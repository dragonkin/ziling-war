# -*- coding: utf-8 -*-
"""过滤出「适合小学生」的词语：两个字都必须是教材生字。再看质量。"""
import os, io, json, re
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))
chars, seen = [], set()
for b in payload['books']:
    for d in b['chars']:
        if d['c'] not in seen:
            seen.add(d['c'])
            chars.append(d['c'])
CSET = set(chars)

data = json.load(open(os.path.join(CACHE, 'ci.json'), encoding='utf-8'))
CJK = re.compile(r'^[\u4e00-\u9fff]{2}$')

def collect(pred):
    m = defaultdict(list)
    for it in data:
        ci = (it.get('ci') or '').strip()
        if CJK.match(ci) and pred(ci):
            m[ci[0]].append(ci)
            m[ci[1]].append(ci)
    return m

raw = collect(lambda ci: True)
both = collect(lambda ci: ci[0] in CSET and ci[1] in CSET)

w('=== 过滤前 vs 过滤后 ===')
w('全部 2 字词可配字的字: %d' % len(raw))
w('「两字都是教材生字」可配字的字: %d / %d = %.1f%%' % (len(both), len(chars), 100.0*len(both)/len(chars)))
w('配不到的字 %d 个: %s' % (len(chars)-len(both), ''.join(c for c in chars if c not in both)[:70]))
w()
w('=== 过滤后的抽样（对比质量）===')
for c in '天地人你我一二上水花江木手学大小中国日月光':
    ws = both.get(c, [])[:8]
    w('  %s : %s' % (c, ' '.join(ws) if ws else '(无)'))
w()
import statistics
cnts = [len(both[c]) for c in chars if c in both]
w('每字平均可配词 %.1f，中位数 %d' % (statistics.mean(cnts), statistics.median(cnts)))
w()
w('=== 配词数量最少的字（前 30）===')
few = sorted([c for c in chars if c in both], key=lambda c: len(both[c]))[:30]
for c in few:
    w('  %s : %s' % (c, ' '.join(both[c][:5])))

json.dump({c: both[c] for c in both}, open(os.path.join(CACHE, 'words-per-char.json'), 'w', encoding='utf-8'),
          ensure_ascii=False)
w()
w('已缓存 cache/words-per-char.json')

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
