/* 字灵技能表：按"字的含义 / 部首"决定这个字放出来是什么技能、什么特效。
   这不是随便配的——氵的字就是水系，火字旁就是火系，孩子拼出「江」看到洪水，
   拼出「烧」看到火焰，字形和字义就绑在一起了。

   生成 data/skills.js： window.SKILLS = { byChar:{}, byRadical:{}, default:{} }
*/
const fs = require('fs'), path = require('path');
const APP = path.join(__dirname, '..');

global.window = {};
require(path.join(APP, 'data/chars.js'));
require(path.join(APP, 'data/expand.js'));
require(path.join(APP, 'data/gamechars.js'));
const FAMS = global.window.CHAR_DATA.families;
const GAMECHARS = global.window.GAMECHARS || {};

/* 技能原型：kind 决定特效画法，color 决定主色，n 是技能名 */
const KIND = {
  cone:  '锥形喷射',
  wave:  '横扫波',
  spin:  '旋风',
  bolt:  '天雷',
  rain:  '天降',
  vine:  '地生藤蔓',
  fall:  '落石',
  blade: '飞刃',
  beam:  '光束',
  burst: '爆裂',
  swarm: '成群扑击',
  fist:  '巨拳',
  dash:  '冲刺',
  cloud: '云涌'
};

/* ① 直接是"元素字"的，用字本身 */
const BY_CHAR = {
  '风': { n:'狂风', k:'spin',  c:'#9fe8d0' },
  '云': { n:'云涌', k:'cloud', c:'#d6e8ff' },
  '雨': { n:'暴雨', k:'rain',  c:'#7fc4ff' },
  '雷': { n:'落雷', k:'bolt',  c:'#ffe14a' },
  '雪': { n:'暴雪', k:'rain',  c:'#eaf7ff' },
  '冰': { n:'寒冰', k:'fall',  c:'#a8e8ff' },
  '火': { n:'烈焰', k:'cone',  c:'#ff8a3c' },
  '水': { n:'洪流', k:'wave',  c:'#4fb8ff' },
  '木': { n:'藤蔓', k:'vine',  c:'#5fd07a' },
  '土': { n:'落石', k:'fall',  c:'#c8a06a' },
  '石': { n:'碎石', k:'fall',  c:'#b9c2cc' },
  '金': { n:'金刃', k:'blade', c:'#ffd964' },
  '刀': { n:'刀光', k:'blade', c:'#e6eef8' },
  '山': { n:'山峰', k:'fall',  c:'#a8b8a0' },
  '日': { n:'烈日', k:'beam',  c:'#ffd45e' },
  '月': { n:'月光', k:'beam',  c:'#cfe0ff' },
  '光': { n:'强光', k:'beam',  c:'#fff3b0' },
  '星': { n:'星雨', k:'rain',  c:'#ffe9a0' },
  '海': { n:'怒海', k:'wave',  c:'#2f9ee0' },
  '河': { n:'大河', k:'wave',  c:'#54b8ff' },
  '江': { n:'长江', k:'wave',  c:'#3fa8ff' },
  '龙': { n:'龙腾', k:'dash',  c:'#ffd45e' },
  '虎': { n:'虎啸', k:'dash',  c:'#ffb04a' },
  '鸟': { n:'飞鸟', k:'swarm', c:'#8fd4ff' },
  '鱼': { n:'鱼跃', k:'wave',  c:'#68c8e0' },
  '虫': { n:'虫群', k:'swarm', c:'#a6d84a' },
  '花': { n:'花雨', k:'rain',  c:'#ff9bd0' },
  '草': { n:'草丛', k:'vine',  c:'#66d17e' },
  '树': { n:'树根', k:'vine',  c:'#4fb86a' },
  '林': { n:'密林', k:'vine',  c:'#3fa85a' },
  '牛': { n:'蛮牛', k:'dash',  c:'#d8b48a' },
  '马': { n:'奔马', k:'dash',  c:'#e0b878' },
  '犬': { n:'犬牙', k:'dash',  c:'#c8a080' },
  '口': { n:'声波', k:'wave',  c:'#ffd0a0' },
  '目': { n:'目光', k:'beam',  c:'#ffe9a0' },
  '心': { n:'心波', k:'burst', c:'#ff8fb0' },
  '手': { n:'巨掌', k:'fist',  c:'#ffb26b' },
  '足': { n:'踏击', k:'fall',  c:'#c8b090' }
};

