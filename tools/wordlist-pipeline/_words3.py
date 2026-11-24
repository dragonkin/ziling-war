# -*- coding: utf-8 -*-
"""用带词频的分词词典（jieba dict.txt）挑「常用词」，为每个字配 3-5 个高频组词。
这是自动生成组词题的关键一步：没有词频就分不出「白天」和「彻天」。"""
import os, io, json, re, urllib.request
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

DST = os.path.join(CACHE, 'jieba-dict.txt')
if not os.path.exists(DST) or os.path.getsize(DST) < 1000000:
    for u in ['https://raw.githubusercontent.com/fxsjy/jieba/master/jieba/dict.txt',
              'https://gh-proxy.com/https://raw.githubusercontent.com/fxsjy/jieba/master/jieba/dict.txt']:
        try:
            w('下载 ' + u)
            req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
            d = urllib.request.urlopen(req, timeout=180).read()
            open(DST, 'wb').write(d)
            w('  %d bytes' % len(d))
            if len(d) > 1000000:
                break
        except Exception as e:
            w('  失败 %s' % e)
else:
    w('缓存命中')
w('文件 %d bytes' % os.path.getsize(DST))

freq = {}
pat = re.compile(r'^([\u4e00-\u9fff]{2})\s+(\d+)\s')
for ln in open(DST, encoding='utf-8', errors='replace'):
    m = pat.match(ln)
    if m:
        wd, f = m.group(1), int(m.group(2))
        if f > freq.get(wd, 0):
            freq[wd] = f
w('带词频的 2 字词: %d' % len(freq))

payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))
chars, seen = [], set()
for b in payload['books']:
    for d in b['chars']:
        if d['c'] not in seen:
            seen.add(d['c'])
            chars.append(d['c'])
CSET = set(chars)

byc = defaultdict(list)
for wd, f in freq.items():
    if wd[0] in CSET or wd[1] in CSET:
        byc[wd[0]].append((f, wd))
        byc[wd[1]].append((f, wd))

MIN_FREQ = 60   # 词频门槛：低于这个数基本不是常用词

for t in (300, 150, 80, 60, 40, 20):
    n = sum(1 for c in chars if any(f >= t for f, _ in byc.get(c, [])))
    w('门槛 %4d -> 可覆盖 %d 字 (%.1f%%)' % (t, n, 100.0 * n / len(chars)))
w()
picked, thin = {}, []
for c in chars:
    lst = sorted({wd: f for f, wd in byc.get(c, [])}.items(), key=lambda kv: -kv[1])
    good = [wd for wd, f in lst if f >= MIN_FREQ][:6]
    if good:
        picked[c] = good
    else:
        thin.append(c)

w()
w('=== 结果（词频门槛 %d）===' % MIN_FREQ)
w('能配到常用词的字: %d / %d = %.1f%%' % (len(picked), len(chars), 100.0*len(picked)/len(chars)))
w('配不到的字 %d 个: %s' % (len(thin), ''.join(thin[:70])))
w()
w('=== 质量抽样（对比之前）===')
for c in '天地人你我一二上水花江木手学大小中国日月光爸车':
    w('  %s : %s' % (c, ' '.join(picked.get(c, ['(无)']))))
w()
import statistics
cnts = [len(v) for v in picked.values()]
w('每字平均 %.1f 个词，最少 %d' % (statistics.mean(cnts), min(cnts)))
w()
w('=== 词频最小的 25 个字（确认门槛是否合理）===')
for c in sorted(picked, key=lambda c: -freq[picked[c][-1]])[:0] or list(thin[:25]):
    pass
for c in thin[:25]:
    lst = sorted({wd: f for f, wd in byc.get(c, [])}.items(), key=lambda kv: -kv[1])[:3]
    w('  %s : %s' % (c, ' '.join('%s(%d)' % (a, b) for a, b in lst) or '(完全无)'))

json.dump(picked, open(os.path.join(CACHE, 'words-common.json'), 'w', encoding='utf-8'), ensure_ascii=False)
w()
w('已缓存 cache/words-common.json')

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
