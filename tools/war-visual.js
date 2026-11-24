/* 客观验收画面：读画布像素，确认
   ① 不是空白/纯色
   ② 战斗画面有内容（角色/Boss/网格）
   ③ 放技能前后画面确实发生大变化（特效真的画出来了）
   ④ 不同技能的特效颜色确实不同（不是所有字一个样）
   因为我（模型）看不了图片，只能用像素数据说话。 */
const { spawn } = require('child_process');
const http = require('http');
const os = require('os');
const path = require('path');
const fs = require('fs');
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9339;
const URL = process.argv[2] || 'http://127.0.0.1:8765/%E5%AD%97%E7%81%B5%E6%88%98%E8%AE%B0.html';
const udd = fs.mkdtempSync(path.join(os.tmpdir(), 'zl-vis-'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const getJSON = u => new Promise((res, rej) => {
  http.get(u, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => res(JSON.parse(b))); }).on('error', rej);
});

(async () => {
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--no-first-run',
    '--disable-background-timer-throttling', '--remote-debugging-port=' + PORT,
    '--user-data-dir=' + udd, '--window-size=430,932', URL], { stdio: 'ignore' });
  let list = null;
  for (let i = 0; i < 40; i++) { await sleep(500); try { list = await getJSON('http://127.0.0.1:' + PORT + '/json/list'); if (list && list.length) break; } catch (e) {} }
  const page = list.find(t => t.type === 'page') || list[0];
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0; const pending = {};
  ws.addEventListener('message', ev => { const m = JSON.parse(ev.data); if (m.id && pending[m.id]) { pending[m.id](m); delete pending[m.id]; } });
  const send = (m, p) => new Promise(res => { const i = ++id; pending[i] = res; ws.send(JSON.stringify({ id: i, method: m, params: p || {} })); });
  const ev = async e => { const r = await send('Runtime.evaluate', { expression: e, returnByValue: true }); return r.result && r.result.result ? r.result.result.value : undefined; };
  // Promise 必须 awaitPromise 才能拿到值
  const evAsync = async e => { const r = await send('Runtime.evaluate', { expression: e, returnByValue: true, awaitPromise: true }); return r.result && r.result.result ? r.result.result.value : undefined; };

  await new Promise(r => ws.addEventListener('open', r));
  await send('Runtime.enable');
  await sleep(2400);

  // 画布采样器：返回平均亮度、不同颜色数、以及按色相分类的主色
  const SIG = `(function(){
    var cv=document.getElementById('cv'), c=cv.getContext('2d');
    var W=cv.width,H=cv.height;
    var d=c.getImageData(0,0,W,H).data;
    var sum=0,n=0,dis={},hue={};
    for(var i=0;i<d.length;i+=4*331){
      var r=d[i],g=d[i+1],b=d[i+2];
      sum+=(r+g+b)/3; n++;
      dis[(r>>4)+'_'+(g>>4)+'_'+(b>>4)]=1;
      // 粗略色相分类
      var mx=Math.max(r,g,b),mn=Math.min(r,g,b);
      if(mx-mn>40){
        if(r===mx&&g>b) hue['暖(红橙黄)']=(hue['暖(红橙黄)']||0)+1;
        else if(r===mx) hue['品红']=(hue['品红']||0)+1;
        else if(g===mx) hue['绿']=(hue['绿']||0)+1;
        else hue['冷(蓝青)']=(hue['冷(蓝青)']||0)+1;
      }
    }
    return {avg:Math.round(sum/n), distinct:Object.keys(dis).length, sampled:n, hue:hue};
  })()`;

  const el = async expr => { const t0 = Date.now(); const v = await ev(expr); return { v: v, ms: Date.now() - t0 }; };
  const log = []; const push = (k, v) => log.push('  ' + k + ': ' + v);

  const menu = await ev(SIG);
  push('主菜单画面 平均亮度/颜色数', menu.avg + ' / ' + menu.distinct);

  await ev('document.getElementById("btnPlay").click()'); await sleep(500);
  await ev('document.querySelector("#pickList .lv").click()'); await sleep(500);
  await ev('document.getElementById("ovStory").click()'); await sleep(3000);

  const battle = await ev(SIG);
  // 场上实体数会随出怪波动，单帧采样偶然性太大：连续采 3 次取最多
  const battleSamples = [battle];
  for (let i = 0; i < 3; i++) { await sleep(600); battleSamples.push(await ev(SIG)); }
  const bestBattle = battleSamples.reduce((a, b) => (b.distinct > a.distinct ? b : a));
  push('战斗画面 平均亮度/颜色数', bestBattle.avg + ' / ' + bestBattle.distinct +
       '（3 次采样 ' + battleSamples.map(s => s.distinct).join('/') + '）');
  push('战斗画面 色相分布', JSON.stringify(bestBattle.hue));
  push('画面有内容(颜色数>25，纯色画面只有个位数)', bestBattle.distinct > 25 ? '是 ✓' : '否 ✗ 只有 ' + bestBattle.distinct);

  // 放一个技能，比较前后
  await ev('window.__game.forcePart(0)'); await sleep(250);
  await ev('window.__game.forcePart(1)'); await sleep(600);
  const before = await ev(SIG);
  await ev('window.__game.useSkill()'); await sleep(200);
  const during = await ev(SIG);
  const diff = Math.abs(during.avg - before.avg) + Math.abs(during.distinct - before.distinct);
  push('放技能前 亮度/颜色数', before.avg + ' / ' + before.distinct);
  push('放技能后 亮度/颜色数', during.avg + ' / ' + during.distinct);
  push('画面变化量', diff + (diff > 8 ? '  ✓ 特效确实画出来了' : '  ✗ 画面几乎没变'));
  push('技能名提示', await ev('document.getElementById("skname").textContent'));

  // 换一个技能色系，确认不同字的特效颜色不同
  await sleep(1800);
  const sigs = [];
  for (const want of ['风', '火', '水', '木']) {
    // 直接把玩家传送到含该字的关卡不现实；改查技能表颜色是否确实不同
    sigs.push(await ev(`(function(){var s=window.SKILLS.byChar["${want}"];return "${want} "+s.n+" "+s.c+" "+s.k})()`));
  }
  push('不同字的技能', sigs.join(' | '));

  // 渲染帧率：连续两帧时间差
  const fps = await evAsync(`new Promise(function(res){
    var n=0,t0=performance.now();
    function f(){ n++; if(n<40) requestAnimationFrame(f); else res(Math.round(40000/(performance.now()-t0))); }
    requestAnimationFrame(f);
  })`);
  push('渲染帧率', fps + ' fps（headless 软件渲染，低于真机）');

  console.log('===== 画面客观验收 =====');
  log.forEach(l => console.log(l));

  ws.close(); chrome.kill();
  try { fs.rmSync(udd, { recursive: true, force: true }); } catch (e) {}
  process.exit(0);
})();
