# -*- coding: utf-8 -*-
"""用 IDS 部件重建字族（严格校验版）-> data/families.js
要点：
  1. parts 来自 cjkvi-ids 的 IDS，取「直接部件」（如 江 -> 氵+工、想 -> 相+心）。
  2. 一个字只有在其**真实部件**里出现该部首（含变形）时，才允许进这个族。
     这一步把「字典部首 ≠ 孩子看得出的部件」的伪族挡掉（才、来… 自动出局）。
  3. 记录 sound（非部首的另一部件）= 声符，为后续「声符族」铺路。
"""
import os, io, re, json
from collections import OrderedDict, Counter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

# ---- 载荷 ----
payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))

# ---- IDS ----
OPEN = set('⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻⿼⿽⿾⿿')
idsmap = {}
for ln in open(os.path.join(CACHE, 'ids.txt'), encoding='utf-8', errors='replace'):
    if ln.startswith('#'):
        continue
    f = ln.rstrip('\n').split('\t')
    if len(f) >= 3 and len(f[1]) == 1 and f[2]:
        idsmap[f[1]] = f[2]

CJK = re.compile(r'^[\u3400-\u9fff]$')
def parts_of(c):
    s = idsmap.get(c)
    if not s or s == c:
        return []
    return [x for x in s if x not in OPEN and CJK.match(x)]

# ---- 部首变形归一 ----
VARIANTS = {'水': '氵', '氺': '氵', '手': '扌', '艸': '艹', '⺿': '艹', '人': '亻',
            '言': '讠', '訁': '讠', '㣺': '忄', '心': '忄', '糸': '纟', '糹': '纟',
            '辵': '辶', '金': '钅', '釒': '钅', '灬': '火', '刀': '刂', '貝': '贝',
            '頁': '页', '玉': '王', '犬': '犭', '食': '饣', '飠': '饣', '衣': '衤',
            '示': '礻', '馬': '马', '鳥': '鸟', '魚': '鱼', '門': '门', '車': '车',
            '⺮': '竹', '見': '见', '肉': '月'}
def canon(x):
    return VARIANTS.get(x, x)

MEAN = {
    '氵': ('水', '「氵」是水的变形——和水有关'), '扌': ('手', '「扌」是手的变形——表示手上的动作'),
    '木': ('木', '「木」表示和树木有关'), '艹': ('艹', '「艹」是草的变形——和花草有关'),
    '口': ('口', '表示和嘴巴、说话、声音有关'), '亻': ('人', '「亻」是人的变形——和人有关'),
    '讠': ('言', '「讠」是言的变形——和说话有关'), '忄': ('心', '「忄」是心的变形——和心情、想法有关'),
    '纟': ('丝', '「纟」是丝的变形——和丝线、纺织有关'), '辶': ('走', '「辶」表示和走路、移动有关'),
    '土': ('土', '表示和泥土、土地有关'), '日': ('日', '表示和太阳、时间有关'),
    '女': ('女', '表示和女子有关'), '虫': ('虫', '表示和虫子有关'),
    '钅': ('金', '「钅」是金的变形——和金属有关'), '火': ('火', '表示和火有关'),
    '宀': ('宀', '「宀」表示和房屋有关'), '竹': ('竹', '表示和竹子有关'),
    '目': ('目', '表示和眼睛、看有关'), '足': ('足', '表示和脚、走路有关'),
    '刂': ('刀', '「刂」是刀的变形——和刀、切割有关'), '禾': ('禾', '表示和庄稼有关'),
    '贝': ('贝', '古时用贝壳当钱——「贝」和钱财有关'), '石': ('石', '表示和石头有关'),
    '王': ('玉', '「王」是玉的变形——和玉石有关'), '页': ('页', '「页」表示和头有关'),
    '山': ('山', '表示和山有关'), '犭': ('犬', '「犭」是犬（狗）的变形——和野兽有关'),
    '饣': ('食', '「饣」是食的变形——和吃有关'), '疒': ('病', '「疒」表示和生病有关'),
    '衤': ('衣', '「衤」是衣的变形——和衣服有关'), '礻': ('示', '「礻」是示的变形——和祭祀、求福有关'),
    '马': ('马', '表示和马有关'), '鸟': ('鸟', '表示和鸟有关'), '鱼': ('鱼', '表示和鱼有关'),
    '门': ('门', '表示和门有关'), '雨': ('雨', '表示和天气有关'), '耳': ('耳', '表示和耳朵、听有关'),
    '车': ('车', '表示和车有关'), '舟': ('舟', '表示和船有关'), '米': ('米', '表示和米、粮食有关'),
    '彳': ('彳', '「彳」和行走、道路有关'), '走': ('走', '表示和跑、走有关'),
    '穴': ('穴', '表示和洞穴有关'), '广': ('广', '表示和房屋有关'), '户': ('户', '表示和门户、房屋有关'),
    '皿': ('皿', '表示和器皿有关'), '弓': ('弓', '表示和弓、射箭有关'), '矢': ('矢', '表示和箭有关'),
    '戈': ('戈', '表示和兵器有关'), '斤': ('斤', '表示和斧头有关'), '齿': ('齿', '表示和牙齿有关'),
    '舌': ('舌', '表示和舌头、味道有关'), '皮': ('皮', '表示和皮肤有关'), '骨': ('骨', '表示和骨头有关'),
    '毛': ('毛', '表示和毛发有关'), '羽': ('羽', '表示和羽毛、鸟有关'), '角': ('角', '表示和角有关'),
    '酉': ('酉', '表示和酒、发酵有关'), '鹿': ('鹿', '表示和鹿有关'), '鼠': ('鼠', '表示和鼠有关'),
    '黑': ('黑', '表示和黑色有关'), '白': ('白', '表示和白色、明亮有关'), '青': ('青', '表示和青色有关'),
    '赤': ('赤', '表示和红色有关'), '黄': ('黄', '表示和黄色有关'), '甘': ('甘', '表示和甜、美味有关'),
    '辛': ('辛', '表示和辛辣、辛苦有关'), '风': ('风', '表示和风有关'), '冫': ('冰', '「冫」是冰的变形——和寒冷有关'),
    '尸': ('尸', '「尸」多表示和身体、房屋有关'), '立': ('立', '表示和站立有关'),
    '见': ('见', '表示和看有关'), '身': ('身', '表示和身体有关'), '手': ('手', '表示和手有关'),
    '犬': ('犬', '表示和狗有关'), '食': ('食', '表示和吃有关'), '衣': ('衣', '表示和衣服有关'),
    '言': ('言', '表示和说话有关'), '金': ('金', '表示和金属有关'), '刀': ('刀', '表示和刀有关'),
}
EXCLUDED = {'月': '「月」形兼作 月亮 / 肉（身体），字形相同无法自动分辨，需人工拆族后启用'}

