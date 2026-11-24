# -*- coding: utf-8 -*-
"""诊断 + 交叉核对。报告写入 _report.txt"""
import re, json, os, io

WS = os.path.dirname(os.path.abspath(__file__))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

books = json.load(open(os.path.join(WS, '_books.json'), encoding='utf-8'))

w('=== A) 2hanzi 每册解析结果（首20 / 尾20）===')
for b in books:
    ch = b['chars']
    w('%-12s 标称%4d 解析%4d | %s ... %s' % (b['label'][:9], b['stated'], len(ch), ch[:20], ch[-20:]))

# --- cngwzj 原文格式探查 ---
w()
w('=== cngwzj _grades/1上.txt 原始行（前45行）===')
p = os.path.join(WS, '_grades', '1上.txt')
for i, ln in enumerate(open(p, encoding='utf-8').read().split('\n')[:45]):
    w('%3d| %s' % (i, ln[:100]))

open(os.path.join(WS, '_report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
