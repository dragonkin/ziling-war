# -*- coding: utf-8 -*-
"""把自动生成的字族/题目，转成应用所需的完整字对象 -> data/expand.js
应用的质检函数要求每个字必须有 scene / emoji / notes / parts / q3 / q4，本脚本全部自动产出：
  scene  : 「<组词>的<字>。」——配合 app 的 speak(字。scene) 读出来是「江。长江的江。」
  emoji  : 按部首给的族级配图
  notes  : [部件讲解, 声符提示]；声符韵母相符才说「提示读音」，否则说「帮它记住字形」
           （这条是本应用的红线，绝不能把「工」和「江」的读音挂上钩）
  q3     : 「X 属于哪一家？」三选一，选项是【该族的 emoji + 部首】
  q4     : 复用已生成的组词题
"""
import os, io, json, re, random
from collections import defaultdict, Counter
from pypinyin import lazy_pinyin, Style

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(HERE, 'cache')
out = io.StringIO()
def w(s=''):
    out.write(str(s) + '\n')

FAMS = json.loads(re.match(r'^window\.FAMILIES\s*=\s*(.*);\s*$',
               open(os.path.join(APP, 'data', 'families.js'), encoding='utf-8').read(), re.S).group(1))
QS = json.loads(re.match(r'^window\.QUESTIONS\s*=\s*(.*);\s*$',
             open(os.path.join(APP, 'data', 'questions.js'), encoding='utf-8').read(), re.S).group(1))
QBY = {q['c']: q for q in QS['items']}

# IDS（取方位符号）
OPEN = set('⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻⿼⿽⿾⿿')
idsmap = {}
for ln in open(os.path.join(CACHE, 'ids.txt'), encoding='utf-8', errors='replace'):
    if ln.startswith('#'):
        continue
    f = ln.rstrip('\n').split('\t')
    if len(f) >= 3 and len(f[1]) == 1 and f[2]:
        idsmap[f[1]] = f[2]

# 部首 -> 族级 emoji
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
}
def emoji_of(r):
    return FEMOJI_GET(r) if False else FEMOJI.get(r)

def op_of(ids):
    for ch in ids:
        if ch in '⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻':
            return ch
    return ''

# IDS 运算符 -> (第0个部件的位置说法, 第1个部件的位置说法)
POSWORDS = {
    '⿰': ('左边', '右边'), '⿱': ('上面', '下面'), '⿲': ('左边', '中间'),
    '⿳': ('上面', '中间'), '⿴': ('外面', '里面'), '⿵': ('外面', '里面'),
    '⿶': ('外面', '里面'), '⿷': ('外面', '里面'), '⿸': ('左上', '右下'),
    '⿹': ('右上', '左下'), '⿺': ('左下', '右上'),
}

# 拼音工具
TONE_MAP = {'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', 'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
            'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', 'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
            'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', 'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v',
            'ü': 'v', 'ń': 'n', 'ň': 'n', 'ǹ': 'n'}
INITIALS = ['zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h',
            'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w']
APICAL = {'zh', 'ch', 'sh', 'r', 'z', 'c', 's'}
def pb(py):
    return ''.join(TONE_MAP.get(ch, ch) for ch in py).lower()
def pf(py):
    b = pb(py)
    for i in INITIALS:
        if b.startswith(i):
            f = b[len(i):]
            return 'i0' if (f == 'i' and i in APICAL) else f
    return b
def rime_same(a, b):
    return bool(a) and bool(b) and pf(a) == pf(b)

# 声符不一定是教材生字；教材拼音优先，查不到时用 pypinyin 补齐。
PART_PY_CACHE = {}
def part_py(ch):
    if ch not in PART_PY_CACHE:
        PART_PY_CACHE[ch] = QBY.get(ch, {}).get('py') or ''.join(lazy_pinyin(ch, style=Style.TONE))
    return PART_PY_CACHE[ch]

