/* 最小诊断：加载 字灵战记.html，把加载期抛出的异常完整打出来 */
const { spawn } = require('child_process');
const http = require('http');
const os = require('os');
const path = require('path');
const fs = require('fs');
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9335;
const URL = process.argv[2] || 'http://127.0.0.1:8765/%E5%AD%97%E7%81%B5%E6%88%98%E8%AE%B0.html';
const udd = fs.mkdtempSync(path.join(os.tmpdir(), 'zl-diag-'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const getJSON = u => new Promise((res, rej) => {
  http.get(u, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => res(JSON.parse(b))); }).on('error', rej);
});

(async () => {
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--no-first-run',
    '--remote-debugging-port=' + PORT, '--user-data-dir=' + udd, URL], { stdio: 'ignore' });
  let list = null;
  for (let i = 0; i < 40; i++) { await sleep(500); try { list = await getJSON('http://127.0.0.1:' + PORT + '/json/list'); if (list && list.length) break; } catch (e) {} }
  const page = list.find(t => t.type === 'page') || list[0];
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0; const pending = {}; const errs = [];
  ws.addEventListener('message', ev => {
    const m = JSON.parse(ev.data);
    if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; return; }
    if (m.method === 'Runtime.exceptionThrown') {
      const d = m.params.exceptionDetails;
      errs.push((d.exception && d.exception.description) ? d.exception.description : JSON.stringify(d));
    }
    if (m.method === 'Log.entryAdded') errs.push('[' + m.params.entry.level + '] ' + m.params.entry.text);
    if (m.method === 'Runtime.consoleAPICalled') errs.push('[console] ' + m.params.args.map(a => a.value || a.description || '').join(' '));
  });
  const send = (method, params) => new Promise(res => { const i = ++id; pending[i] = res; ws.send(JSON.stringify({ id: i, method, params: params || {} })); });
  const ev = async e => { const r = await send('Runtime.evaluate', { expression: e, returnByValue: true }); return r.result && r.result.result ? r.result.result.value : JSON.stringify(r.result); };

  await new Promise(r => ws.addEventListener('open', r));
  await send('Runtime.enable'); await send('Log.enable');
  await sleep(2500);

  console.log('CHAR_DATA 存在 :', await ev('typeof window.CHAR_DATA'));
  console.log('字族数         :', await ev('window.CHAR_DATA ? window.CHAR_DATA.families.length : -1'));
  console.log('__game 存在    :', await ev('typeof window.__game'));
  console.log('canvas 存在    :', await ev('!!document.getElementById("cv")'));
  console.log('');
  console.log('--- 异常 / 日志 ---');
  if (!errs.length) console.log('无');
  else [...new Set(errs)].forEach(e => console.log(e.split('\n').slice(0, 6).join('\n')));

  ws.close(); chrome.kill();
  try { fs.rmSync(udd, { recursive: true, force: true }); } catch (e) {}
  process.exit(0);
})();
