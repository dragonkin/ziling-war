# -*- coding: utf-8 -*-
"""按 (部首 × 年级) 聚成可玩字族 -> data/families.js
规则：**只有人工写了讲解(MEAN)的部首才成为可用字族**，笔画类部首（一/丿/十/又…）自动落选。
另处理「月/肉」同形陷阱：月形部首实为「肉」的字单独列出，避免把身体部位讲成月亮。"""
import json, os, io, re
from collections import OrderedDict, Counter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

rad = json.load(open(os.path.join(CACHE, 'radicals.json'), encoding='utf-8'))
payload = json.loads(re.match(r'^window\.CURRICULUM\s*=\s*(.*);\s*$',
                    open(os.path.join(APP, 'data', 'curriculum.js'), encoding='utf-8').read(), re.S).group(1))

# 人工讲解表：部首 -> (读音, 讲解)。只有在这里的部首才成族。
MEAN = {
    '氵': ('水', '「氵」是水的变形——和水有关'), '扌': ('手', '「扌」是手的变形——表示手上的动作'),
    '木': ('木', '「木」表示和树木有关'), '艹': ('艹', '「艹」是草的变形——和花草有关'),
    '口': ('口', '表示和嘴巴、说话、声音有关'), '亻': ('人', '「亻」是人的变形——和人有关'),
    '讠': ('言', '「讠」是言的变形——和说话有关'), '忄': ('心', '「忄」是心的变形——和心情有关'),
    '心': ('心', '表示和心情、想法有关'), '纟': ('丝', '「纟」是丝的变形——和丝线、纺织有关'),
    '辶': ('走', '「辶」表示和走路、移动有关'), '土': ('土', '表示和泥土、土地有关'),
    '日': ('日', '表示和太阳、时间有关'),
    '女': ('女', '表示和女子有关'),
    '虫': ('虫', '表示和虫子有关'), '钅': ('金', '「钅」是金的变形——和金属有关'),
    '火': ('火', '表示和火有关'), '宀': ('宀', '「宀」表示和房屋有关'),
    '竹': ('竹', '表示和竹子有关'), '目': ('目', '表示和眼睛、看有关'),
    '足': ('足', '表示和脚、走路有关'), '刂': ('刀', '「刂」是刀的变形——和刀、切割有关'),
    '禾': ('禾', '表示和庄稼有关'), '贝': ('贝', '古时用贝壳当钱——「贝」和钱财有关'),
    '石': ('石', '表示和石头有关'), '王': ('玉', '「王」是玉的变形——和玉石有关'),
    '页': ('页', '「页」表示和头有关'), '山': ('山', '表示和山有关'),
    '犭': ('犬', '「犭」是犬（狗）的变形——和野兽有关'), '饣': ('食', '「饣」是食的变形——和吃有关'),
    '疒': ('病', '「疒」表示和生病有关'), '衤': ('衣', '「衤」是衣的变形——和衣服有关'),
    '礻': ('示', '「礻」是示的变形——和祭祀、求福有关'), '马': ('马', '表示和马有关'),
    '鸟': ('鸟', '表示和鸟有关'), '鱼': ('鱼', '表示和鱼有关'), '门': ('门', '表示和门有关'),
    '雨': ('雨', '表示和天气有关'), '耳': ('耳', '表示和耳朵、听有关'), '车': ('车', '表示和车有关'),
    '舟': ('舟', '表示和船有关'), '米': ('米', '表示和米、粮食有关'),
    '讠': ('言', '「讠」是言的变形——和说话有关'), '彳': ('彳', '「彳」和行走、道路有关'),
    '走': ('走', '表示和跑、走有关'), '言': ('言', '表示和说话有关'),
    '尸': ('尸', '「尸」多表示和身体、房屋有关'), '穴': ('穴', '表示和洞穴有关'),
    '广': ('广', '表示和房屋有关'), '户': ('户', '表示和门户、房屋有关'),
    '皿': ('皿', '表示和器皿有关'), '缶': ('缶', '表示和陶器有关'),
    '弓': ('弓', '表示和弓、射箭有关'), '矢': ('矢', '表示和箭有关'),
    '戈': ('戈', '表示和兵器有关'), '斤': ('斤', '表示和斧头有关'),
    '页': ('页', '「页」表示和头有关'), '齿': ('齿', '表示和牙齿有关'),
    '舌': ('舌', '表示和舌头、味道有关'), '皮': ('皮', '表示和皮肤有关'),
    '骨': ('骨', '表示和骨头有关'), '毛': ('毛', '表示和毛发有关'),
    '羽': ('羽', '表示和羽毛、鸟有关'), '角': ('角', '表示和角有关'),
    '食': ('食', '表示和吃有关'), '酉': ('酉', '表示和酒、发酵有关'),
    '麻': ('麻', '表示和麻有关'), '鹿': ('鹿', '表示和鹿有关'),
    '鼠': ('鼠', '表示和鼠有关'), '黑': ('黑', '表示和黑色有关'),
    '白': ('白', '表示和白色、明亮有关'), '青': ('青', '表示和青色有关'),
    '赤': ('赤', '表示和红色有关'), '黄': ('黄', '表示和黄色有关'),
    '甘': ('甘', '表示和甜、美味有关'), '辛': ('辛', '表示和辛辣、辛苦有关'),
    '风': ('风', '表示和风有关'), '宀': ('宀', '「宀」表示和房屋有关'),
    '灬': ('火', '「灬」是火的变形——和火有关'), '冫': ('冰', '「冫」是冰的变形——和寒冷有关'),
    '亠': ('亠', ''), '冖': ('冖', ''), '卜': ('卜', ''), '厶': ('厶', ''),
}
MEAN = {k: v for k, v in MEAN.items() if v[1]}   # 讲解为空的不算