# ---- 生成 ----
fam_emoji_used = {}
expand, skipped = [], defaultdict(int)
for f in FAMS['families']:
    r = f['radical']
    em = emoji_of(r)
    if not em:
        skipped['该部首没有族级配图'] += len(f['chars']); continue
    chars = []
    for d in f['chars']:
        c, py = d['c'], d['py']
        q = QBY.get(c)
        if not q or 'qWord' not in q:
            skipped['没有组词题'] += 1; continue
        if d.get('isRoot'):
            if not d.get('parts'):
                skipped['根字无 parts'] += 1; continue
            ch = {'c': c, 'py': py, 'emoji': em, 'isRoot': True,
                  'parts': [c],
                  'scene': (q['words'][0] + '的' + c + '。') if q.get('words') else (c + '。'),
                  'notes': [f['meaning']],
                  'q3': None, 'q4': None}
        else:
            ps = d.get('parts') or []
            if len(ps) != 2:
                skipped['部件数不是2（应用质检要求）'] += 1; continue
            # 义符必须是本族部首；IDS 的视觉顺序不一定把义符放在前面。
            raw0, raw1 = ps[0], ps[1]
            canon0, canon1 = raw0, raw1
            # 与 families2.py 同口径的部首变形归一
            VAR = {'水':'氵','氺':'氵','手':'扌','艸':'艹','⺿':'艹','人':'亻',
                   '言':'讠','訁':'讠','㣺':'忄','心':'忄','糸':'纟','糹':'纟',
                   '辵':'辶','金':'钅','釒':'钅','灬':'火','刀':'刂','貝':'贝',
                   '頁':'页','玉':'王','犬':'犭','食':'饣','飠':'饣','衣':'衤',
                   '示':'礻','馬':'马','鳥':'鸟','魚':'鱼','門':'门','車':'车',
                   '⺮':'竹','見':'见','肉':'月'}
            canon0, canon1 = VAR.get(raw0, raw0), VAR.get(raw1, raw1)
            rad_pos = 0 if canon0 == r else 1
            yi, sheng = (raw0, raw1) if rad_pos == 0 else (raw1, raw0)
            op = op_of(idsmap.get(c, ''))
            pair = POSWORDS.get(op)
            yi_pos = pair[rad_pos] if pair else ''
            n1 = (yi_pos + '「' + yi + '」表示意思') if yi_pos else ('「' + yi + '」表示意思')
            # 声符韵母相符才敢说「提示读音」（红线）
            sp = part_py(sheng)
            if sp and rime_same(sp, py):
                n2 = '「' + sheng + '」在这儿提示读音'
            else:
                n2 = '「' + sheng + '」帮它记住字形'
            word = q['words'][0]
            ch = {'c': c, 'py': py, 'emoji': em, 'parts': [yi, sheng],
                  'scene': word + '的' + c + '。',
                  'notes': [n1, n2], 'q3': None, 'q4': None}
        chars.append(ch)
    if len(chars) < 2:
        skipped['成族后不足2字'] += len(chars); continue
    rd = f.get('radicalReading') or r
    nm = rd + '之族' if rd == r else rd + '之族(' + r + ')'
    expand.append({'id': 'x' + f['id'], 'name': nm, 'radical': r,
                   # 不声明 shapePart：族名用变形（亻/扌/氵），而 IDS 给的是全形（人/手/水），
                   # 两者都对；硬声明会让应用质检误报。这条不变量改由 verify-merged.js 校验（它懂全形↔变形）。
                   'intro': f['meaning'], 'grade': f['grade'], 'chars': chars})

# 同一部首同一年级切成多块时会重名，加序号区分（图鉴上要能分辨）
cn = Counter((f['radical'], f['grade']) for f in expand)
sn = Counter()
for ef in expand:
    k = (ef['radical'], ef['grade'])
    if cn[k] > 1:
        sn[k] += 1
        ef['name'] = ef['name'] + '①②③④⑤⑥⑦⑧⑨'[sn[k] - 1]

# 不同部首可能读音相同（辶 与 走 都读"走"），导致同年级内族名撞车——按年级再查一次
seen_name = {}
for ef in expand:
    k = (ef['grade'], ef['name'])
    if k in seen_name:
        # 撞名了：把括号里的字形换成"读音(字形)"更完整的写法
        ef['name'] = (seen_name[k]['name'] + '·' + ef['radical'])
    seen_name[(ef['grade'], ef['name'])] = ef

# ---- q3/q4：需要 emoji 干扰项，放在最后统一做（此时已知所有族的 emoji）----
fam_em = {}
for ef in expand:
    fam_em.setdefault(ef['radical'], []).append(ef)
