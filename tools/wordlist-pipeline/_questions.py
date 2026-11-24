# -*- coding: utf-8 -*-
"""为全部教材生字自动生成题目 -> data/questions.js
题型（都可从数据自动生成，不需要人工写）：
  A 读音题：给字选正确拼音，干扰项取**近音字**的拼音（pyTier 1~2），逼孩子真辨音。
  B 组词题：给「今___」选正确的字，干扰项取**同音/近音字**。
     出题前校验干扰项确实组不成词（查词频表），避免出现两个都对。
  C 拆形题：给部件选字 / 给字选部件（用 IDS 部件）。
"""
import os, io, json, re, random
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))
FAM = json.loads(re.match(r'^window\.FAMILIES\s*=\s*(.*);\s*$',
               open(os.path.join(APP, 'data', 'families.js'), encoding='utf-8').read(), re.S).group(1))

# 字 -> {py, grade, parts, sound}
info, order = {}, []
seen = set()
for b in payload['books']:
    for d in b['chars']:
        if d['c'] in seen:
            continue
        seen.add(d['c'])
        info[d['c']] = {'c': d['c'], 'py': d['py'], 'grade': b['grade'], 'book': b['book'],
                        'parts': [], 'sound': None, 'family': None}
        order.append(d['c'])
for f in FAM['families']:
    for d in f['chars']:
        if d['c'] in info:
            info[d['c']]['parts'] = d['parts']
            info[d['c']]['sound'] = d.get('sound')
            info[d['c']]['family'] = f['id']

# 词频
freq = {}
pat = re.compile(r'^([\u4e00-\u9fff]{2})\s+(\d+)\s')
for ln in open(os.path.join(CACHE, 'jieba-dict.txt'), encoding='utf-8', errors='replace'):
    m = pat.match(ln)
    if m:
        wd, f = m.group(1), int(m.group(2))
        if f > freq.get(wd, 0):
            freq[wd] = f
CSET = set(info)
MIN_FREQ = 40
words = defaultdict(list)
for wd, f in freq.items():
    if f >= MIN_FREQ and len(wd) == 2 and (wd[0] in CSET or wd[1] in CSET):
        words[wd[0]].append((f, wd))
        words[wd[1]].append((f, wd))
for c in words:
    # 去重并按词频降序；保留词本身，不要把频数误当成词
    unique = {wd: f for f, wd in words[c]}
    words[c] = [wd for wd, f in sorted(unique.items(), key=lambda kv: -kv[1])][:6]

# ---- 拼音工具（与应用内 pyTier 一致）----
TONE_MAP = {'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', 'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
            'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', 'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
            'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v',
            'ü': 'v', 'ń': 'n', 'ň': 'n', 'ǹ': 'n'}
INITIALS = ['zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h',
            'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w']
APICAL = {'zh', 'ch', 'sh', 'r', 'z', 'c', 's'}
def pb(py):
    return ''.join(TONE_MAP.get(ch, ch) for ch in py).lower()
def pf(py):
    b = pb(py)
    for i in INITIALS:
        if b.startswith(i):
            f = b[len(i):]
            return 'i0' if (f == 'i' and i in APICAL) else f
    return b
def pyTier(t, c):
    if not t or not c:
        return 0
    if pb(t) == pb(c):
        return 3
    ft, fc = pf(t), pf(c)
    if ft == fc:
        return 2
    if ft.rstrip('g') == fc.rstrip('g'):
        return 1
    return 0

# 按韵母分组，方便找近音字
by_final = defaultdict(list)
for c, d in info.items():
    by_final[pf(d['py'])].append(c)

def det_shuffle(items, seed):
    r = random.Random(seed)
    lst = list(items)
    r.shuffle(lst)
    return lst