# 已知陷阱：整族排除，等人工拆分后再启用
EXCLUDED = {
    '月': '「月」形偏旁有两个来源——月亮(月/期/朗) 与 肉·身体(肥/肯/胡/胜/腊/脱/股/育)。'
          '字形完全相同，机器难以分辨，必须先人工拆成两族再启用。',
}

# 「月」形实为「肉」(身体) 的字——避免把身体讲成月亮
BODY = set('胆脖臂肚腿脚脸胖膀腰背脑胸肝肠肌肤肋骨胳胳膊腕肘膝肩胃脏肺脾')
MOON = set('月明有朋望朝期朗服朐')

CAP, MIN = 12, 2

agg = OrderedDict()
skipped = Counter()
seen_char = set()
for b in payload['books']:
    for d in b['chars']:
        c = d['c']
        # 生字按首次教材出现归属；避免跨册重复导致同族重复
        if c in seen_char:
            continue
        seen_char.add(c)
        if c not in rad:
            skipped['无部首数据'] += 1
            continue
        r = rad[c]['radical']
        if r in EXCLUDED:
            skipped['整族排除(需人工拆分): ' + r] += 1
            continue
        if r not in MEAN:
            skipped['部首无人工讲解(含笔画类)'] += 1
            continue
        if r == '月' and c in BODY:
            r = '月(肉)'
        agg.setdefault(r, OrderedDict()).setdefault(b['grade'], []).append(
            {'c': c, 'py': d['py'], 'book': b['book']})

families = []
for r, byg in agg.items():
    base = r.replace('(肉)', '')
    zh, mean = MEAN[base]
    if r.endswith('(肉)'):
        mean = '皮肤、身体部位——这里的「月」其实是「肉」'
    for g, items in byg.items():
        chunks = [items[i:i + CAP] for i in range(0, len(items), CAP)]
        if len(chunks) > 1 and len(chunks[-1]) < MIN:
            chunks[-2] += chunks[-1]; chunks.pop()
        for k, ch in enumerate(chunks):
            if len(ch) < MIN:
                continue
            families.append({
                'id': r.replace('(肉)', '-rou') + str(g) + (chr(97 + k) if k else ''),
                'radical': r, 'radicalReading': zh, 'meaning': mean,
                'grade': g, 'chars': ch,
            })

families.sort(key=lambda f: (f['grade'], -len(f['chars'])))
ready_chars = sum(len(f['chars']) for f in families)

w('=== 结果（只保留有讲解的部首）===')
w('可用字族: %d 个' % len(families))
w('覆盖字数: %d / %d' % (ready_chars, sum(len(b['chars']) for b in payload['books'])))
w('落选原因统计: ' + json.dumps(dict(skipped), ensure_ascii=False))
w('族大小分布: ' + json.dumps(sorted(Counter(len(f['chars']) for f in families).items()), ensure_ascii=False))
w()
w('=== 各年级 ===')
for g in range(1, 7):
    fs = [f for f in families if f['grade'] == g]
    w('  %d 年级: %2d 族  %4d 字' % (g, len(fs), sum(len(f['chars']) for f in fs)))
w()
w('=== 各年级字族示例 ===')
for g in range(1, 7):
    w('-- %d 年级 --' % g)
    for f in [f for f in families if f['grade'] == g][:14]:
        w('   %-3s %2d字  %s' % (f['radical'], len(f['chars']),
          ''.join(d['c'] for d in f['chars'])[:26]))
w()
w('=== 月/肉 拆分检查 ===')
for f in families:
    if f['radical'] in ('月', '月(肉)'):
        w('   %-6s g%d  %s' % (f['radical'], f['grade'], ''.join(d['c'] for d in f['chars'])))

open(os.path.join(APP, 'data', 'families.js'), 'w', encoding='utf-8').write(
    'window.FAMILIES = ' + json.dumps({
        'version': 1,
        'edition': '部编版/统编版 小学语文识字表',
        'derived': 'curriculum.js + 部首数据(chinese-xinhua) + 人工讲解表',
        'note': '草稿：每字含 字/拼音/年级；每族含 部首/讲解。场景、图、题目待补。',
        'families': families,
    }, ensure_ascii=False) + ';\n')
w()
w('输出 data/families.js  %d bytes' % os.path.getsize(os.path.join(APP, 'data', 'families.js')))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
