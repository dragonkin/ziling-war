/* 真浏览器端到端测试：用 CDP 驱动 headless Chrome，真的点按钮，捕获运行时报错。
   这是唯一能验证「点进去会不会炸」的方法——数据层校验查不出 UI 运行时错误。 */
const { spawn } = require('child_process');
const http = require('http');
const os = require('os');
const path = require('path');
const fs = require('fs');

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const URL = process.argv[2] || 'http://127.0.0.1:8765/';
const PORT = 9333;
const udd = fs.mkdtempSync(path.join(os.tmpdir(), 'zl-chrome-'));

const sleep = ms => new Promise(r => setTimeout(r, ms));

function getJSON(u) {
  return new Promise((res, rej) => {
    http.get(u, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => res(JSON.parse(b))); })
      .on('error', rej);
  });
}

(async () => {
  const chrome = spawn(CHROME, [
    '--headless=new', '--disable-gpu', '--no-sandbox', '--no-first-run',
    '--remote-debugging-port=' + PORT, '--user-data-dir=' + udd,
    '--window-size=390,844', URL
  ], { stdio: 'ignore' });

  let list = null;
  for (let i = 0; i < 40; i++) {
    await sleep(500);
    try { list = await getJSON('http://127.0.0.1:' + PORT + '/json/list'); if (list && list.length) break; } catch (e) {}
  }
  if (!list || !list.length) { console.log('无法连接 Chrome'); chrome.kill(); process.exit(1); }
  const page = list.find(t => t.type === 'page') || list[0];

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0;
  const pending = {};
  const errors = [];

  ws.addEventListener('message', ev => {
    const m = JSON.parse(ev.data);
    if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; return; }
    if (m.method === 'Runtime.exceptionThrown') {
      const d = m.params.exceptionDetails;
      errors.push('EXCEPTION: ' + (d.exception && d.exception.description ? d.exception.description.split('\n')[0] : d.text));
    }
    if (m.method === 'Runtime.consoleAPICalled' && (m.params.type === 'error' || m.params.type === 'warning')) {
      errors.push(m.params.type.toUpperCase() + ': ' + m.params.args.map(a => a.value || a.description || '').join(' '));
    }
    if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') {
      errors.push('LOG: ' + m.params.entry.text);
    }
  });

  const send = (method, params) => new Promise(res => {
    const myId = ++id; pending[myId] = res;
    ws.send(JSON.stringify({ id: myId, method, params: params || {} }));
  });
  const evalJS = async expr => {
    const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
    if (r.result && r.result.exceptionDetails) return 'EVAL-ERR: ' + r.result.exceptionDetails.text;
    return r.result && r.result.result ? r.result.result.value : undefined;
  };

  await new Promise(r => ws.addEventListener('open', r));
  await send('Runtime.enable');
  await send('Log.enable');
  await sleep(2500);   // 等应用初始化

  const log = [];
  const push = (k, v) => { log.push(k + ': ' + v); };

  push('总族数', await evalJS('window.CHAR_DATA.families.length'));
  push('年级按钮数', await evalJS('document.querySelectorAll("#home-grades .gradechip").length'));
  push('默认选中年级', await evalJS('document.querySelector(".gradechip.on").textContent'));
  push('默认字族数', await evalJS('document.querySelectorAll("#home-fams .famchip").length'));

  // 切到 1 年级
  await evalJS('document.querySelector(\'[data-grade="1"]\').click()');
  await sleep(600);
  push('切1年级后 字族数', await evalJS('document.querySelectorAll("#home-fams .famchip").length'));
  push('切1年级后 首个字族', await evalJS('document.querySelector("#home-fams .famchip").textContent'));
  push('切1年级后 当前族字数', await evalJS('document.getElementById("home-found-total").textContent'));

  // 切到 2 年级
  await evalJS('document.querySelector(\'[data-grade="2"]\').click()');
  await sleep(600);
  push('切2年级后 首个字族', await evalJS('document.querySelector("#home-fams .famchip").textContent'));

  // 开始学习：走完一整轮
  await evalJS('document.getElementById("btn-start").click()');
  await sleep(900);
  push('会话中 learn-body 首屏', await evalJS('(document.getElementById("learn-body").textContent||"").slice(0,60)'));
  push('会话中 可点按钮数', await evalJS('document.querySelectorAll("#learn-body button").length'));

  // 连续点击（优先选项按钮），一直点到会话自然结束为止
  const classesSeen = new Set();
  let steps = 0, ended = false;
  for (let step = 1; step <= 90; step++) {
    steps = step;
    const inSession = await evalJS('document.body.classList.contains("session")');
    if (!inSession) { ended = true; break; }
    const info = await evalJS(`(function(){
      var bs=document.querySelectorAll("#learn-body button");
      if(!bs.length) return null;
      var cls=[];for(var i=0;i<bs.length;i++)cls.push(bs[i].className);
      return {n:bs.length,cls:cls,txt:(document.getElementById("learn-body").textContent||"").slice(0,50)};
    })()`);
    if (!info) { push('第' + step + '步', '无可点按钮（可能卡住）'); break; }
    info.cls.forEach(c => classesSeen.add(c));
    if (step === 1) { push('第1步 按钮class', JSON.stringify(info.cls)); push('第1步 文案', info.txt); }
    // 轮流点不同选项：答错时应用会让孩子再试，总点第一个会永远停在同一题
    const total = info.n;
    const k = (step - 1) % total;
    await evalJS(`(function(){
      var bs=document.querySelectorAll("#learn-body button");
      var pick=null, n=0;
      for(var i=0;i<bs.length;i++){ if(/opt/i.test(bs[i].className)){ if(n===${k % Math.max(1, info.cls.filter(c=>/opt/i.test(c)).length)}){pick=bs[i];break;} n++; } }
      if(!pick){ for(var i=0;i<bs.length;i++){ if(/opt/i.test(bs[i].className)){pick=bs[i];break;} } }
      if(!pick) pick=bs[bs.length-1];
      pick.click();
    })()`);
    if (step <= 6) push('第' + step + '步 文案', info.txt);
    await sleep(180);
  }
  push('点击步数', steps);
  push('会话是否正常结束', ended ? '是 ✓' : '否 ✗（可能卡在题里）');
  push('结束屏文案', await evalJS('(document.getElementById("learn-body").textContent||"").slice(0,60)'));
  push('见过的按钮class', JSON.stringify([...classesSeen]));

  // 检查 localStorage 存档是否落盘
  push('存档已写', await evalJS('!!localStorage.getItem("ziling.save.v1")'));
  push('存档字数', await evalJS('(function(){var s=JSON.parse(localStorage.getItem("ziling.save.v1")||"{}");return Object.keys(s.chars||{}).length})()'));

  // 图鉴页
  await evalJS('document.querySelector(\'[data-go="screen-dex"]\').click()');
  await sleep(600);
  push('图鉴 年级行', await evalJS('document.querySelectorAll("#dex-grades .gradechip").length'));
  push('图鉴 格子数', await evalJS('document.querySelectorAll("#dex-grid > *").length'));

  // 合成台
  await evalJS('document.querySelector(\'[data-go="screen-fuse"]\').click()');
  await sleep(600);
  push('合成台 零件数', await evalJS('document.querySelectorAll("#fuse-parts > *").length'));

  // 家长页 + 字表自检
  await evalJS('document.querySelector(\'[data-go="screen-parent"]\').click()');
  await sleep(600);
  await evalJS('document.getElementById("btn-validate").click()');
  await sleep(1500);
  push('字表自检结果', await evalJS('(document.getElementById("validate-out").textContent||"").slice(0,200)'));

  console.log('===== 端到端结果 =====');
  log.forEach(l => console.log('  ' + l));
  console.log('');
  console.log('===== 运行时报错 =====');
  if (!errors.length) console.log('  无 ✓');
  else [...new Set(errors)].forEach(e => console.log('  ! ' + e));

  ws.close(); chrome.kill();
  try { fs.rmSync(udd, { recursive: true, force: true }); } catch (e) {}
  process.exit(0);
})();
