# -*- coding: utf-8 -*-
"""给游戏用的全量字表：把教材 3209 个字全部补上部件。
   之前 data/expand.js 只覆盖了 1825 个字（能拆成两个部件的），
   剩下 1068 个独体字（天我一二三四五上下耳足月水火石田禾云雨风鸟…）
   恰恰是一年级最核心的字，游戏里必须能玩到。
   独体字拆不出两个部件 → 按「单部件」处理（妖怪直接掉整个字）。

   输出 data/gamechars.js：
     window.GAMECHARS = { "江": {py, rad, emoji, parts:["氵","工"]}, "天": {...parts:["天"]} }
"""
import os, re, io, json

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))   # tools/wordlist-pipeline -> 项目根
CACHE = os.path.join(HERE, 'cache')

def load_js(path, varname):
    """从 window.X = {...}; 里把 JSON 抠出来"""
    s = io.open(path, encoding='utf-8').read()
    i = s.index('{')
    j = s.rindex('}')
    return json.loads(s[i:j + 1])

CURR = load_js(os.path.join(APP, 'data', 'curriculum.js'), 'CURRICULUM')
FAMS = load_js(os.path.join(APP, 'data', 'families.js'), 'FAMILIES')
RAD = json.load(io.open(os.path.join(CACHE, 'radicals.json'), encoding='utf-8'))
UNITS = load_js(os.path.join(APP, 'data', 'units.js'), 'UNITS')

# 整册字表（curriculum）不含「语文园地」里那些字（驻钞培赌媒氛账贺樟杠狡猾 之类），
# 但它们是真教材的单元生字，单元关卡里会出现。少了它们，那一幕会被整个丢掉。
# 所以这里把单元数据里出现、整册字表没收录的字补进来，拼音用 pypinyin 现生成。
_CURR_C = set(o['c'] for bk in CURR['books'] for o in bk['chars'])
EXTRA, _seen_e = [], set()
for _b in UNITS['books']:
    for _u in _b['units']:
        for _ls in _u['lessons']:
            for _ch in _ls['chars']:
                if _ch not in _CURR_C and _ch not in _seen_e:
                    _seen_e.add(_ch)
                    EXTRA.append(_ch)
PYM = {}
if EXTRA:
    from pypinyin import pinyin, Style
    PYM = {ch: ''.join(x[0] for x in pinyin(ch, style=Style.TONE)) for ch in EXTRA}
    print('补充「语文园地」等单元生字 %d 个（整册字表未收录）' % len(EXTRA))
    print('  ', ''.join(EXTRA))
ALLBOOKS = list(CURR['books']) + [{'chars': [{'c': ch, 'py': PYM.get(ch, '')} for ch in EXTRA]}]

