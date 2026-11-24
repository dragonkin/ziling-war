/* 给 v3 游戏截图（关=单元、幕=课），肉眼验收 */
const { spawn } = require('child_process');
const http = require('http');
const os = require('os');
const path = require('path');
const fs = require('fs');
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9338;
const URL = process.argv[2] || 'http://127.0.0.1:8765/%E5%AD%97%E7%81%B5%E6%88%98%E8%AE%B0.html';
const OUT = path.join(__dirname, '..', 'shots');
const udd = fs.mkdtempSync(path.join(os.tmpdir(), 'zl-s3-'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const getJSON = u => new Promise((res, rej) => {
  http.get(u, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => res(JSON.parse(b))); }).on('error', rej);
});
if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--no-first-run',
    '--hide-scrollbars', '--force-device-scale-factor=2',
    '--remote-debugging-port=' + PORT, '--user-data-dir=' + udd, '--window-size=430,900', URL], { stdio: 'ignore' });
  let list = null;
  for (let i = 0; i < 40; i++) { await sleep(500); try { list = await getJSON('http://127.0.0.1:' + PORT + '/json/list'); if (list && list.length) break; } catch (e) {} }
  const page = list.find(t => t.type === 'page') || list[0];
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0; const pending = {};
  ws.addEventListener('message', ev => { const m = JSON.parse(ev.data); if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; } });
  const send = (m, p) => new Promise(res => { const i = ++id; pending[i] = res; ws.send(JSON.stringify({ id: i, method: m, params: p || {} })); });
  const ev = async e => { const r = await send('Runtime.evaluate', { expression: e, returnByValue: true }); return r.result && r.result.result ? r.result.result.value : undefined; };
  const shot = async name => {
    const r = await send('Page.captureScreenshot', { format: 'png' });
    const f = path.join(OUT, name + '.png');
    fs.writeFileSync(f, Buffer.from(r.result.data, 'base64'));
    console.log('  ' + name + '.png  ' + Math.round(fs.statSync(f).size / 1024) + ' KB');
  };

  await new Promise(r => ws.addEventListener('open', r));
  await send('Runtime.enable'); await send('Page.enable');
  await sleep(2400);

  await shot('v3-1-menu');
  await ev('document.getElementById("btnPlay").click()'); await sleep(700);
  await shot('v3-2-pick');
  await ev('document.querySelectorAll("#pickList .lv")[0].click()'); await sleep(700);
  await shot('v3-3-story');
  await ev('document.getElementById("ovStory").click()'); await sleep(2800);
  await shot('v3-4-battle');

  // 拼出第一个字，拿技能
  await ev('window.__game.forcePart(0)'); await sleep(300);
  await ev('window.__game.forcePart(1)'); await sleep(900);
  await shot('v3-5-assembled');
  // 放技能（抓住特效那一帧）
  await ev('window.__game.useSkill()'); await sleep(280);
  await shot('v3-6-skill-fx');
  await sleep(1600);

  // 多拼几个字，让技能栏堆起来
  for (let i = 0; i < 3; i++) {
    await ev('window.__game.forcePart(0)'); await sleep(200);
    await ev('window.__game.forcePart(1)'); await sleep(500);
  }
  await shot('v3-7-skillbar');

  // 打完第 1 幕 → 幕间画面
  for (let i = 0; i < 40; i++) {
    const st = await ev('window.__game.info().state');
    if (st === 'actbreak' || st === 'clear') break;
    await ev('window.__game.forcePart(0)'); await sleep(120);
    await ev('window.__game.forcePart(1)'); await sleep(160);
    await ev('window.__game.useSkill()'); await sleep(180);
  }
  await sleep(1500);
  await shot('v3-8-actbreak');

  // 继续下一幕
  await ev('document.getElementById("btnActGo").click()'); await sleep(2200);
  await shot('v3-9-act2');

  // 一路打到整个单元通关
  for (let a = 0; a < 14; a++) {
    for (let i = 0; i < 40; i++) {
      const st = await ev('window.__game.info().state');
      if (st === 'actbreak' || st === 'clear') break;
      await ev('window.__game.forcePart(0)'); await sleep(100);
      await ev('window.__game.forcePart(1)'); await sleep(130);
      await ev('window.__game.useSkill()'); await sleep(150);
    }
    await sleep(900);
    const st = await ev('window.__game.info().state');
    if (st === 'clear') break;
    await ev('document.getElementById("btnActGo").click()'); await sleep(900);
  }
  await sleep(1200);
  await shot('v3-10-clear');

  ws.close(); chrome.kill();
  try { fs.rmSync(udd, { recursive: true, force: true }); } catch (e) {}
  process.exit(0);
})();
