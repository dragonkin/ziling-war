# -*- coding: utf-8 -*-
"""修复 curriculum.js 的拼音：区分「抽取损坏」与「多音字」，只修前者。
判定（base=去声调小写）：
  1. 与 pypinyin 一致            -> 保留
  2. py 是参考的**真后缀**        -> 损坏（丢声母），改用参考
  3. 仅差尾字母 g（前后鼻音）      -> 损坏，改用参考
  4. py 不是任何合法音节           -> 损坏，改用参考
  5. 其余（如 cháng/zhǎng）       -> 多音字，**保留教材读音**
"""
import os, io, re, json
from pypinyin import lazy_pinyin, Style

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

SRC = os.path.join(APP, 'data', 'curriculum.js')
payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(SRC, encoding='utf-8').read(), re.S).group(1))

TONE_MAP = {'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', 'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
            'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', 'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
            'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v',
            'ü': 'v', 'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'ḿ': 'm'}
def base(py):
    return ''.join(TONE_MAP.get(c, c) for c in py).lower()

# 合法音节集合：由 pypinyin 对全部字产生的读音反推
seen, refs = set(), {}
for b in payload['books']:
    for d in b['chars']:
        c = d['c']
        if c in seen:
            continue
        seen.add(c)
        refs[c] = ''.join(lazy_pinyin(c, style=Style.TONE))
VALID = set(base(v) for v in refs.values() if v)
w('参考音节集合大小: %d' % len(VALID))

def is_corrupt(py, ref):
    bp, br = base(py), base(ref)
    if not bp or bp == br:
        return False
    if bp and br.endswith(bp) and bp != br:          # 真后缀
        return True
    if bp.rstrip('g') == br.rstrip('g') and bp != br:  # 前后鼻音
        return True
    if bp not in VALID:                                # 非法音节
        return True
    return False

fixed, kept_multi, stats = 0, [], []
for b in payload['books']:
    for d in b['chars']:
        c, py = d['c'], d['py']
        ref = refs.get(c, '')
        if is_corrupt(py, ref):
            stats.append((c, py, ref))
            d['py'] = ref
            fixed += 1
        elif base(py) != base(ref):
            kept_multi.append((c, py, ref))

w('修正损坏拼音: %d 个' % fixed)
w('保留教材读音（多音字等）: %d 个' % len(kept_multi))
w()
w('=== 修正样例（前 30）===')
for c, old, new in stats[:30]:
    w('   %s  %s -> %s' % (c, old, new))
w()
w('=== 保留的多音字样例（前 25）===')
for c, py, ref in kept_multi[:25]:
    w('   %s  教材=%s  pypinyin=%s' % (c, py, ref))

open(SRC, 'w', encoding='utf-8').write('window.CURRICULUM = ' + json.dumps(payload, ensure_ascii=False) + ';\n')
w()
w('已写回 ' + SRC)

# 复核
bad = 0
for b in payload['books']:
    for d in b['chars']:
        if is_corrupt(d['py'], refs.get(d['c'], '')):
            bad += 1
w('复核：仍判定为损坏的条目 = %d' % bad)

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
