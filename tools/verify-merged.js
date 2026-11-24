/* 接入扩展包后的全量验证：
   1. 模拟 app.js 的初始化（含去重），看族数/字数对不对
   2. 逐条套用 app.js 自带质检函数的规则
   3. 重点验「提示读音」红线：说了"提示读音"的字，声符韵母必须真的相符 */
global.window = {};
require('E:/AI agent/deepseek work/软件work/data/chars.js');
var origCount = global.window.CHAR_DATA.families.length;
require('E:/AI agent/deepseek work/软件work/data/expand.js');
var FAMS = global.window.CHAR_DATA.families;

/* 声符可能本身不是生字（不在字族里），它的拼音要去 questions.js 取 */
global.window.QUESTIONS = null;
require('E:/AI agent/deepseek work/软件work/data/questions.js');
var QBY = {};
(global.window.QUESTIONS.items || []).forEach(function (q) { QBY[q.c] = q; });
function pyOf(ch) {
  if (QBY[ch] && QBY[ch].py) return QBY[ch].py;
  return null;
}

// —— 复刻 app.js 的初始化（含去重）——
var ALL = [], BY = {}, FAMBY = {};
FAMS.forEach(function (f) {
  FAMBY[f.id] = f;
  (f.chars || []).forEach(function (c) {
    if (BY[c.c]) return;
    c.fam = f.id; ALL.push(c); BY[c.c] = c;
  });
});

// —— 拼音工具（与 app.js pyTier 同口径）——
var TM = {'ā':'a','á':'a','ǎ':'a','à':'a','ē':'e','é':'e','ě':'e','è':'e','ī':'i','í':'i',
          'ǐ':'i','ì':'i','ō':'o','ó':'o','ǒ':'o','ò':'o','ū':'u','ú':'u','ǔ':'u','ù':'u',
          'ǖ':'v','ǘ':'v','ǚ':'v','ǜ':'v','ü':'v','ń':'n','ň':'n','ǹ':'n'};
var INI = ['zh','ch','sh','b','p','m','f','d','t','n','l','g','k','h','j','q','x','r','z','c','s','y','w'];
var AP = {'zh':1,'ch':1,'sh':1,'r':1,'z':1,'c':1,'s':1};
function pb(p){ return p.split('').map(function(c){return TM[c]||c}).join('').toLowerCase(); }
function pf(p){ var b=pb(p); for(var i=0;i<INI.length;i++){ if(b.indexOf(INI[i])===0){ var f=b.slice(INI[i].length); return (f==='i'&&AP[INI[i]])?'i0':f; } } return b; }

var P = { fams: 0, chars: 0, problems: [], soundOK: 0, soundShape: 0, unknownSound: 0, yifuOK: 0 };

/* 义符不变量：parts[0] 必须就是本族部首（允许全形↔变形，如 人↔亻 / 水↔氵） */
var VARIANT = {
  '水': '氵', '氺': '氵', '手': '扌', '艸': '艹', '⺿': '艹', '人': '亻', '言': '讠',
  '訁': '讠', '㣺': '忄', '心': '忄', '糸': '纟', '糹': '纟', '辵': '辶', '金': '钅',
  '釒': '钅', '灬': '火', '刀': '刂', '貝': '贝', '頁': '页', '玉': '王', '犬': '犭',
  '食': '饣', '飠': '饣', '衣': '衤', '示': '礻', '馬': '马', '鳥': '鸟', '魚': '鱼',
  '門': '门', '車': '车', '⺮': '竹', '見': '见', '肉': '月'
};
function canon(x) { return VARIANT[x] || x; }