# 部首 -> 配图（与 _expand.py 同一套，游戏里保持一致）
FEMOJI = {
    '氵': '💧', '扌': '✋', '木': '🌳', '艹': '🌿', '口': '👄', '亻': '🧍', '讠': '💬',
    '忄': '💗', '纟': '🧵', '辶': '🚶', '土': '🟫', '日': '☀️', '女': '👧', '虫': '🐛',
    '钅': '🔧', '火': '🔥', '宀': '🏠', '竹': '🎋', '目': '👁️', '足': '🦶', '刂': '🔪',
    '禾': '🌾', '贝': '🐚', '石': '🪨', '王': '💎', '页': '🗣️', '山': '⛰️', '犭': '🐕',
    '饣': '🍚', '疒': '🤒', '衤': '👕', '礻': '⛩️', '马': '🐴', '鸟': '🐦', '鱼': '🐟',
    '门': '🚪', '雨': '🌧️', '耳': '👂', '车': '🚗', '舟': '⛵', '米': '🍚',
    '彳': '🚶', '走': '🏃', '穴': '🕳️', '广': '🏠', '户': '🚪', '皿': '🍽️', '弓': '🏹',
    '矢': '🏹', '戈': '⚔️', '斤': '🪓', '齿': '🦷', '舌': '👅', '皮': '🖐️', '骨': '🦴',
    '毛': '🧶', '羽': '🪶', '角': '🦄', '酉': '🍶', '鹿': '🦌', '鼠': '🐭', '黑': '⬛',
    '白': '⬜', '青': '🟦', '赤': '🟥', '黄': '🟨', '甘': '🍯', '辛': '🌶️', '风': '🌬️',
    '冫': '❄️', '尸': '🏚️', '立': '🧍', '见': '👀', '身': '🧍', '手': '✋', '犬': '🐕',
    '食': '🍚', '衣': '👕', '言': '💬', '金': '🔧', '刀': '🔪',
    '人': '🧍', '大': '🧍', '小': '🔹', '一': '➖', '二': '🟰', '三': '☰', '十': '➕',
    '八': '✳️', '儿': '🧒', '入': '↩️', '力': '💪', '又': '🔁', '匕': '🥄', '匚': '📦',
    '卜': '🔮', '厂': '🏭', '厶': '🌀', '囗': '⬜', '寸': '📏', '工': '🔨', '己': '🧭',
    '巾': '🧣', '干': '🪵', '弋': '🎯', '幺': '➰', '廴': '➰', '心': '❤️', '户': '🚪',
    '毋': '🚫', '气': '💨', '爪': '🐾', '父': '👨', '爻': '✖️', '爿': '🪵', '片': '🪵',
    '牛': '🐮', '犬': '🐕', '玄': '⚫', '瓦': '🏺', '田': '🌾', '疋': '🦶', '癶': '🚶',
    '皿': '🍽️', '矛': '🔱', '矢': '🏹', '秉': '🌾', '耒': '🌾', '聿': '✍️', '艮': '⛰️',
    '色': '🎨', '虍': '🐯', '血': '🩸', '行': '🚶', '襾': '🧺', '齐': '📐', '龙': '🐉',
    '龟': '🐢', '龠': '🎵', '鼓': '🥁', '黍': '🌾', '黾': '🐸', '鼎': '🍲', '非': '❌',
    '面': '😐', '革': '🟫', '韦': '🟫', '音': '🎵', '韭': '🌿', '页': '🗣️', '首': '🗣️',
    '香': '🌸', '高': '⬆️', '鬲': '🍲', '鬼': '👻', '麻': '🌿', '鸟': '🐦', '鱼': '🐟',
}
DEFAULT_EMOJI = '🔷'

# IDS 分解
idsmap = {}
for ln in io.open(os.path.join(CACHE, 'ids.txt'), encoding='utf-8', errors='replace'):
    if ln.startswith('#'):
        continue
    f = ln.rstrip('\n').split('\t')
    if len(f) >= 3 and len(f[1]) == 1 and f[2]:
        idsmap[f[1]] = f[2]

VAR = {'水': '氵', '氺': '氵', '手': '扌', '艸': '艹', '⺿': '艹', '人': '亻', '言': '讠',
       '訁': '讠', '心': '忄', '㣺': '忄', '糸': '纟', '糹': '纟', '辵': '辶', '金': '钅',
       '釒': '钅', '灬': '火', '刀': '刂', '貝': '贝', '頁': '页', '玉': '王', '犬': '犭',
       '食': '饣', '飠': '饣', '衣': '衤', '示': '礻', '馬': '马', '鳥': '鸟', '魚': '鱼',
       '門': '门', '車': '车', '⺮': '竹', '見': '见', '肉': '月'}
def canon(x):
    return VAR.get(x, x)

def ids_two(ch):
    """IDS 里正好两个部件时返回它们（list）；否则 None。
       注意：Python 里 d[1:] 切字符串得到的是字符串，必须显式 list()，
       否则 parts 会写成 "亻呆" 这种字符串，游戏里 x.parts.join 直接报错。"""
    d = idsmap.get(ch)
    if not d:
        return None
    ops = set('⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻')
    parts = list(d[1:])
    if len(parts) != 2:
        return None
    if any(p in ops for p in parts):
        return None
    return parts

