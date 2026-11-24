# -*- coding: utf-8 -*-
"""解析 raw/_gushi/*.txt（古文之家 按课生字）与 data/curriculum.js，做对比诊断。"""
import json, re, os, sys, io

ROOT = os.path.dirname(os.path.abspath(__file__))
WROOT = os.path.dirname(os.path.dirname(ROOT))
sys.stdout.reconfigure(encoding='utf-8')

BOOKS = ['1上','1下','2上','2下','3上','3下','4上','4下','5上','5下']

def load_curriculum():
    p = os.path.join(WROOT, 'data', 'curriculum.js')
    s = open(p, encoding='utf-8').read()
    i = s.index('{'); j = s.rindex('}') + 1
    return json.loads(s[i:j])

def parse_gushi(book):
    """返回 [{'section':..,'label':..,'chars':[..]}] 按页面顺序。"""
    p = os.path.join(ROOT, 'raw', '_gushi', book + '.txt')
    if not os.path.exists(p):
        return None
    lines = open(p, encoding='utf-8').read().split('\n')
    # 从「课文-识字表」那一行之后开始
    start = 0
    for k, l in enumerate(lines):
        if '识字表' in l and ('打印版' in l or l.strip().endswith('识字表')):
            start = k + 1
            break
    out = []
    section = ''
    for l in lines[start:]:
        l = l.strip()
        if l.startswith('**相关内容') or l.startswith('[三年级上册生字表]'):
            break
        if l in ('识字', '汉语拼音', '课文'):
            section = l
            continue
        m = re.match(r'^(语文园地[一二三四五六七八九十]*)\s*[：:]\s*(.+)$', l)
        if m:
            out.append({'section': section, 'label': m.group(1), 'kind': '园地',
                        'chars': [c for c in m.group(2) if '\u4e00' <= c <= '\u9fff']})
            continue
        m = re.match(r'^(\d+)\s*[：:]\s*(.+)$', l)
        if m:
            out.append({'section': section, 'label': m.group(1), 'kind': '课',
                        'chars': [c for c in m.group(2) if '\u4e00' <= c <= '\u9fff']})
    return out

def dump_groups():
    for b in BOOKS:
        g = parse_gushi(b)
        print(f'########## {b}  ({len(g)} groups) ##########')
        for i, it in enumerate(g):
            print(f'{i:3d} [{it["section"] or "-"}] {it["kind"]} {it["label"]:<6} n={len(it["chars"]):3d}  {"".join(it["chars"])}')


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'dump':
        dump_groups(); return
    cur = load_curriculum()
    cbook = {b['book']: [x['c'] for x in b['chars']] for b in cur['books']}
    for b in BOOKS:
        g = parse_gushi(b)
        if g is None:
            print(f'--- {b}: 无 raw 数据'); continue
        flat = []
        for it in g:
            flat.extend(it['chars'])
        cs = cbook.get(b, [])
        print(f'===== {b} ===== 课次条目={len(g)} 原文合计={len(flat)} 去重={len(set(flat))} | curriculum={len(cs)}')
        # 逐条对齐检查：curriculum 顺序是否与原文顺序一致
        # 用「原文按顺序在 curriculum 中贪心匹配」
        idx = 0; miss = []
        pos = {c: [] for c in set(cs)}
        for i, c in enumerate(cs):
            pos[c].append(i)
        used = set()
        for c in flat:
            cand = [i for i in pos.get(c, []) if i not in used]
            if cand:
                used.add(cand[0])
            else:
                miss.append(c)
        extra = [c for c in cs if c not in set(flat)]
        print(f'   curriculum 有但原文无: {len(extra)} {extra[:40]}')
        print(f'   原文有但 curriculum 无: {len(miss)} {miss[:40]}')

if __name__ == '__main__':
    main()