FAMS.forEach(function (f) {
  P.fams++;
  if (!f.name) P.problems.push(f.id + ' 缺 name');
  if (!f.intro) P.problems.push(f.id + ' 缺 intro');
  (f.chars || []).forEach(function (c) {
    P.chars++;
    var tag = f.id + '/' + c.c + ' ';
    if (!c.scene) P.problems.push(tag + '缺 scene');
    if (!c.emoji) P.problems.push(tag + '缺 emoji');
    if (!c.py) P.problems.push(tag + '缺 py');
    if (c.isRoot) {
      if (!c.parts || c.parts[0] !== c.c) P.problems.push(tag + '根字 parts[0] 应为自身');
      if (!c.notes || !c.notes.length) P.problems.push(tag + '根字缺讲解');
    } else {
      if (!c.parts || c.parts.length !== 2) P.problems.push(tag + 'parts 不是 2 个');
      if (!c.notes || c.notes.length !== 2) P.problems.push(tag + 'notes 不是 2 条');
      // 义符必须在第一位（允许全形↔变形的对应），否则"XX表示意思"会讲错部件。
      // 注意：声符族（如 青之家族）的族部首就是声符，义符另有其人，不能套这条。
      if (c.parts && c.parts.length === 2 && f.radical && !f.soundPart) {
        if (canon(c.parts[0]) !== canon(f.radical))
          P.problems.push(tag + '义符不在第一位：parts[0]=' + c.parts[0] + ' 本族部首=' + f.radical);
        else P.yifuOK++;
      }
      // ★ 红线：说了"提示读音"，声符韵母必须真的相符
      if (c.notes && /提示读音/.test(c.notes[1] || '')) {
        var sp = pyOf(c.parts[1]);
        if (!sp) { P.unknownSound++; }
        else if (pf(sp) !== pf(c.py)) P.problems.push(tag + '红线！说提示读音但韵母不符 ' + c.parts[1] + '=' + sp + ' vs ' + c.py);
        else P.soundOK++;
      } else P.soundShape++;
    }
    ['q3', 'q4'].forEach(function (k) {
      var q = c[k];
      if (!q) { P.problems.push(tag + '缺 ' + k); return; }
      if (!q.options || q.options.length < 3) P.problems.push(tag + k + ' 选项不足 3 个');
      if (typeof q.answer !== 'number' || q.answer < 0 || q.answer >= (q.options || []).length)
        P.problems.push(tag + k + ' 答案越界');
      if (k === 'q3' && q.options && q.options[q.answer] && !q.options[q.answer].e)
        P.problems.push(tag + 'q3 答案不是图片选项');
      if (k === 'q4') {
        if (q.prompt.indexOf('___') === -1) P.problems.push(tag + 'q4 题干缺 ___');
        if (q.options && q.options[q.answer] !== c.c) P.problems.push(tag + 'q4 答案不是本字');
      }
    });
  });
});

// 年级分布
var byGrade = {};
FAMS.forEach(function (f) {
  var g = typeof f.grade === 'number' ? f.grade : 0;
  byGrade[g] = byGrade[g] || { fams: 0, chars: 0 };
  byGrade[g].fams++; byGrade[g].chars += f.chars.length;
});

// 族名重复：chip 是按年级过滤的，所以只关心「同一年级内」是否重名
var perGrade = {};
FAMS.forEach(function (f) {
  var g = typeof f.grade === 'number' ? f.grade : 0;
  perGrade[g] = perGrade[g] || {};
  perGrade[g][f.name] = (perGrade[g][f.name] || 0) + 1;
});
var dupName = [];
Object.keys(perGrade).forEach(function (g) {
  Object.keys(perGrade[g]).forEach(function (n) {
    if (perGrade[g][n] > 1) dupName.push((g === '0' ? '精选' : g + '年级') + ' 「' + n + '」×' + perGrade[g][n]);
  });
});

console.log('=== 合并结果 ===');
console.log('精选族(原始) ' + origCount + '  →  全部族 ' + P.fams);
console.log('族内字条目 ' + P.chars + '   去重后唯字 ' + ALL.length);
console.log('因重复被略过的条目 ' + (P.chars - ALL.length));
console.log('');
console.log('=== 各年级 ===');
Object.keys(byGrade).sort().forEach(function (g) {
  console.log('  ' + (g === '0' ? '精选  ' : g + '年级') + ' ' +
    byGrade[g].fams + ' 族  ' + byGrade[g].chars + ' 字');
});
console.log('');
console.log('=== 质检（app.js 的规则）===');
console.log('问题数 ' + P.problems.length);
P.problems.slice(0, 20).forEach(function (p) { console.log('  ! ' + p); });
console.log('');
console.log('=== 红线专项 ===');
console.log('说「提示读音」且韵母确实相符: ' + P.soundOK);
console.log('说「帮它记住字形」          : ' + P.soundShape);
console.log('声符拼音未知（无法验证）    : ' + P.unknownSound);
console.log('');
console.log('=== 义符位置 ===');
console.log('parts[0] 即本族部首（含全形↔变形）: ' + P.yifuOK);
console.log('');
console.log('=== 族名重复（同年级内）===');
console.log(dupName.length ? '  ' + dupName.join('  ') : '  无 ✓');