# 字族数据里的部件（质量最高，优先用）
FAMPARTS = {}
FAMNAME = {}
for f in FAMS['families']:
    for c in f['chars']:
        if c['c'] in FAMPARTS:
            continue
        FAMPARTS[c['c']] = c.get('parts') or []
        FAMNAME[c['c']] = f.get('meaning') or ''

out = {}
stat = {'族部件': 0, 'IDS两部件': 0, '单部件(独体)': 0, 'IDS三部件以上': 0}
missing_py = 0

for bk in ALLBOOKS:
    for o in bk['chars']:
        ch = o['c']
        if ch in out:
            continue
        py = o.get('py') or ''
        if not py:
            missing_py += 1
        rad = (RAD.get(ch) or {}).get('radical') or ''
        parts = FAMPARTS.get(ch) or []
        if len(parts) == 2:
            stat['族部件'] += 1
        else:
            two = ids_two(ch)
            if two:
                # 义符（= 部首）放前面，和 expand.js 的口径一致
                c0, c1 = canon(two[0]), canon(two[1])
                rc = canon(rad)
                if c1 == rc and c0 != rc:
                    parts = [two[1], two[0]]
                else:
                    parts = [two[0], two[1]]
                stat['IDS两部件'] += 1
            else:
                d = idsmap.get(ch)
                if d and len(d) > 3:
                    stat['IDS三部件以上'] += 1
                else:
                    stat['单部件(独体)'] += 1
                parts = [ch]
        emoji = FEMOJI.get(rad) or FEMOJI.get(canon(rad)) or DEFAULT_EMOJI
        if len(parts) == 1:
            emoji = FEMOJI.get(rad) or FEMOJI.get(canon(rad)) or DEFAULT_EMOJI
        out[ch] = {'py': py, 'rad': rad, 'emoji': emoji, 'parts': parts,
                   'fam': FAMNAME.get(ch, '')}

lines = []
for ch, v in out.items():
    lines.append(json.dumps(ch, ensure_ascii=False) + ':' + json.dumps(v, ensure_ascii=False, separators=(',', ':')))
body = '{\n' + ',\n'.join(lines) + '\n}'
io.open(os.path.join(APP, 'data', 'gamechars.js'), 'w', encoding='utf-8').write(
    '/* 自动生成，勿手改。生成器：tools/wordlist-pipeline/gen-gamechars.py */\n'
    'window.GAMECHARS = ' + body + ';\n')

n1 = sum(1 for v in out.values() if len(v['parts']) == 1)
n2 = sum(1 for v in out.values() if len(v['parts']) == 2)
print('全量字表已生成 data/gamechars.js')
print('  总字数     :', len(out))
print('  两部件(可拼):', n2)
print('  单部件(独体):', n1)
print('  缺拼音     :', missing_py)
print('  来源分布   :', stat)
print('')
print('  一年级上册抽样（之前完全玩不到的独体字）:')
row = []
for o in CURR['books'][0]['chars'][:24]:
    ch = o['c']
    v = out[ch]
    row.append('%s(%s%s)' % (ch, v['py'], '·独' if len(v['parts']) == 1 else '·拼'))
print('   ', ' '.join(row))

# ---- 自检：写出去的东西必须是游戏能直接用的 ----
bad, dup = [], []
for ch, v in out.items():
    p = v['parts']
    if not isinstance(p, list):
        bad.append('%s parts 不是 list: %r' % (ch, p))
        continue
    if len(p) not in (1, 2):
        bad.append('%s 部件数 %d' % (ch, len(p)))
    if len(p) == 2 and p[0] == p[1]:
        dup.append(ch)   # 品字结构（林=木+木），是真实构字规律，不算错，只统计
    if not v['py']:
        bad.append('%s 缺拼音' % ch)
print('')
if bad:
    print('!!! 自检不通过，%d 个问题：' % len(bad))
    for b in bad[:20]:
        print('   ', b)
    raise SystemExit(1)
print('自检通过：%d 个字，parts 全是 1~2 个元素的 list，无缺拼音' % len(out))
print('  其中品字结构（两个部件相同，如 林=木+木）%d 个：%s' % (len(dup), ' '.join(dup)))

