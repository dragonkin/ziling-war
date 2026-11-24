# -*- coding: utf-8 -*-
"""拼音数据质检：拿 pypinyin 与 curriculum.js 的拼音逐字比对，找出抽取错误的条目。"""
import os, io, re, json
from pypinyin import lazy_pinyin, Style

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))

TONE_MAP = {'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', 'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
            'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', 'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
            'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v',
            'ü': 'v', 'ń': 'n', 'ň': 'n', 'ǹ': 'n'}
def base(py):
    return ''.join(TONE_MAP.get(c, c) for c in py).lower()

seen, mism, seen_py = set(), [], {}
for b in payload['books']:
    for d in b['chars']:
        c, py = d['c'], d['py']
        if c in seen:
            continue
        seen.add(c)
        ref = ''.join(lazy_pinyin(c, style=Style.TONE))
        if base(py) != base(ref):
            mism.append((c, py, ref, b['book']))

w('比对字数: %d' % len(seen))
w('拼音不一致: %d' % len(mism))
w()
# 分类：缺声母 vs 完全不同 vs 多音字
import collections
no_initial = [(c, py, ref) for c, py, ref, bk in mism
              if base(py) and base(ref) and base(py)[0] in 'aeiouv' and base(ref)[0] not in 'aeiouv']
w('=== A) 疑似丢失声母（%d 个）===' % len(no_initial))
for c, py, ref in no_initial[:40]:
    w('   %s  现=%s  应为=%s' % (c, py, ref))
w()
others = [m for m in mism if m not in [(c, p, r, bk) for c, p, r in no_initial for bk in [None]] and
          not (base(m[1]) and base(m[2]) and base(m[1])[0] in 'aeiouv' and base(m[2])[0] not in 'aeiouv')]
w('=== B) 其它不一致（%d 个，多为多音字）===' % len(others))
for c, py, ref, bk in others[:40]:
    w('   %s(%s)  现=%s  参考=%s' % (c, bk, py, ref))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