def distractor_chars(c, k=2):
    """同音优先、再近音、最后同声母的其它字"""
    d0 = info[c]
    same = [x for x in by_final[pf(d0['py'])] if x != c and pb(info[x]['py']) != pb(d0['py'])]
    homo = [x for x in info if x != c and pb(info[x]['py']) == pb(d0['py'])]
    near = [x for x in by_final[pf(d0['py'])] if x != c]
    # 兜底：同声母
    ini = pb(d0['py'])[:2] if pb(d0['py'])[:2] in INITIALS else pb(d0['py'])[:1]
    sim = [x for x in info if x != c and pb(info[x]['py']).startswith(ini)] if ini else []
    res = []
    for pool in (homo, same, near, sim):
        for x in sorted(pool):
            if x not in res and x != c:
                res.append(x)
            if len(res) >= k:
                return res
    return res[:k]

questions, no_q = [], []
for c in order:
    d = info[c]
    py = d['py']
    q = {'c': c, 'py': py, 'grade': d['grade'], 'book': d['book'],
         'parts': d['parts'], 'sound': d['sound'], 'family': d['family'],
         'words': words.get(c, [])}
    # A 读音题（干扰项拼音必须互不相同，且与答案不同）
    ds = distractor_chars(c, 4)
    dps = []
    for x in ds:
        p = info[x]['py']
        if p != py and p not in dps:
            dps.append(p)
        if len(dps) == 2:
            break
    if len(dps) == 2:
        opts = det_shuffle([py] + dps, ord(c))
        q['qSound'] = {'prompt': '「%s」怎么读？' % c, 'options': opts, 'answer': opts.index(py)}
    # B 组词题
    ws = q['words']
    if ws:
        wd = ws[0]
        i = 0 if wd[0] == c else 1
        blank = wd[:i] + '___' + wd[i+1:]
        cand = [x for x in ds if x != c and (wd[:i] + x + wd[i+1:]) not in freq]
        if len(cand) >= 2:
            opts = det_shuffle([c] + cand[:2], ord(c) * 7)
            q['qWord'] = {'prompt': '哪个字能组成「%s」？' % blank, 'word': wd,
                          'options': opts, 'answer': opts.index(c)}
    if 'qSound' in q or 'qWord' in q:
        questions.append(q)
    else:
        no_q.append(c)

nA = sum(1 for q in questions if 'qSound' in q)
nB = sum(1 for q in questions if 'qWord' in q)
w('=== 题目生成结果 ===')
w('总字数 %d' % len(order))
w('生成题目 %d 字（%.1f%%）' % (len(questions), 100.0*len(questions)/len(order)))
w('  读音题(A): %d 字' % nA)
w('  组词题(B): %d 字' % nB)
w('  两题都有: %d 字' % sum(1 for q in questions if 'qSound' in q and 'qWord' in q))
w('无题可出: %d 字  %s' % (len(no_q), ''.join(no_q[:40])))
w()
w('=== 抽样检查 ===')
for c in '江青花田天云手':
    q = next((x for x in questions if x['c'] == c), None)
    if not q:
        w('  %s (无)' % c); continue
    w('  %s (%s) 组词: %s' % (c, q['py'], ' '.join(q['words'][:4])))
    if 'qSound' in q:
        w('     读音题: %s  选项=%s  答案=%s' % (q['qSound']['prompt'], q['qSound']['options'], q['qSound']['options'][q['qSound']['answer']]))
    if 'qWord' in q:
        w('     组词题: %s  选项=%s  答案=%s' % (q['qWord']['prompt'], q['qWord']['options'], q['qWord']['options'][q['qWord']['answer']]))

open(os.path.join(APP, 'data', 'questions.js'), 'w', encoding='utf-8').write(
    'window.QUESTIONS = ' + json.dumps({
        'version': 1,
        'edition': '部编版/统编版 小学语文识字表',
        'derived': 'curriculum.js + families.js + jieba词频 + chinese-xinhua',
        'note': '全自动生成：读音题(近音干扰) + 组词题(同音干扰,已验证干扰项组不成词)',
        'total': len(questions),
        'items': questions,
    }, ensure_ascii=False) + ';\n')
w()
w('输出 data/questions.js  %d bytes' % os.path.getsize(os.path.join(APP, 'data', 'questions.js')))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
