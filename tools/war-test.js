/* 字灵战记 v3 端到端：验证「关=单元、幕=课」这条结构
   1) 单元来自真实教材（识字表按课），不是按顺序切
   2) 每一幕 = 一课的字；妖王血量 = 本幕要拼的字数
   3) 打完一幕 → 存盘 → 妖王退场 → 下一幕
   4) 最后一幕打完 → 整个单元通关
   5) 中途退出能从那一幕接着玩
*/
const { spawn } = require('child_process');
const http = require('http');
const os = require('os');
const path = require('path');
const fs = require('fs');
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9337;
const URL = process.argv[2] || 'http://127.0.0.1:8765/%E5%AD%97%E7%81%B5%E6%88%98%E8%AE%B0.html';
const udd = fs.mkdtempSync(path.join(os.tmpdir(), 'zl-v3-'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const getJSON = u => new Promise((res, rej) => {
  http.get(u, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => res(JSON.parse(b))); }).on('error', rej);
});

(async () => {
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--no-first-run',
    '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
    '--disable-backgrounding-occluded-windows',
    '--remote-debugging-port=' + PORT, '--user-data-dir=' + udd, '--window-size=430,932', URL], { stdio: 'ignore' });

  let list = null;
  for (let i = 0; i < 40; i++) { await sleep(500); try { list = await getJSON('http://127.0.0.1:' + PORT + '/json/list'); if (list && list.length) break; } catch (e) {} }
  const page = list.find(t => t.type === 'page') || list[0];
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0; const pending = {}; const errors = [];
  ws.addEventListener('message', ev => {
    const m = JSON.parse(ev.data);
    if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; return; }
    if (m.method === 'Runtime.exceptionThrown') {
      const d = m.params.exceptionDetails;
      errors.push('EXCEPTION: ' + (d.exception && d.exception.description ? d.exception.description.split('\n')[0] : d.text));
    }
    if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') errors.push('LOG: ' + m.params.entry.text);
  });
  const send = (method, params) => new Promise(res => { const i = ++id; pending[i] = res; ws.send(JSON.stringify({ id: i, method, params: params || {} })); });
  const ev = async e => {
    const r = await send('Runtime.evaluate', { expression: e, returnByValue: true });
    if (r.result && r.result.exceptionDetails) return 'ERR:' + ((r.result.exceptionDetails.exception || {}).description || '');
    return r.result && r.result.result ? r.result.result.value : undefined;
  };
  const info = async () => {
    const raw = await ev('JSON.stringify(window.__game.info())');
    if (typeof raw !== 'string' || raw.startsWith('ERR:')) throw new Error('info() 失败: ' + raw);
    return JSON.parse(raw);
  };
  const click = async sel => ev(`(function(){var e=document.querySelector('${sel}'); if(!e) return 'NO:'+'${sel}'; e.click(); return 'ok';})()`);

  await new Promise(r => ws.addEventListener('open', r));
  await send('Runtime.enable'); await send('Log.enable');
  await sleep(2400);

  const log = []; const push = (k, v) => log.push('  ' + k + ': ' + v);

  push('__game 存在', await ev('!!window.__game'));
  push('音效自检', JSON.stringify(await ev('JSON.stringify(window.__game.audioTest())')));
  let s = await info();
  push('单元总数 / 册数', s.levels + ' 个单元 / ' + s.books + ' 册');
  push('用的是真实单元吗', s.realUnits ? '是 ✓' : '否 ✗（回退到按顺序分组）');
  push('单元数据来源', s.unitSource);
  push('主菜单进度', await ev('document.getElementById("progText").textContent'));

  // 选关页
  await click('#btnPlay'); await sleep(500);
  push('选关按钮数', await ev('document.querySelectorAll("#pickList .lv").length'));
  push('第一册标题', await ev('document.querySelector("#pickList .bkhd").textContent.trim()'));
  push('前 3 个单元按钮', await ev('Array.from(document.querySelectorAll("#pickList .lv .n")).slice(0,3).map(function(e){return e.textContent.trim()}).join(" ｜ ")'));

  // 剧情页
  await click('#pickList .lv'); await sleep(500);
  push('剧情层显示', await ev('document.getElementById("ovStory").classList.contains("on")'));
  push('剧情标题', await ev('document.getElementById("stTitle").textContent'));
  push('剧情正文', (await ev('document.getElementById("stText").textContent')).slice(0, 60));
  push('幕列表', (await ev('document.getElementById("stActs").textContent')).slice(0, 90));
  await click('#ovStory'); await sleep(900);

  s = await info();
  push('开局: 册/单元', s.book + ' ' + s.unitName);
  push('幕总数', s.actCount + ' 幕：' + s.acts.join(' '));
  push('第 1 幕的字', s.actChars.join('') + '（' + s.actChars.length + ' 字，独体 ' + s.onePartCount + '）');
  push('本幕要拼 actTodo', s.actTodo.join('') + '（' + s.actTodo.length + '）');
  push('妖王', s.boss.name + ' ' + s.boss.hp + '/' + s.boss.max + '  ← 应等于 actTodo 数');
  push('HUD 关卡标签', await ev('document.getElementById("lvTag").textContent'));
  push('部件槽', s.slots);

  // 打一会儿，确认战斗还在
  await ev('window.dispatchEvent(new KeyboardEvent("keydown",{key:"d",bubbles:true}));1');
  await ev('window.dispatchEvent(new KeyboardEvent("keydown",{key:"j",bubbles:true}));1');
  await sleep(6000);
  await ev('window.dispatchEvent(new KeyboardEvent("keyup",{key:"d",bubbles:true}));1');
  await ev('window.dispatchEvent(new KeyboardEvent("keyup",{key:"j",bubbles:true}));1');
  s = await info();
  push('打了6秒 击杀/Boss招式/血量', s.kills + ' / ' + s.bullets + ' / ' + s.hp);

  // 拼第一个字 → 得技能 → 打 Boss
  await ev('window.__game.forcePart(0)'); await sleep(200);
  await ev('window.__game.forcePart(1)'); await sleep(500);
  s = await info();
  const before = s.boss.hp;
  push('拼字后技能', JSON.stringify(s.skills));
  await ev('window.__game.useSkill()'); await sleep(600);
  s = await info();
  push('放技能 Boss', before + ' → ' + s.boss.hp);

  // 打完第 1 幕
  let g = 0;
  while (g++ < 60) {
    s = await info();
    if (s.state === 'actbreak' || s.state === 'clear') break;
    await ev('window.__game.forcePart(0)'); await sleep(120);
    await ev('window.__game.forcePart(1)'); await sleep(150);
    await ev('window.__game.useSkill()'); await sleep(180);
  }
  await sleep(900);
  s = await info();
  push('第 1 幕结束状态', s.state + '（应是 actbreak）');
  push('幕间层显示', await ev('document.getElementById("ovAct").classList.contains("on")'));
  push('幕间标题', await ev('document.getElementById("actTitle").textContent'));
  push('下一幕提示', await ev('document.getElementById("actNextTitle").textContent'));
  push('存档 acts', (await ev('localStorage.getItem("ziling.war.save.v3")') || '').slice(0, 80));

  // 继续下一幕
  await click('#btnActGo'); await sleep(900);
  s = await info();
  push('进入第 2 幕', 'actIdx=' + s.actIdx + ' ' + s.acts[1] + '  字: ' + s.actChars.join(''));
  push('第 2 幕妖王', s.boss.hp + '/' + s.boss.max + '  名字: ' + s.boss.name);
  push('部件槽已重置', s.slots);

  // 中途退出 → 看能否从第 2 幕续
  await click('#btnActQuit'); await sleep(600);
  push('幕间「先歇一会儿」→ 回到选关', await ev('document.getElementById("ovPick").classList.contains("on")'));
  push('选关页显示打到第几幕', await ev('document.querySelector("#pickList .lv .n").textContent.trim()'));
  await click('#pickList .lv'); await sleep(500);
  push('重进单元的续玩提示', (await ev('document.getElementById("stText").textContent')).includes('接着来') ? '有 ✓：' + (await ev('document.getElementById("stText").textContent')).slice(-18) : '没有 ✗');
  await click('#ovStory'); await sleep(800);
  s = await info();
  push('续玩落在第几幕', 'actIdx=' + s.actIdx + '（应为 1，即第 2 幕）  字: ' + s.actChars.join(''));
  push('六年级缺口是否标明', await ev('document.querySelectorAll("#pickList .bkblk")[10] ? document.querySelectorAll("#pickList .bkblk")[10].textContent.slice(0,24) : "没标 ✗"'));

  // 把整单元打完
  for (let a = s.actIdx; a < s.actCount; a++) {
    let k = 0;
    while (k++ < 60) {
      const st = await info();
      if (st.state === 'actbreak' || st.state === 'clear') break;
      await ev('window.__game.forcePart(0)'); await sleep(80);
      await ev('window.__game.forcePart(1)'); await sleep(90);
      await ev('window.__game.useSkill()'); await sleep(110);
    }
    await sleep(700);
    const st = await info();
    if (st.state === 'clear') break;
    await ev('window.__game.gotoAct(' + (a + 1) + ')'); await sleep(500);
  }
  await sleep(1400);
  s = await info();
  push('整单元结束状态', s.state);
  push('通关层显示', await ev('document.getElementById("ovClear").classList.contains("on")'));
  push('通关文案', (await ev('document.getElementById("clearInfo").textContent') || '').slice(0, 80));
  push('通关字灵数', (await ev('document.getElementById("clearList").textContent') || '').length);

  // 重新进入同一单元，应从第 1 幕（已全清则第 0 幕）开始
  await click('#btnHome'); await sleep(600);
  push('返回选关后按钮数', await ev('document.querySelectorAll("#pickList .lv").length'));

  console.log('===== 字灵战记 v3 · 关=单元 幕=课 =====');
  log.forEach(l => console.log(l));
  console.log('\n===== 运行时报错 =====');
  if (!errors.length) console.log('  无 ✓');
  else [...new Set(errors)].forEach(e => console.log('  ! ' + e));

  ws.close(); chrome.kill();
  try { fs.rmSync(udd, { recursive: true, force: true }); } catch (e) {}
  process.exit(0);
})();
