# -*- coding: utf-8 -*-
"""从 cngwzj「拼音版」页面抽取 (字, 拼音) 序列。
页面里正文是「拼音在前、汉字在后」交替排布，被抽取器随意断行，
例如： yī / **一**nián / 年jí / 级 ...
所以：去掉 markdown 记号与换行，再用 (拼音)(汉字) 配对即可。
标题「一年级上册生字表」也在正文里，从第一个课次标记 `数字：` 之后开始取，排除标题。"""
import re, json, os, io, unicodedata

WS = os.path.dirname(os.path.abspath(__file__))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

PY = 'a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùüǖǘǚǜńňǹ'
PAIR = re.compile(r'([' + PY + r']+)([\u4e00-\u9fff])')
LESSON = re.compile(r'\d+\s*[：:]')

def clean(text):
    t = text.replace('**', '').replace('- ', '')
    return t.replace('\n', '').replace('\r', '')

def extract(path):
    raw = open(path, encoding='utf-8').read()
    t = clean(raw)
    i = 0
    m = LESSON.search(t)
    if m:
        i = m.start()
    seq = []
    for mm in PAIR.finditer(t, i):
        seq.append((mm.group(2), mm.group(1)))
    return seq

books = json.load(open(os.path.join(WS, '_books.json'), encoding='utf-8'))
stated = {b['label'][:3].replace('年级', '').replace('册', ''): b['stated'] for b in books}
# 一年级上册 -> 1上
def key_of(label):
    g = '一二三四五六'.index(label[0]) + 1
    t = '上' if '上' in label else '下'
    return str(g) + t
stated2 = {key_of(b['label']): b['stated'] for b in books}
zh_list = {key_of(b['label']): b['chars'] for b in books}

gd = os.path.join(WS, '_grades')
result = []
w('%-6s %8s %8s %8s   %s' % ('册', '抽取', '去重', '2hanzi', '说明'))
for fn in sorted(os.listdir(gd)):
    key = fn.replace('.txt', '')
    seq = extract(os.path.join(gd, fn))
    uniq, seen = [], set()
    for c, py in seq:
        if c not in seen:
            seen.add(c)
            uniq.append((c, py))
    zl = zh_list.get(key, '')
    overlap = len([1 for c, _ in uniq if c in set(zl)])
    result.append({'book': key, 'count': len(uniq), 'chars': [{'c': c, 'py': py} for c, py in uniq]})
    w('%-6s %8d %8d %8d   与2hanzi重叠 %d' % (key, len(seq), len(uniq), len(zl), overlap))

json.dump(result, open(os.path.join(WS, '_wordlist.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)

w()
w('=== 抽样：1上 前 30 个字 + 拼音 ===')
for c, py in result[0]['chars'][:30] if result else []:
    w('%s %s' % (c, py))

open(os.path.join(WS, '_report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
