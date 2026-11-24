# -*- coding: utf-8 -*-
"""取「部首」数据，与 curriculum.js 的 3209 字求交集，报告覆盖率与主要部首。
数据源：chinese-xinhua 的 word.json（字段含 radicals=部首、strokes=笔画）"""
import json, os, io, re, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
os.makedirs(CACHE, exist_ok=True)
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

SRC = os.path.join(CACHE, 'xinhua-word.json')
URLS = [
    'https://raw.githubusercontent.com/pwxcoo/chinese-xinhua/master/data/word.json',
    'https://gh-proxy.com/https://raw.githubusercontent.com/pwxcoo/chinese-xinhua/master/data/word.json',
]
if not os.path.exists(SRC) or os.path.getsize(SRC) < 1000000:
    for u in URLS:
        try:
            w('下载 ' + u)
            req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
            data = urllib.request.urlopen(req, timeout=120).read()
            open(SRC, 'wb').write(data)
            w('  得到 %d bytes' % len(data))
            if len(data) > 1000000:
                break
        except Exception as e:
            w('  失败: %s' % e)
else:
    w('缓存命中 ' + SRC)

raw = json.load(open(SRC, encoding='utf-8'))
w('数据集条目数: %d' % len(raw))
w('样例: ' + json.dumps(raw[0], ensure_ascii=False)[:200])

rad = {}
for it in raw:
    ch = it.get('word') or ''
    r = (it.get('radicals') or '').strip()
    if len(ch) == 1 and r:
        rad[ch] = {'radical': r, 'strokes': it.get('strokes')}
w('有部首的单字: %d' % len(rad))

# curriculum 覆盖
src = open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read()
payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$', src, re.S).group(1))
chars = []
for b in payload['books']:
    for d in b['chars']:
        chars.append(d['c'])
uniq = []
seen = set()
for c in chars:
    if c not in seen:
        seen.add(c)
        uniq.append(c)
w()
w('curriculum 总字 %d（去重 %d）' % (len(chars), len(uniq)))
have = [c for c in uniq if c in rad]
miss = [c for c in uniq if c not in rad]
w('有部首 %d / %d = %.1f%%' % (len(have), len(uniq), 100.0 * len(have) / len(uniq)))
w('缺部首 %d 个: %s' % (len(miss), ''.join(miss)))

from collections import Counter
cnt = Counter(rad[c]['radical'] for c in have)
w()
w('=== 出现最多的 30 个部首 ===')
for r, n in cnt.most_common(30):
    w('  %s  %3d' % (r, n))
w()
w('不同部首数: %d' % len(cnt))
w('只出现 1 次的部首数: %d' % sum(1 for r, n in cnt.items() if n == 1))

json.dump(rad, open(os.path.join(CACHE, 'radicals.json'), 'w', encoding='utf-8'), ensure_ascii=False)
open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
