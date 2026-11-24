# -*- coding: utf-8 -*-
"""合并两个来源，产出最终字表数据集。
  字序列 <- cngwzj /gushi/ 原文版（分课次，干净）
  拼音   <- cngwzj /pygushi/ 拼音版（配对抽取）
报告写入 _report.txt。"""
import re, json, os, io

WS = os.path.dirname(os.path.abspath(__file__))
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

# ---- 1) 拼音映射（来自拼音版）----
PY = 'a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùüǖǘǚǜńňǹ'
PAIR = re.compile(r'([' + PY + r']+)([\u4e00-\u9fff])')
py_map = {}
for fn in sorted(os.listdir(os.path.join(WS, '_grades'))):
    t = open(os.path.join(WS, '_grades', fn), encoding='utf-8').read()
    t = t.replace('**', '').replace('- ', '').replace('\n', '').replace('\r', '')
    for m in PAIR.finditer(t):
        c, py = m.group(2), m.group(1)
        if c not in py_map:
            py_map[c] = py
w('拼音版共覆盖 %d 个不同汉字' % len(py_map))

# ---- 2) 字序列（来自原文版）----
LESSON = re.compile(r'^(?:语文园地[一二三四五六七八九十]+|\d+)\s*[：:]\s*([\u4e00-\u9fff]+)\s*$')
books_data = []
w()
w('%-5s %7s %7s %7s %7s  %s' % ('册', '课次', '原始', '去重', '有拼音', '对照2hanzi标称'))
zh = {b['label']: b for b in json.load(open(os.path.join(WS, '_books.json'), encoding='utf-8'))}
def key_of(label):
    return str('一二三四五六'.index(label[0]) + 1) + ('上' if '上' in label else '下')
stated = {key_of(b['label']): b['stated'] for b in zh.values()}

for fn in sorted(os.listdir(os.path.join(WS, '_gushi'))):
    book = fn.replace('.txt', '')
    text = open(os.path.join(WS, '_gushi', fn), encoding='utf-8').read()
    chars, nlesson = [], 0
    for ln in text.split('\n'):
        m = LESSON.match(ln.strip())
        if m:
            nlesson += 1
            chars.extend(m.group(1))
    uniq, seen = [], set()
    for c in chars:
        if c not in seen:
            seen.add(c)
            uniq.append(c)
    havepy = sum(1 for c in uniq if c in py_map)
    miss = [c for c in uniq if c not in py_map]
    w('%-5s %7d %7d %7d %7d  %d  %s' % (book, nlesson, len(chars), len(uniq), havepy,
                                          stated.get(book, 0),
                                          ('缺拼音: ' + ''.join(miss[:20])) if miss else ''))
    books_data.append({
        'book': book, 'lessons': nlesson,
        'chars': [{'c': c, 'py': py_map.get(c, '')} for c in uniq],
    })

json.dump(books_data, open(os.path.join(WS, '_final_wordlist.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)
total = sum(len(b['chars']) for b in books_data)
w()
w('合计（各册内去重，未跨册合并）：%d 字' % total)
w()
w('=== 抽样 1上 前 25 ===')
w(' '.join('%s(%s)' % (d['c'], d['py']) for d in books_data[0]['chars'][:25]))

open(os.path.join(WS, '_report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
