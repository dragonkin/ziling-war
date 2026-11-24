# -*- coding: utf-8 -*-
"""补齐拼音并产出应用可直接加载的 data/curriculum.js（部编版 1-6 年级字表）。"""
import re, json, os, io
from pypinyin import lazy_pinyin, Style

WS = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(WS, 'data')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

books = json.load(open(os.path.join(WS, '_final_wordlist.json'), encoding='utf-8'))

filled, still = 0, []
for b in books:
    for d in b['chars']:
        if d['py']:
            continue
        py = ''.join(lazy_pinyin(d['c'], style=Style.TONE))
        if py and py != d['c']:
            d['py'] = py
            filled += 1
        else:
            still.append(d['c'])

w('用 pypinyin 补齐 %d 个字；仍缺 %d 个: %s' % (filled, len(still), ''.join(still[:40])))

# 去掉完全没拼音的（应为 0）
for b in books:
    b['chars'] = [d for d in b['chars'] if d['py']]

for b in books:
    b['grade'] = int(b['book'][0])
    b['term'] = b['book'][1]

os.makedirs(APP, exist_ok=True)
js = 'window.CURRICULUM = ' + json.dumps({
    'version': 1,
    'source': '部编版（统编）小学语文识字表',
    'books': books,
}, ensure_ascii=False) + ';\n'
open(os.path.join(APP, 'curriculum.js'), 'w', encoding='utf-8').write(js)

w()
w('%-5s %6s %6s' % ('册', '字数', '课次'))
tot = 0
for b in books:
    tot += len(b['chars'])
    w('%-5s %6d %6d' % (b['book'], len(b['chars']), b['lessons']))
w('合计 %d 字（10 册；缺六年级两册）' % tot)
w('输出: data/curriculum.js  ' + str(os.path.getsize(os.path.join(APP, 'curriculum.js'))) + ' bytes')

open(os.path.join(WS, '_report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
