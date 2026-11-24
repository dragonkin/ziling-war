# -*- coding: utf-8 -*-
"""把古文之家的「按课生字表」解析成 单元 -> 课 -> 生字，生成 data/units.js。

原始文件 tools/wordlist-pipeline/raw/_gushi/{册}.txt，形如：

    识字
    1：天地人你我他
    2：一二三四五上下
    ...
    语文园地一：六七八九十
    汉语拼音
    3：爸妈
    ...
    课文
    1：秋气了树叶片大飞会个

「语文园地」就是部编版教材的单元收口标志 —— 用它切单元。

同时和 data/curriculum.js（2hanzi.com 的整册字表）交叉核对，
报出覆盖率差异，不做静默假设。

用法：
    python gen-units.py            # 只诊断，不写文件
    python gen-units.py --write    # 写 data/units.js
"""
import json, re, os, sys, io

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(HERE, 'raw', '_gushi')
sys.stdout.reconfigure(encoding='utf-8')

CJK = lambda s: ''.join(c for c in s if '\u4e00' <= c <= '\u9fff')
CN_NUM = '一二三四五六七八九十'
BOOK_ORDER = ['1上', '1下', '2上', '2下', '3上', '3下',
              '4上', '4下', '5上', '5下', '6上', '6下']
# 5上/5下原始生字表页面没有「语文园地」行，用已核对的电子课本目录页作单元边界。
# 来源：dzkbw.com/books/rjb/yuwen/xs5s_2019/ 与 xs5x_2019/
# 格式 (该单元最后一课的序号, 真实单元号) —— 单元号必须显式写出，
# 因为 5下第三单元是「综合性学习：遨游汉字王国」，没有生字、不占生字表条目，
# 如果按顺序编号就会把第四单元错标成第三单元。
MANUAL_UNIT_ENDS = {
    '5上': [(4, 1), (8, 2), (11, 3), (15, 4), (17, 5), (20, 6), (24, 7), (27, 8)],
    '5下': [(4, 1), (8, 2), (12, 4), (14, 5), (17, 6), (20, 7), (23, 8)],
}


def load_curriculum():
    p = os.path.join(APP, 'data', 'curriculum.js')
    s = io.open(p, encoding='utf-8').read()
    return json.loads(s[s.index('{'):s.rindex('}') + 1])


def load_gamechars():
    p = os.path.join(APP, 'data', 'gamechars.js')
    s = io.open(p, encoding='utf-8').read()
    return json.loads(s[s.index('{'):s.rindex('}') + 1])


def parse_book(book):
    """返回 [{'section','kind','label','chars':[...]}]，按原文顺序。
       只读「识字表打印版」到「相关内容/图片版」之间的正文。"""
    p = os.path.join(RAW, book + '.txt')
    if not os.path.exists(p):
        return None
    lines = io.open(p, encoding='utf-8').read().split('\n')

    start = None
    for i, l in enumerate(lines):
        if '识字表' in l and ('打印版' in l or l.strip().endswith('识字表')):
            start = i + 1
            break
    if start is None:
        return None

    out, section = [], ''
    for l in lines[start:]:
        l = l.strip()
        if not l:
            continue
        # 正文结束标志
        if l.startswith('**相关内容') or l.startswith('图片版') or re.match(r'^\d+：.*\d：', l):
            break
        if l in ('识字', '汉语拼音', '课文'):
            section = l
            continue
        m = re.match(r'^语文园地([' + CN_NUM + r']*)\s*[：:]\s*(.+)$', l)
        if m:
            out.append({'section': section, 'kind': '园地',
                        'label': '语文园地' + (m.group(1) or ''), 'chars': list(CJK(m.group(2)))})
            continue
        m = re.match(r'^(\d+)\s*[：:]\s*(.+)$', l)
        if m:
            out.append({'section': section, 'kind': section or '课',
                        'label': m.group(1), 'chars': list(CJK(m.group(2)))})
            continue
    return out


def ends_of(book):
    return MANUAL_UNIT_ENDS.get(book)


def group_units(lessons, book=None):
    """返回 [(unitNo, [lesson, ...]), ...]
       有「语文园地」的册：园地是单元收口，归入它所在的单元，单元号按出现顺序编。
       5上/5下：没有园地行，用目录页核对出来的 (末课序号, 真实单元号) 切。"""
    ends = MANUAL_UNIT_ENDS.get(book) if book else None
    units, cur, idx, n = [], [], 0, 0
    for ls in lessons:
        cur.append(ls)
        idx += 1
        if ends:
            hit = [un for (e, un) in ends if e == idx]
            if hit:
                n = hit[0]
                units.append((n, cur))
                cur = []
        elif ls['kind'] == '园地':
            n += 1
            units.append((n, cur))
            cur = []
    if cur:
        n += 1
        units.append((n, cur))     # 末尾残余单独成单元
    return units


