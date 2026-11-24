# -*- coding: utf-8 -*-
"""解析 2hanzi.com 生字表页面 -> 结构化 JSON，并核对标称字数。"""
import re, json, os

WS = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(WS, '_raw_2hanzi.txt')
OUT = os.path.join(WS, '_books.json')

src = open(SRC, encoding='utf-8').read()
lines = src.split('\n')

LABEL = re.compile(r'^([一二三四五六]年级[上下]册)([^（(]*)\((\d+)字\)')
CJK = re.compile(r'^[\u3400-\u9fff]+$')

books = []
for i, ln in enumerate(lines):
    m = LABEL.match(ln.strip())
    if not m:
        continue
    label = (m.group(1) + m.group(2)).strip()
    stated = int(m.group(3))
    chars = None
    for j in range(i + 1, min(i + 6, len(lines))):
        s = lines[j].strip()
        if s and CJK.match(s):
            chars = s
            break
    if chars is None:
        print('!! 未找到字串:', label)
        continue
    uniq = []
    seen = set()
    for ch in chars:
        if ch not in seen:
            seen.add(ch)
            uniq.append(ch)
    books.append({
        'label': label,
        'stated': stated,
        'raw_count': len(chars),
        'unique_count': len(uniq),
        'chars': ''.join(uniq),
    })

print('解析到 %d 册\n' % len(books))
print('%-22s %6s %6s %6s  %s' % ('册名', '标称', '原始', '去重', '判定'))
for b in books:
    ok = 'OK' if b['stated'] == b['unique_count'] else ('原始一致' if b['stated'] == b['raw_count'] else '不符')
    print('%-22s %6d %6d %6d  %s' % (b['label'], b['stated'], b['raw_count'], b['unique_count'], ok))

json.dump(books, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('\n已写出 ' + OUT)
total = sum(b['unique_count'] for b in books)
print('累计去重后 %d 字（未跨册去重）' % total)
