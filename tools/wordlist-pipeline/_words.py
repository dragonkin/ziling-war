# -*- coding: utf-8 -*-
"""取「词语」数据（chinese-xinhua ci.json），评估能否为每个字自动生成组词题。
并统计：每个字能配到多少个常用词（用于填空/干扰项）。"""
import os, io, json, urllib.request, re
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

DST = os.path.join(CACHE, 'ci.json')
URLS = [
    'https://raw.githubusercontent.com/pwxcoo/chinese-xinhua/master/data/ci.json',
    'https://gh-proxy.com/https://raw.githubusercontent.com/pwxcoo/chinese-xinhua/master/data/ci.json',
]
if not os.path.exists(DST) or os.path.getsize(DST) < 1000000:
    for u in URLS:
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

data = json.load(open(DST, encoding='utf-8'))
w('词条数 %d' % len(data))
w('样例 ' + json.dumps(data[0], ensure_ascii=False)[:160])

# 只保留 2 字词（最适合做「填一个字」的题）
words = defaultdict(list)
CJK = re.compile(r'^[\u4e00-\u9fff]+$')
for it in data:
    ci = (it.get('ci') or '').strip()
    if len(ci) == 2 and CJK.match(ci):
        words[ci[0]].append(ci)
        words[ci[1]].append(ci)
w('可配词的不同的字: %d' % len(words))

payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))
chars = []
seen = set()
for b in payload['books']:
    for d in b['chars']:
        if d['c'] not in seen:
            seen.add(d['c'])
            chars.append(d['c'])

have = [c for c in chars if c in words]
miss = [c for c in chars if c not in words]
w()
w('=== 组词题可行性 ===')
w('能配到 2 字词的字: %d / %d = %.1f%%' % (len(have), len(chars), 100.0*len(have)/len(chars)))
w('配不到词的字 %d 个: %s' % (len(miss), ''.join(miss[:60])))
import statistics
cnts = [len(words[c]) for c in have]
w('每字平均可配词数 %.1f，中位数 %d，最少 %d' % (statistics.mean(cnts), statistics.median(cnts), min(cnts)))
w()
w('=== 抽样 ===')
for c in chars[:12]:
    ws = words.get(c, [])[:6]
    w('  %s : %s' % (c, ' '.join(ws) if ws else '(无)'))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
