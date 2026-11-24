# -*- coding: utf-8 -*-
"""交叉核对两个来源的字表：
   A) 2hanzi.com 汇总页 -> _books.json（已解析）
   B) cngwzj.com 按课文分课页 -> _grades/*.txt
把报告写入 _report.txt（避免控制台乱码）。"""
import re, json, os, io

WS = os.path.dirname(os.path.abspath(__file__))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

# ---------- A: 2hanzi ----------
books = json.load(open(os.path.join(WS, '_books.json'), encoding='utf-8'))
w('=== A) 2hanzi.com 汇总页 ===')
for b in books:
    w('%-24s 标称%5d  解析%5d' % (b['label'], b['stated'], b['unique_count']))

# ---------- B: cngwzj ----------
LESSON = re.compile(r'^(?:语文园地[一二三四五六七八九十]+|\d+)\s*[：:]\s*([\u4e00-\u9fff]+)$')
CJK = re.compile(r'[\u4e00-\u9fff]')

gd = os.path.join(WS, '_grades')
w()
w('=== B) cngwzj.com 按课分册页 ===')
resB = {}
for fn in sorted(os.listdir(gd)):
    label = fn.replace('.txt', '')
    text = open(os.path.join(gd, fn), encoding='utf-8').read()
    chars = []
    for ln in text.split('\n'):
        m = LESSON.match(ln.strip())
        if m:
            chars.extend(m.group(1))
    uniq = []
    seen = set()
    for c in chars:
        if c not in seen:
            seen.add(c)
            uniq.append(c)
    resB[label] = ''.join(uniq)
    w('%-10s 课次数=%3d  原始%5d  去重%5d' % (label, 0, len(chars), len(uniq)))

# ---------- 对比 ----------
w()
w('=== 对比（A vs B）===')
for b in books:
    key = b['label'][:3]
    A = set(b['chars'])
    B = resB.get(key)
    if B is None:
        w('%-10s  B 无此册（本站缺六年级）' % key)
        continue
    Bs = set(B)
    w('%-10s  A=%4d  B=%4d  共有%4d  A独有%4d  B独有%4d'
      % (key, len(A), len(Bs), len(A & Bs), len(A - Bs), len(Bs - A)))

open(os.path.join(WS, '_report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('report written')