def main():
    write = '--write' in sys.argv
    curr = load_curriculum()
    gc = load_gamechars()
    curr_chars = {}
    for b in curr['books']:
        seen = {}
        for o in b['chars']:
            seen[o['c']] = 1
        curr_chars[b['book']] = set(seen)

    books_out, report = [], []
    for book in BOOK_ORDER:
        lessons = parse_book(book)
        if not lessons:
            report.append((book, None, None, None, '原始文件缺失'))
            continue
        units = group_units(lessons, book)
        total = sum(len(l['chars']) for l in lessons)
        uniq = set(c for l in lessons for c in l['chars'])
        # 交叉核对
        cs = curr_chars.get(book, set())
        inter = uniq & cs
        onlyg = uniq - cs
        onlyc = cs - uniq
        playable = sum(1 for c in uniq if c in gc)

        report.append((book, len(lessons), len(units), len(uniq),
                       '原始 %d 篇 / 单元 %d 个 / 不重复字 %d' % (len(lessons), len(units), len(uniq))))

        books_out.append({
            'book': book,
            'grade': book[0],
            'verified': True,
            'source': 'https://m.cngwzj.com/gushi/KeWen/',
            'note': '识字表（会认字），按课文顺序，单元按「语文园地」收口切分',
            'stats': {
                'lessons': len(lessons), 'units': len(units),
                'uniq_chars': len(uniq), 'playable': playable,
                'overlap_curriculum': len(inter),
                'only_in_gushi': len(onlyg), 'only_in_curriculum': len(onlyc),
            },
            'units': [{
                'unit': un,
                'name': '第 %d 单元' % un,
                'verified': True,
                'note': '%s（到「%s」为止）' % (
                    ('第 %d 单元' % un) if not ends_of(book) else '第 %d 单元（按电子课本目录核对）' % un,
                    u[-1]['label']),
                'lessons': [{'label': l['label'], 'kind': l['kind'], 'chars': l['chars']} for l in u],
                'chars': [c for l in u for c in l['chars']],
            } for (un, u) in units],
        })

    print('%-5s %-10s %s' % ('册', '不重复字', '结构'))
    print('-' * 76)
    for book, nl, nu, nch, msg in report:
        plays = ''
        if nl:
            b = next(x for x in books_out if x['book'] == book)
            plays = '  可玩 %d' % b['stats']['playable']
        print('%-5s %-10s %s%s' % (book, nch if nch else '-', msg, plays))

    print('')
    print('=== 每册单元规模（决定一关多长）===')
    for b in books_out:
        sizes = [len(u['chars']) for u in b['units']]
        acts = [len(u['lessons']) for u in b['units']]
        print('  %s  %d 个单元  单元字数: %s  每单元幕数: %s' % (b['book'], len(b['units']), sizes, acts))

    print('')
    print('=== 幕（= 一课）规模：这才是孩子一次能玩完的长度 ===')
    all_acts = []
    for b in books_out:
        for u in b['units']:
            for l in u['lessons']:
                all_acts.append(len(l['chars']))
    if all_acts:
        import collections
        buckets = collections.Counter()
        for n in all_acts:
            if n <= 3: buckets['1-3 字'] += 1
            elif n <= 6: buckets['4-6 字'] += 1
            elif n <= 10: buckets['7-10 字'] += 1
            elif n <= 15: buckets['11-15 字'] += 1
            else: buckets['16+ 字'] += 1
        print('  共 %d 幕，长度分布: %s' % (len(all_acts), dict(buckets)))
        print('  最短 %d 字，最长 %d 字，平均 %.1f 字' %
              (min(all_acts), max(all_acts), sum(all_acts) / len(all_acts)))

    print('')
    print('=== 和 data/curriculum.js 交叉核对 ===')
    for b in books_out:
        s = b['stats']
        print('  %s  识字表 %3d 字 | 与现有字表重合 %3d | 只在识字表 %3d | 只在现有字表 %3d | 游戏中可玩 %3d'
              % (b['book'], s['uniq_chars'], s['overlap_curriculum'],
                 s['only_in_gushi'], s['only_in_curriculum'], s['playable']))

    if write:
        body = json.dumps({'source': '古文之家 按课生字表（识字表）',
                           'generated': 'tools/wordlist-pipeline/gen-units.py',
                           'note': '6上/6下 该来源未收录，未包含在内',
                           'books': books_out}, ensure_ascii=False, indent=0)
        out = os.path.join(APP, 'data', 'units.js')
        io.open(out, 'w', encoding='utf-8').write(
            '/* 自动生成，勿手改。生成器：tools/wordlist-pipeline/gen-units.py */\n'
            'window.UNITS = ' + body + ';\n')
        print('')
        print('已写出 data/units.js（%d 册）' % len(books_out))
    else:
        print('')
        print('（未写文件，加 --write 才会写）')


main()