/* ② 其余的字，按它所在字族的部首给一套同系技能 */
const BY_RAD = {
  '氵':{n:'水波',k:'wave',c:'#4fb8ff'},   '水':{n:'水柱',k:'wave',c:'#4fb8ff'},
  '火':{n:'火舌',k:'cone',c:'#ff8a3c'},   '灬':{n:'热浪',k:'cone',c:'#ff9a4c'},
  '木':{n:'枝条',k:'vine',c:'#5fd07a'},   '艹':{n:'藤蔓',k:'vine',c:'#66d17e'},
  '竹':{n:'竹刺',k:'vine',c:'#8ad060'},   '禾':{n:'谷穗',k:'vine',c:'#e0d060'},
  '土':{n:'沙尘',k:'fall',c:'#c8a06a'},   '石':{n:'碎石',k:'fall',c:'#b9c2cc'},
  '山':{n:'岩落',k:'fall',c:'#a8b8a0'},   '钅':{n:'金刃',k:'blade',c:'#ffd964'},
  '金':{n:'金刃',k:'blade',c:'#ffd964'},  '刂':{n:'刀光',k:'blade',c:'#e6eef8'},
  '刀':{n:'刀光',k:'blade',c:'#e6eef8'},  '虫':{n:'虫群',k:'swarm',c:'#a6d84a'},
  '鸟':{n:'飞鸟',k:'swarm',c:'#8fd4ff'},  '鱼':{n:'鱼群',k:'swarm',c:'#68c8e0'},
  '马':{n:'奔马',k:'dash',c:'#e0b878'},   '犭':{n:'猛兽',k:'dash',c:'#c8a080'},
  '犬':{n:'猛兽',k:'dash',c:'#c8a080'},   '车':{n:'冲车',k:'dash',c:'#c0c8d8'},
  '扌':{n:'巨拳',k:'fist',c:'#ffb26b'},   '手':{n:'巨掌',k:'fist',c:'#ffb26b'},
  '心':{n:'心波',k:'burst',c:'#ff8fb0'},  '忄':{n:'心波',k:'burst',c:'#ff8fb0'},
  '口':{n:'声波',k:'wave',c:'#ffd0a0'},   '目':{n:'目光',k:'beam',c:'#ffe9a0'},
  '日':{n:'日光',k:'beam',c:'#ffd45e'},   '月':{n:'月光',k:'beam',c:'#cfe0ff'},
  '雨':{n:'雨点',k:'rain',c:'#7fc4ff'},   '风':{n:'旋风',k:'spin',c:'#9fe8d0'},
  '云':{n:'云涌',k:'cloud',c:'#d6e8ff'},  '贝':{n:'金雨',k:'rain',c:'#ffd964'},
  '王':{n:'玉碎',k:'burst',c:'#a0f0e0'},  '玉':{n:'玉碎',k:'burst',c:'#a0f0e0'},
  '女':{n:'花雨',k:'rain',c:'#ff9bd0'},   '米':{n:'米粒',k:'rain',c:'#f0e8c0'},
  '糸':{n:'丝线',k:'beam',c:'#ffb0d0'},   '纟':{n:'丝线',k:'beam',c:'#ffb0d0'},
  '讠':{n:'言灵',k:'wave',c:'#a0d8ff'},   '言':{n:'言灵',k:'wave',c:'#a0d8ff'},
  '亻':{n:'人海',k:'swarm',c:'#c0d0e8'},  '人':{n:'人海',k:'swarm',c:'#c0d0e8'},
  '大':{n:'巨力',k:'fist',c:'#ffb26b'},   '宀':{n:'屋宇',k:'fall',c:'#b8c0d0'},
  '门':{n:'门扉',k:'burst',c:'#c8b090'},  '阝':{n:'山壁',k:'fall',c:'#a8b8a0'},
  '阝左':{n:'山壁',k:'fall',c:'#a8b8a0'},
  '饣':{n:'食气',k:'burst',c:'#e0b070'},  '食':{n:'食气',k:'burst',c:'#e0b070'},
  '衤':{n:'衣袂',k:'spin',c:'#d0a0e0'},   '衣':{n:'衣袂',k:'spin',c:'#d0a0e0'},
  '礻':{n:'祈光',k:'beam',c:'#ffe0a0'},   '示':{n:'祈光',k:'beam',c:'#ffe0a0'},
  '田':{n:'地裂',k:'wave',c:'#b0d070'},   '力':{n:'蛮力',k:'fist',c:'#ffab6b'},
  '页':{n:'头槌',k:'dash',c:'#d8c0a0'},   '疒':{n:'瘴气',k:'cloud',c:'#c0a0d0'},
  '宀':{n:'屋宇',k:'fall',c:'#b8c0d0'},   '广':{n:'屋檐',k:'fall',c:'#b8c0d0'},
  '尸':{n:'压制',k:'fall',c:'#b0a8a0'},   '穴':{n:'地陷',k:'fall',c:'#a89c90'},
  '彳':{n:'疾行',k:'dash',c:'#c0d8e8'},   '辶':{n:'疾行',k:'dash',c:'#c0d8e8'},
  '走':{n:'疾行',k:'dash',c:'#c0d8e8'},   '见':{n:'洞察',k:'beam',c:'#c8e8ff'},
  '页':{n:'头槌',k:'dash',c:'#d8c0a0'},   '骨':{n:'骨刺',k:'blade',c:'#e0e0d0'},
  '舟':{n:'舟行',k:'dash',c:'#a0c8d8'},   '酉':{n:'酒液',k:'wave',c:'#d0a060'},
  '羽':{n:'羽翼',k:'swarm',c:'#e8e8ff'},  '皿':{n:'器鸣',k:'burst',c:'#c0c8c0'},
  '耳':{n:'听风',k:'wave',c:'#ffd8b0'},   '辛':{n:'辛辣',k:'cone',c:'#ff7a5a'},
  '立':{n:'屹立',k:'burst',c:'#b0d0e0'},  '衣':{n:'衣袂',k:'spin',c:'#d0a0e0'},
  '页':{n:'头槌',k:'dash',c:'#d8c0a0'},   '工':{n:'工器',k:'blade',c:'#c8d0d8'},
  '白':{n:'白光',k:'beam',c:'#ffffff'},   '黑':{n:'暗影',k:'cloud',c:'#8890a8'},
  '黄':{n:'黄土',k:'fall',c:'#e0c060'},   '青':{n:'青芒',k:'beam',c:'#7fd8c0'},
  '赤':{n:'赤焰',k:'cone',c:'#ff6a4a'},
  '父':{n:'家威',k:'burst',c:'#d0b090'},  '子':{n:'生机',k:'vine',c:'#8ad890'},
  '士':{n:'士气',k:'burst',c:'#c8d0e0'},  '又':{n:'再击',k:'fist',c:'#ffb26b'},
  '爪':{n:'利爪',k:'blade',c:'#e0d0b0'},  '页':{n:'头槌',k:'dash',c:'#d8c0a0'},
  '戈':{n:'戈击',k:'blade',c:'#d0d8e0'},  '弓':{n:'劲射',k:'beam',c:'#e0c8a0'},
  '巾':{n:'布幕',k:'cloud',c:'#c8d8e8'},  '缶':{n:'陶鸣',k:'burst',c:'#c8b090'},
  '艮':{n:'山止',k:'fall',c:'#b8b0a0'},   '无':{n:'虚无',k:'cloud',c:'#b0b0c8'},
  '辰':{n:'辰光',k:'beam',c:'#e0d0a0'},   '页':{n:'头槌',k:'dash',c:'#d8c0a0'},
  /* ---- 独体字/常用部首补齐（一年级最核心的那批字在这里）---- */
  '足':{n:'踏击',k:'dash',c:'#c8a06a'},   '一':{n:'一笔斩',k:'blade',c:'#cfd8e8'},
  '二':{n:'双笔斩',k:'blade',c:'#c8d4e4'}, '丨':{n:'笔锋',k:'blade',c:'#d8e0ec'},
  '丿':{n:'撇锋',k:'blade',c:'#d0d8e4'},   '丶':{n:'点朱',k:'burst',c:'#ff9a8a'},
  '十':{n:'十字斩',k:'blade',c:'#e8d8b0'}, '攵':{n:'敲击',k:'fist',c:'#ffb26b'},
  '冫':{n:'寒冰',k:'fall',c:'#a8e8ff'},   '囗':{n:'围困',k:'burst',c:'#b8c8d8'},
  '厂':{n:'屋檐砸落',k:'fall',c:'#b8c0d0'}, '欠':{n:'吐息',k:'cloud',c:'#d8e0f0'},
  '亠':{n:'点睛',k:'beam',c:'#ffe9a0'},   '寸':{n:'寸劲',k:'fist',c:'#ffab6b'},
  '儿':{n:'疾走',k:'dash',c:'#c0d8e8'},   '八':{n:'分叉',k:'burst',c:'#c8d8e8'},
  '小':{n:'微尘',k:'swarm',c:'#dbd0b8'},  '乙':{n:'曲笔',k:'blade',c:'#c8d0dc'},
  '方':{n:'旌旗',k:'spin',c:'#d0a0e0'},   '隹':{n:'群鸟',k:'swarm',c:'#8fd4ff'},
  '曰':{n:'言语',k:'wave',c:'#a0d8ff'},   '止':{n:'止步',k:'fall',c:'#b8b0a0'},
  '矢':{n:'飞箭',k:'beam',c:'#e0c8a0'},   '几':{n:'云几',k:'cloud',c:'#c8d8e8'},
  '斤':{n:'巨斧',k:'blade',c:'#c8d0d8'},  '夕':{n:'夜幕',k:'cloud',c:'#8890a8'},
  '勹':{n:'包裹',k:'burst',c:'#c8b090'},  '羊':{n:'羊群',k:'swarm',c:'#e8e0d0'},
  '冖':{n:'覆盖',k:'fall',c:'#b0b8c8'},   '匚':{n:'匣中',k:'burst',c:'#c0b8a8'},
  '卩':{n:'印记',k:'beam',c:'#d8c0a0'},   '歹':{n:'凶煞',k:'cloud',c:'#9888a8'},
  '牜':{n:'牛群',k:'dash',c:'#d8b48a'},   '鬼':{n:'鬼影',k:'cloud',c:'#9098b8'},
  '罒':{n:'罗网',k:'rain',c:'#c0c8b0'},   '关':{n:'滋养',k:'vine',c:'#8ad890'},
  '干':{n:'干戈',k:'blade',c:'#d0c8b0'},  '彡':{n:'彩光',k:'beam',c:'#ffb0d0'},
  '毛':{n:'绒毛',k:'cloud',c:'#e8e0d8'},  '行':{n:'疾行',k:'dash',c:'#c0d8e8'},
  '户':{n:'门户',k:'fall',c:'#c8b090'},   '殳':{n:'重击',k:'fist',c:'#ffb26b'},
  '里':{n:'田野',k:'vine',c:'#b0d070'},   '夂':{n:'缓行',k:'dash',c:'#c8d0c0'},
  '廾':{n:'双手',k:'fist',c:'#ffb26b'},   '舌':{n:'舌尖',k:'wave',c:'#ffb0a0'},
  '身':{n:'身躯',k:'fist',c:'#ffb26b'},   '青':{n:'青芒',k:'beam',c:'#7fd8c0'},
  '非':{n:'双翼',k:'swarm',c:'#d0d8e8'},  '音':{n:'音波',k:'wave',c:'#ffd0a0'},
  '首':{n:'首击',k:'dash',c:'#d8c0a0'},   '高':{n:'高塔',k:'fall',c:'#c8c0b0'},
  '麻':{n:'麻林',k:'vine',c:'#8ad060'},   '鹿':{n:'鹿奔',k:'dash',c:'#d8b88a'},
  '鼠':{n:'鼠群',k:'swarm',c:'#b8a8a0'},  '黑':{n:'暗影',k:'cloud',c:'#8890a8'},
  '白':{n:'白光',k:'beam',c:'#ffffff'},   '赤':{n:'赤焰',k:'cone',c:'#ff6a4a'},
  '黄':{n:'黄土',k:'fall',c:'#e0c060'},   '甘':{n:'甘霖',k:'rain',c:'#e0d890'},
  '舟':{n:'舟行',k:'dash',c:'#a0c8d8'},   '穴':{n:'地陷',k:'fall',c:'#a89c90'},
  '立':{n:'屹立',k:'burst',c:'#b0d0e0'},  '见':{n:'洞察',k:'beam',c:'#c8e8ff'},
  '走':{n:'疾走',k:'dash',c:'#c0d8e8'},   '豆':{n:'豆弹',k:'burst',c:'#d0a860'},
  '豕':{n:'野猪',k:'dash',c:'#c8a080'},   '贝':{n:'金雨',k:'rain',c:'#ffd964'},
  '鼓':{n:'鼓震',k:'burst',c:'#d8a060'},  '齐':{n:'齐射',k:'beam',c:'#d0d8c0'},
  '龙':{n:'龙腾',k:'dash',c:'#ffd45e'},   '龟':{n:'龟甲',k:'burst',c:'#8ac890'},
  '鼎':{n:'鼎鸣',k:'burst',c:'#c0a878'},  '黍':{n:'黍穗',k:'vine',c:'#e0d060'},
  '黾':{n:'蛙跃',k:'swarm',c:'#90c880'},  '尸':{n:'压制',k:'fall',c:'#b0a8a0'},
  '广':{n:'屋檐砸落',k:'fall',c:'#b8c0d0'}, '彳':{n:'疾行',k:'dash',c:'#c0d8e8'},
  '辶':{n:'疾行',k:'dash',c:'#c0d8e8'},   '皿':{n:'器鸣',k:'burst',c:'#c0c8c0'},
  '弓':{n:'劲射',k:'beam',c:'#e0c8a0'},   '戈':{n:'戈击',k:'blade',c:'#d0d8e0'},
  '巾':{n:'布幕',k:'cloud',c:'#c8d8e8'},  '缶':{n:'陶鸣',k:'burst',c:'#c8b090'},
  '艮':{n:'山止',k:'fall',c:'#b8b0a0'},   '无':{n:'虚无',k:'cloud',c:'#b0b0c8'},
  '父':{n:'家威',k:'burst',c:'#d0b090'},  '子':{n:'生机',k:'vine',c:'#8ad890'},
  '士':{n:'士气',k:'burst',c:'#c8d0e0'},  '又':{n:'再击',k:'fist',c:'#ffb26b'},
  '爪':{n:'利爪',k:'blade',c:'#e0d0b0'},  '片':{n:'木片',k:'blade',c:'#c8b090'},
  '牛':{n:'蛮牛',k:'dash',c:'#d8b48a'},   '玉':{n:'玉碎',k:'burst',c:'#a0f0e0'},
  '田':{n:'地裂',k:'wave',c:'#b0d070'},   '力':{n:'蛮力',k:'fist',c:'#ffab6b'},
  '疒':{n:'瘴气',k:'cloud',c:'#c0a0d0'},  '骨':{n:'骨刺',k:'blade',c:'#e0e0d0'},
  '羽':{n:'羽翼',k:'swarm',c:'#e8e8ff'},  '耳':{n:'听风',k:'wave',c:'#ffd8b0'},
  '辛':{n:'辛辣',k:'cone',c:'#ff7a5a'},   '酉':{n:'酒液',k:'wave',c:'#d0a060'},
  '工':{n:'工器',k:'blade',c:'#c8d0d8'},  '土':{n:'沙尘',k:'fall',c:'#c8a06a'},
  '山':{n:'岩落',k:'fall',c:'#a8b8a0'},   '石':{n:'碎石',k:'fall',c:'#b9c2cc'},

};