ALL_EMOJI = sorted({emoji_of(f['radical']) for f in expand})
# 干扰项要显示有意义的标签而不是占位符：emoji -> 它对应哪一族
EM2RAD = {}
for ef in expand:
    EM2RAD.setdefault(emoji_of(ef['radical']), ef['radical'])
for ef in expand:
    own = emoji_of(ef['radical'])
    others = [e for e in ALL_EMOJI if e != own]
    for i, ch in enumerate(ef['chars']):
        q = QBY.get(ch['c'])
        # q3 认族：选项 = emoji + 部首
        rnd = random.Random(ord(ch['c']))
        pick = rnd.sample(others, 2)
        opts = [{'e': own, 'l': ef['radical']}] + \
               [{'e': e, 'l': EM2RAD.get(e) or '?'} for e in pick]
        rnd.shuffle(opts)
        ch['q3'] = {'prompt': '「%s」属于哪一家？' % ch['c'], 'options': opts,
                    'answer': next(j for j, o in enumerate(opts) if o['e'] == own)}
        # q4 组词：直接用已生成的题
        qw = q.get('qWord') if q else None
        if qw:
            ch['q4'] = {'prompt': qw['prompt'], 'options': qw['options'], 'answer': qw['answer']}

tot = sum(len(f['chars']) for f in expand)
w('=== 扩展包生成 ===')
w('族数 %d   字数 %d' % (len(expand), tot))
w('年级分布: ' + json.dumps(sorted({g: sum(len(f['chars']) for f in expand if f['grade'] == g)
                                    for g in range(1, 7)}.items())))
w('跳过统计: ' + json.dumps(dict(skipped), ensure_ascii=False))
w()
w('=== 质检自检（模拟应用的约束）===')
bad = defaultdict(int)
for f in expand:
    for ch in f['chars']:
        if not ch.get('scene'): bad['缺 scene'] += 1
        if not ch.get('emoji'): bad['缺 emoji'] += 1
        if not ch.get('q3') or not ch.get('q4'): bad['缺题'] += 1
        if ch.get('isRoot'):
            if len(ch['notes']) < 1: bad['根字缺讲解'] += 1
            if ch['parts'][0] != ch['c']: bad['根字 parts[0] 不是自己'] += 1
        else:
            if len(ch['parts']) != 2: bad['部件数不是2'] += 1
            if len(ch['notes']) != 2: bad['讲解不是2条'] += 1
        if ch.get('q4') and '___' not in ch['q4']['prompt']: bad['q4 缺 ___'] += 1
        if ch.get('q4') and ch['q4']['options'][ch['q4']['answer']] != ch['c']:
            bad['q4 答案不是本字'] += 1
        if ch.get('q3') and set(o['e'] for o in ch['q3']['options']).__len__() != 3:
            bad['q3 选项 emoji 重复'] += 1
w('问题: ' + (json.dumps(dict(bad), ensure_ascii=False) if bad else '无 ✓'))
w()
w('=== 抽样 ===')
for c in '江清桥湖肝胆':
    ch = next((x for ef in expand for x in ef['chars'] if x['c'] == c), None)
    if ch:
        w('  %s (%s) %s  parts=%s' % (c, ch['py'], ch['emoji'], ch['parts']))
        w('     情境: %s' % ch['scene'])
        w('     讲解: %s | %s' % (ch['notes'][0], ch['notes'][1]))
        w('     q3: %s -> %s' % (ch['q3']['prompt'], [o['e'] for o in ch['q3']['options']]))
        w('     q4: %s -> %s' % (ch['q4']['prompt'], ch['q4']['options']))

js = ('window.CHAR_DATA = window.CHAR_DATA || {families: []};\n'
      'window.CHAR_DATA.families = window.CHAR_DATA.families.concat(' +
      json.dumps(expand, ensure_ascii=False, separators=(',', ':')) + ');\n')
open(os.path.join(APP, 'data', 'expand.js'), 'w', encoding='utf-8').write(js)
w()
w('输出 data/expand.js  %.1f KB' % (os.path.getsize(os.path.join(APP, 'data', 'expand.js')) / 1024.0))

open(os.path.join(HERE, 'last-report.txt'), 'w', encoding='utf-8').write(out.getvalue())
print('ok')