CAP, MIN = 12, 2
old_rad = json.load(open(os.path.join(CACHE, 'radicals.json'), encoding='utf-8'))
seen = set()
agg, skipped, no_ids = OrderedDict(), Counter(), []
for b in payload['books']:
    for d in b['chars']:
        c = d['c']
        if c in seen:
            continue
        seen.add(c)
        ps = parts_of(c)
        if not ps:
            # 拆不开的字：若它本身就是部首（口/目/日/虫/女…），作为族根收入
            rc = canon(c)
            if rc in MEAN and rc not in EXCLUDED:
                agg.setdefault(rc, OrderedDict()).setdefault(b['grade'], []).append(
                    {'c': c, 'py': d['py'], 'parts': [c], 'sound': None, 'isRoot': True})
            else:
                no_ids.append(c)
                skipped['无可拆解且非部首(圆体字)'] += 1
            continue
        cs = [canon(x) for x in ps]
        drad = canon(old_rad.get(c, {}).get('radical', ''))
        # 双条件：字典部首就是该族，且该部首确实出现在可视部件里（否则是伪族）
        if drad in EXCLUDED:
            skipped['整族排除(月/肉)'] += 1
            continue
        if drad not in MEAN:
            skipped['部首无人工讲解(含笔画类)'] += 1
            continue
        if drad not in cs:
            skipped['部首不在可视部件中(伪族,已剔除)'] += 1
            continue
        r = drad
        sound = ''.join(x for x, k in zip(ps, cs) if k != r) or None
        agg.setdefault(r, OrderedDict()).setdefault(b['grade'], []).append(
            {'c': c, 'py': d['py'], 'parts': ps, 'sound': sound})

families = []
for r, byg in agg.items():
    zh, mean = MEAN[r]
    for g, items in byg.items():
        chunks = [items[i:i + CAP] for i in range(0, len(items), CAP)]
        if len(chunks) > 1 and len(chunks[-1]) < MIN:
            chunks[-2] += chunks[-1]; chunks.pop()
        for k, ch in enumerate(chunks):
            if len(ch) < MIN:
                continue
            families.append({'id': r + str(g) + (chr(97 + k) if k else ''),
                             'radical': r, 'radicalReading': zh, 'meaning': mean,
                             'grade': g, 'chars': ch})
families.sort(key=lambda f: (f['grade'], -len(f['chars'])))

# ---- 声符族：同一个声符带出多个字（「青之家族」那种）----
# 先按读音相似度过滤，否则「又」族会混进 鸡观戏汉 这种毫不相干的字。
TONE_MAP = {'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', 'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
            'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', 'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
            'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v',
            'ü': 'v', 'ń': 'n', 'ň': 'n', 'ǹ': 'n'}
INITIALS = ['zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h',
            'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w']
APICAL = {'zh', 'ch', 'sh', 'r', 'z', 'c', 's'}

def py_base(py):
    return ''.join(TONE_MAP.get(ch, ch) for ch in py).lower()