/* ③ 剩下的小部首：按部首本身确定性派生（同一个部首永远同一套，不会每次刷新都变） */
const KIND_LIST = ['cone','wave','spin','bolt','rain','vine','fall','blade','beam','burst','swarm','fist','dash','cloud'];
const KIND_NAME = { cone:'喷射', wave:'冲击波', spin:'旋风', bolt:'落雷', rain:'天降', vine:'藤蔓',
                    fall:'落石', blade:'飞刃', beam:'光束', burst:'爆裂', swarm:'成群',
                    fist:'巨拳', dash:'冲刺', cloud:'云涌' };
const PALETTE = ['#ff8a3c','#4fb8ff','#5fd07a','#ffd964','#c8a06a','#ff9bd0','#9fe8d0',
                 '#c8b0ff','#8fd4ff','#ffb26b','#b9c2cc','#ff7a7a','#7fd8c0','#e0b878'];
function deriveSkill(rad) {
  let h = 2166136261;
  for (const ch of String(rad)) h = ((h ^ ch.codePointAt(0)) * 16777619) >>> 0;
  return { n: '字灵·' + KIND_NAME[KIND_LIST[h % KIND_LIST.length]],
           k: KIND_LIST[h % KIND_LIST.length],
           c: PALETTE[(h >>> 7) % PALETTE.length] };
}

