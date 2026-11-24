# -*- coding: utf-8 -*-
import re, json, os, io

WS = os.path.dirname(os.path.abspath(__file__))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

CN = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6}
def norm(g, t):
    return '%d%s' % (CN[g], t)

SEC = re.compile(r'\*{3,}\s*([一二三四五六])\s*年?([上下])\s*册?\s*\((\d+)\)')
LESSON = re.compile(r'^\s*(?:-\s*|\d+\s*[.、]?\s*)')

raw = open(os.path.join(WS, '_src_cnblogs.txt'), encoding='utf-8').read()
cnb, cur = {}, None
for ln in raw.split('\n'):
    m = SEC.search(ln)
    if m:
        cur = norm(m.group(1), m.group(2))
        cnb[cur] = {'stated': int(m.group(3)), 'chars': []}
        continue
    if cur and LESSON.match(ln) and not ln.strip().startswith('*'):
        for ch in ln:
            if '\u4e00' <= ch <= '\u9fff':
                cnb[cur]['chars'].append(ch)

def uniq(s):
    r, seen = [], set()
    for c in s:
        if c not in seen:
            seen.add(c); r.append(c)
    return ''.join(r)

w('=== cnblogs 解析结果（据称写字表）===')
w('%-6s %8s %8s' % ('册', '标称', '去重'))
for k in sorted(cnb, key=lambda x: (int(x[0]), x[1])):
    cnb[k]['u'] = uniq(cnb[k]['chars'])
    w('%-6s %8d %8d' % (k, cnb[k]['stated'], len(cnb[k]['u'])))

mine = json.load(open(os.path.join(WS, '_final_wordlist.json'), encoding='utf-8'))
mk = {b['book']: set(d['c'] for d in b['chars']) for b in mine}

w()
w('=== 关键检验：cnblogs 是否为「识字表」的子集 ===')
w('%-6s %8s %8s %8s %8s   %s' % ('册', '识字表', 'cnblogs', '共有', '不在识字表', '结论'))
for k in ['1上','1下','2上','2下','3上','3下','4上','4下','5上','5下']:
    if k not in cnb or k not in mk: continue
    A, B = mk[k], set(cnb[k]['u'])
    onlyB = B - A
    w('%-6s %8d %8d %8d %8d   %s' % (k, len(A), len(B), len(A & B), len(onlyB),
      '子集 ✓（写字表⊂识字表）' if not onlyB else '有%d字不在识字表' % len(onlyB)))
    if onlyB:
        w('        样例: ' + ''.join(sorted(onlyB)[:20]))

books2 = json.load(open(os.path.join(WS, '_books.json'), encoding='utf-8'))
z = {}
for b in books2:
    z['%d%s' % (CN[b['label'][0]], '上' if '上' in b['label'][:6] else '下')] = b['chars']

w()
w('=== 六年级冲突 ===')
for k in ['6上', '6下']:
    A = set(z.get(k, ''))
    B = set(cnb.get(k, {}).get('u', ''))
    w('%s: 2hanzi=%d cnblogs=%d 共有=%d 2hanzi独有=%d cnblogs独有=%d'
      % (k, len(A), len(B), len(A & B), len(A - B), len(B - A)))
    w('   cnblogs独有: ' + ''.join(sorted(B - A)[:36]))
    w('   2hanzi独有: ' + ''.join(sorted(A - B)[:36]))

open(os.path.join(WS, '_report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