def py_final(py):
    b = py_base(py)
    for i in INITIALS:
        if b.startswith(i):
            f = b[len(i):]
            if f == 'i' and i in APICAL:
                return 'i0'
            return f
    return b

def tier(target, cand):
    if not target or not cand:
        return 0
    if py_base(target) == py_base(cand):
        return 3
    ft, fc = py_final(target), py_final(cand)
    if ft == fc:
        return 2
    if ft.rstrip('g') == fc.rstrip('g'):
        return 1
    return 0

from pypinyin import lazy_pinyin, Style
py_of = {}
for b in payload['books']:
    for d in b['chars']:
        py_of.setdefault(d['c'], d['py'])
def pinyin_of(c):
    if c in py_of:
        return py_of[c]
    return ''.join(lazy_pinyin(c, style=Style.TONE))

by_sound = OrderedDict()
for f in families:
    for d in f['chars']:
        s = d.get('sound')
        if s and len(s) == 1:
            by_sound.setdefault(s, []).append({'c': d['c'], 'py': d['py'],
                                               'grade': f['grade'], 'radical': f['radical']})

sound_fams, rejected_sound = [], 0
for s, v in by_sound.items():
    if len(v) < 3:
        continue
    sp = pinyin_of(s)
    good = [d for d in v if tier(sp, d['py']) >= 1]
    if len(good) >= 3 and len(good) >= 0.7 * len(v):
        sound_fams.append({'sound': s, 'soundPy': sp, 'chars': good})
    else:
        rejected_sound += 1
sound_fams.sort(key=lambda x: -len(x['chars']))

tot_chars = len(seen)
ready = sum(len(f['chars']) for f in families)

# 对比：旧法（纯字典部首）会收进多少
old_rad = json.load(open(os.path.join(CACHE, 'radicals.json'), encoding='utf-8'))
old_cnt = sum(1 for c in seen if old_rad.get(c, {}).get('radical') in MEAN)

w('=== 严格校验后的字族 ===')
w('族数: %d   覆盖字数: %d / %d (%.1f%%)' % (len(families), ready, tot_chars, 100.0*ready/tot_chars))
w('落选统计: ' + json.dumps(dict(skipped), ensure_ascii=False))
w('无 IDS 数据的字: %d 个  %s' % (len(no_ids), ''.join(no_ids[:30])))
w('族大小分布: ' + json.dumps(sorted(Counter(len(f['chars']) for f in families).items()), ensure_ascii=False))
w()
w('=== 质量提升对照 ===')
w('旧法（字典部首，含伪族）: %d 字' % old_cnt)
w('新法（IDS 部件校验）  : %d 字   -> 剔除了 %d 字的伪族归属' % (ready, old_cnt - ready))
w()
w('=== 伪族被剔除的例子（字典说有，实际部件里没有）===')
for c in '才来和古吴周喜严专丢':
    ps = parts_of(c)
    r = old_rad.get(c, {}).get('radical', '?')
    w('  %s  字典部首=%-2s  实际部件=%s  %s' % (c, r, ''.join(ps) or '(拆不开)',
      '-> 已剔除' if canon(r) not in [canon(x) for x in ps] else '-> 保留'))
w()
w('=== 抽样：检查 parts 质量 ===')
shown = 0
for f in families:
    for d in f['chars']:
        if len(d['parts']) == 2 and shown < 14:
            w('  %s = %s + %s   (%s)   声符=%s' % (d['c'], d['parts'][0], d['parts'][1], d['py'], d['sound']))
            shown += 1
w()
w('=== 声符族（同一声符带出 ≥3 字，且读音相近）===')
w('通过: %d 个   因读音不符被剔除: %d 个' % (len(sound_fams), rejected_sound))
for sf in sound_fams[:20]:
    w('  声符「%s」(%s) %2d字  %s' % (sf['sound'], sf['soundPy'], len(sf['chars']),
      ' '.join('%s(%s)' % (d['c'], d['py']) for d in sf['chars'])))
w()
w('=== 各年级 ===')
for g in range(1, 7):
    fs = [f for f in families if f['grade'] == g]
    w('  %d 年级: %2d 族  %4d 字' % (g, len(fs), sum(len(f['chars']) for f in fs)))

open(os.path.join(APP, 'data', 'families.js'), 'w', encoding='utf-8').write(
    'window.FAMILIES = ' + json.dumps({
        'version': 2,
        'edition': '部编版/统编版 小学语文识字表',
        'derived': 'curriculum.js + IDS部件(cjkvi-ids) + 人工部首讲解',
        'note': '每字含 字/拼音/年级/部件(parts)/声符(sound)/是否族根(isRoot)；每族含 部首/讲解。场景、图、题目待补。',
        'families': families,
        'soundFamilies': sound_fams,
    }, ensure_ascii=False) + ';\n')
w()
w('输出 data/families.js  %d bytes' % os.path.getsize(os.path.join(APP, 'data', 'families.js')))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