const DEFAULT = { n:'字灵波', k:'burst', c:'#ffd964' };

/* 建表：每个字 -> 技能 */
const byChar = {};
FAMS.forEach(f => {
  const rad = f.radical || '';
  const famSkill = BY_RAD[rad] || DEFAULT;
  (f.chars || []).forEach(c => {
    if (byChar[c.c]) return;
    byChar[c.c] = BY_CHAR[c.c] || famSkill;
  });
});
/* 全量字表补齐：教材里 2893 个字都要有技能（含独体字） */
let addedByGamechars = 0, derived = 0;
Object.keys(GAMECHARS).forEach(ch => {
  if (byChar[ch]) return;
  const rad = (GAMECHARS[ch] && GAMECHARS[ch].rad) || '';
  if (BY_CHAR[ch]) { byChar[ch] = BY_CHAR[ch]; addedByGamechars++; return; }
  if (BY_RAD[rad]) { byChar[ch] = BY_RAD[rad]; addedByGamechars++; return; }
  byChar[ch] = deriveSkill(rad || ch); addedByGamechars++; derived++;
});
/* 元素字本身也补进去（哪怕不在字族里） */
let addedByChar = 0;
Object.keys(BY_CHAR).forEach(ch => { if (!byChar[ch]) { byChar[ch] = BY_CHAR[ch]; addedByChar++; } });

