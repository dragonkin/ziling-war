# -*- coding: utf-8 -*-
"""汇总为 <应用根>/data/curriculum.js
   1上-5下 : cngwzj 识字表(分课) + 拼音版   -> verified=true
   6下     : sohu 逐课列表(80字，带原拼音)  -> verified=true
   6上     : 2hanzi 列表(120字，标称250存疑) -> verified=false
本脚本位于 tools/wordlist-pipeline/，应用根为其上两级。"""
import re, json, os, io
from pypinyin import lazy_pinyin, Style

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
RAW = os.path.join(HERE, 'raw')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

w('APP = ' + APP)

books = json.load(open(os.path.join(CACHE, '_final_wordlist.json'), encoding='utf-8'))
for b in books:
    b['grade'] = int(b['book'][0])
    b['term'] = b['book'][1]
    b['verified'] = True
    b['source'] = 'cngwzj 识字表(分课) + 拼音版'

# 拼音版抽取会漏掉少数字，用 pypinyin 补齐
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
w('pypinyin 补齐 %d 字；仍缺 %d' % (filled, len(still)))

# ---- 6下：sohu ----
sohu = open(os.path.join(RAW, '_src_sohu6x.txt'), encoding='utf-8').read()
PAIR = re.compile(r'([\u4e00-\u9fff])\(([a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùüǖǘǚǜ]+)\)')
seq = PAIR.findall(sohu)
lessons6x = len(re.findall(r'^\s*\d+、', sohu, re.M))
w('6下 sohu: %d 字 / %d 课' % (len(seq), lessons6x))
books.append({
    'book': '6下', 'grade': 6, 'term': '下', 'lessons': lessons6x,
    'verified': True, 'source': 'sohu 逐课列表(80字)',
    'chars': [{'c': c, 'py': p} for c, p in seq],
})

# ---- 6上：2hanzi ----
zh = json.load(open(os.path.join(CACHE, '_books.json'), encoding='utf-8'))
six_u = [b for b in zh if b['label'].startswith('六年级上册')][0]
chars6u = [{'c': c, 'py': ''.join(lazy_pinyin(c, style=Style.TONE))} for c in six_u['chars']]
w('6上 2hanzi: %d 字（该站标称 %d，存疑）' % (len(chars6u), six_u['stated']))
books.append({
    'book': '6上', 'grade': 6, 'term': '上', 'lessons': 0,
    'verified': False, 'source': '2hanzi 列表（标称字数与实际不符，待复核）',
    'chars': chars6u,
})

books.sort(key=lambda b: (b['grade'], 0 if b['term'] == '上' else 1))
empty = sum(1 for b in books for d in b['chars'] if not d['py'])
w('最终空拼音条目: %d' % empty)

os.makedirs(os.path.join(APP, 'data'), exist_ok=True)
open(os.path.join(APP, 'data', 'curriculum.js'), 'w', encoding='utf-8').write(
    'window.CURRICULUM = ' + json.dumps({
        'version': 1,
        'domain': '识字表（会认字）',
        'edition': '部编版/统编版 小学语文',
        'books': books,
    }, ensure_ascii=False) + ';\n')

w()
tot = 0
for b in books:
    tot += len(b['chars'])
    w('%-5s 年级%d  %4d 字  %s' % (b['book'], b['grade'], len(b['chars']),
                                   '已验证' if b['verified'] else '待复核'))
w('合计 %d 字 / %d 册' % (tot, len(books)))
w('输出 %d bytes' % os.path.getsize(os.path.join(APP, 'data', 'curriculum.js')))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