const out = '/* 自动生成，勿手改。生成器：tools/gen-skills.js */\n' +
  'window.SKILLS = ' + JSON.stringify({
    byChar: byChar,
    byRadical: BY_RAD,
    default: DEFAULT
  }, null, 0) + ';\n';
fs.writeFileSync(path.join(APP, 'data/skills.js'), out, 'utf8');

/* 统计 */
const kindCount = {}, radCount = {};
Object.keys(byChar).forEach(ch => {
  const s = byChar[ch];
  kindCount[s.k] = (kindCount[s.k] || 0) + 1;
});
console.log('技能表已生成 data/skills.js');
console.log('  可放技能的字数:', Object.keys(byChar).length);
console.log('  （其中靠全量字表补齐的:', addedByGamechars + '，其中按部首派生的:', derived + '）');
console.log('  全量字表覆盖率:', Object.keys(GAMECHARS).filter(c => byChar[c]).length + '/' + Object.keys(GAMECHARS).length);
console.log('  技能原型种类  :', Object.keys(kindCount).length);
console.log('  各原型字数    :', Object.keys(kindCount).sort((a,b)=>kindCount[b]-kindCount[a]).map(k=>k+'='+kindCount[k]).join(' '));
console.log('');
console.log('  抽样:');
['风','云','雨','雷','火','水','江','烧','树','马','说','心','贝','竹','天','我','一','口','日','月'].forEach(ch => {
  const s = byChar[ch];
  console.log('    ' + ch + ' -> ' + (s ? (s.n + '  (' + KIND[s.k] + ', ' + s.c + ')') : '（无）'));
});
