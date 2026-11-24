  /* ============================================================
     10. 软件 3D 渲染
     自己写的透视投影 + 画家算法 + 逐面光照，纯 Canvas 2D。
     不用 WebGL / three.js：headless 软件渲染也能跑满帧，验收才做得下去。
     世界坐标：x 左右 · y 高度（0 = 地面）· z 远近（越大越远）
     相机在 (0, CAM_Y, 0) 朝 +z 看，所以：
       屏幕 y = HORIZON + (CAM_Y - wy) * FOV / wz
     ============================================================ */
  var Z_NEAR = 260, Z_FAR = 900, FOV = 520, CAM_Y = 267, HORIZON = 226;
  var FOG = [26, 35, 64];

  /* 游戏坐标 y（FIELD_TOP 最远、FIELD_BOT 最近）→ 世界深度 z */
  function depthOf(gy) {
    var k = (gy - FIELD_TOP) / (FIELD_BOT - FIELD_TOP);
    if (k < -1.1) k = -1.1;
    if (k > 1.25) k = 1.25;
    return Z_FAR - k * (Z_FAR - Z_NEAR);
  }
  function WX(gx) { return gx - VW / 2; }
  function P(wx, wy, wz) {
    var d = wz < 70 ? 70 : wz;
    var s = FOV / d;
    return { x: VW / 2 + wx * s, y: HORIZON + (CAM_Y - wy) * s, s: s, d: d };
  }
  function fogOf(wz) {
    var f = (wz - 330) / 600;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }
  function hx(h) {
    var n = parseInt(h.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  /* 一个颜色同时处理：受光强弱 k + 远处混雾 fog */
  function col3(hex, k, fog) {
    var c = hx(hex), r = c[0], g = c[1], b = c[2];
    if (k > 0) { r += (255 - r) * k; g += (255 - g) * k; b += (255 - b) * k; }
    else if (k < 0) { r *= 1 + k; g *= 1 + k; b *= 1 + k; }
    if (fog) { r += (FOG[0] - r) * fog; g += (FOG[1] - g) * fog; b += (FOG[2] - b) * fog; }
    return 'rgb(' + (r | 0) + ',' + (g | 0) + ',' + (b | 0) + ')';
  }
  function poly(pts, fill, stroke, lw) {
    ctx.beginPath();
    ctx.moveTo(pts[0].x, pts[0].y);
    for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
    ctx.closePath();
    ctx.fillStyle = fill; ctx.fill();
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw || 1; ctx.stroke(); }
  }

  /* 有厚度的方块：只画看得见的三面，顺序必须是 侧面 → 顶面 → 正面 */
  function box3(wx, wyBase, wz, w, h, d, hex, o) {
    o = o || {};
    var hw = w / 2, hd = d / 2, f = o.fog === undefined ? fogOf(wz) : o.fog;
    var x0 = wx - hw, x1 = wx + hw, y0 = wyBase, y1 = wyBase + h;
    var z0 = wz - hd, z1 = wz + hd;                 // z0 是朝着镜头的近侧
    if (o.shade !== false) {
      if (Math.abs(wx) > w * 0.34) {                // 正对镜头时侧面是一条线，别画
        var sx = wx > 0 ? x0 : x1;
        poly([P(sx, y0, z0), P(sx, y1, z0), P(sx, y1, z1), P(sx, y0, z1)],
             col3(hex, o.kSide === undefined ? -0.36 : o.kSide, f));
      }
      poly([P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)],
           col3(hex, o.kTop === undefined ? 0.30 : o.kTop, f));
    }
    poly([P(x0, y0, z0), P(x1, y0, z0), P(x1, y1, z0), P(x0, y1, z0)],
         o.flat ? hex : col3(hex, o.kFront === undefined ? 0.03 : o.kFront, f),
         o.stroke ? col3(hex, -0.55, f) : null, o.lw || 1);
  }

  /* 地面上的圆 → 投影成真正的透视椭圆（范围技、冲击波全靠它） */
  function disc3(gx, gy, r, fill, alpha, lift) {
    var wx = WX(gx), z = depthOf(gy);
    var pts = [];
    for (var i = 0; i < 15; i++) {
      var a = i / 15 * 6.2832;
      pts.push(P(wx + Math.cos(a) * r, lift || 0, z + Math.sin(a) * r * 0.9));
    }
    ctx.globalAlpha = alpha === undefined ? 1 : alpha;
    poly(pts, fill);
    ctx.globalAlpha = 1;
  }

  /* ============================================================
     天空：一次性画进离屏画布，之后每帧只 drawImage
     ============================================================ */
  var skyCache = null;
  function buildSky() {
    var s = document.createElement('canvas');
    s.width = VW; s.height = HORIZON + 6;
    var c = s.getContext('2d');
    var g = c.createLinearGradient(0, 0, 0, HORIZON);
    g.addColorStop(0, '#05081a');
    g.addColorStop(0.42, '#101a3e');
    g.addColorStop(0.74, '#252552');
    g.addColorStop(1, '#4a3157');
    c.fillStyle = g; c.fillRect(0, 0, VW, HORIZON + 6);

    // 星星
    var seed = 12345;
    function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }
    for (var i = 0; i < 130; i++) {
      var x = rnd() * VW, y = rnd() * HORIZON * 0.8, r = rnd() * 1.3 + 0.3;
      c.globalAlpha = 0.25 + rnd() * 0.7;
      c.fillStyle = rnd() > 0.85 ? '#ffe9b0' : '#dfeaff';
      c.beginPath(); c.arc(x, y, r, 0, 6.2832); c.fill();
    }
    c.globalAlpha = 1;

    // 月亮 + 光晕
    var mx = VW * 0.76, my = HORIZON * 0.30, mr = 34;
    var halo = c.createRadialGradient(mx, my, mr * 0.6, mx, my, mr * 4.6);
    halo.addColorStop(0, 'rgba(255,244,208,.34)');
    halo.addColorStop(0.4, 'rgba(255,230,180,.10)');
    halo.addColorStop(1, 'rgba(255,230,180,0)');
    c.fillStyle = halo; c.beginPath(); c.arc(mx, my, mr * 4.6, 0, 6.2832); c.fill();
    c.fillStyle = '#fff6d8'; c.beginPath(); c.arc(mx, my, mr, 0, 6.2832); c.fill();
    c.fillStyle = 'rgba(226,214,180,.5)';
    c.beginPath(); c.arc(mx - 10, my - 8, 6, 0, 6.2832); c.fill();
    c.beginPath(); c.arc(mx + 9, my + 6, 4.5, 0, 6.2832); c.fill();
    c.beginPath(); c.arc(mx + 2, my - 14, 3, 0, 6.2832); c.fill();

    // 云带
    for (var j = 0; j < 5; j++) {
      var cy = HORIZON * (0.42 + j * 0.075), cw = 150 + rnd() * 230, cx = rnd() * VW;
      var cg = c.createLinearGradient(0, cy - 9, 0, cy + 9);
      cg.addColorStop(0, 'rgba(120,110,170,0)');
      cg.addColorStop(0.5, 'rgba(140,130,190,' + (0.10 + rnd() * 0.09) + ')');
      cg.addColorStop(1, 'rgba(120,110,170,0)');
      c.fillStyle = cg; c.fillRect(cx - cw / 2, cy - 9, cw, 18);
    }

    // 远山三层（越近越暗，做大气透视）
    function ridge(baseY, amp, col, step) {
      c.fillStyle = col;
      c.beginPath(); c.moveTo(0, HORIZON + 6);
      for (var x = 0; x <= VW; x += step) {
        var y = baseY - Math.sin(x / 118) * amp - Math.cos(x / 47) * amp * 0.42
                - Math.sin(x / 23) * amp * 0.16;
        c.lineTo(x, y);
      }
      c.lineTo(VW, HORIZON + 6); c.closePath(); c.fill();
    }
    ridge(HORIZON * 0.66, 40, '#232a52', 16);
    ridge(HORIZON * 0.80, 30, '#191f3c', 14);
    ridge(HORIZON * 0.93, 20, '#0f1428', 12);

    // 塔与牌楼剪影
    function pagoda(px, baseY, sc, col) {
      c.fillStyle = col;
      for (var f = 0; f < 3; f++) {
        var w = (44 - f * 10) * sc, h = 13 * sc, y = baseY - f * 21 * sc;
        c.fillRect(px - w / 2, y - h, w, h);
        c.beginPath();
        c.moveTo(px - w / 2 - 7 * sc, y - h);
        c.lineTo(px + w / 2 + 7 * sc, y - h);
        c.lineTo(px + w / 2 - 1 * sc, y - h - 8 * sc);
        c.lineTo(px - w / 2 + 1 * sc, y - h - 8 * sc);
        c.closePath(); c.fill();
      }
      c.fillRect(px - 2.5 * sc, baseY - 3 * sc, 5 * sc, 3 * sc);
    }
    pagoda(VW * 0.13, HORIZON * 0.90, 1.15, '#0c1124');
    pagoda(VW * 0.90, HORIZON * 0.86, 0.85, '#0c1124');
    // 牌楼
    c.fillStyle = '#0b1020';
    c.fillRect(VW * 0.35, HORIZON * 0.80, 8, HORIZON * 0.20);
    c.fillRect(VW * 0.51, HORIZON * 0.80, 8, HORIZON * 0.20);
    c.fillRect(VW * 0.33, HORIZON * 0.78, VW * 0.20, 7);
    c.fillRect(VW * 0.335, HORIZON * 0.72, VW * 0.19, 6);
    return s;
  }
  function drawSky() {
    if (!skyCache) skyCache = buildSky();
    ctx.drawImage(skyCache, 0, 0);
  }

  /* ============================================================
     地面：透视网格 + 雾 + 边界辉光
     ============================================================ */
  function drawGround() {
    var g = ctx.createLinearGradient(0, HORIZON, 0, VH);
    g.addColorStop(0, '#1b2942');
    g.addColorStop(0.24, '#16273a');
    g.addColorStop(1, '#0a1420');
    ctx.fillStyle = g;
    ctx.fillRect(0, HORIZON + 2, VW, VH - HORIZON - 2);

    // 地平线辉光
    var hg = ctx.createLinearGradient(0, HORIZON - 14, 0, HORIZON + 26);
    hg.addColorStop(0, 'rgba(150,120,190,0)');
    hg.addColorStop(0.5, 'rgba(170,140,210,.24)');
    hg.addColorStop(1, 'rgba(150,120,190,0)');
    ctx.fillStyle = hg; ctx.fillRect(0, HORIZON - 14, VW, 40);

    // 横线（等 z）
    var i, z, p0, p1;
    ctx.lineWidth = 1;
    for (i = 0; i <= 13; i++) {
      z = Z_NEAR + (Z_FAR - Z_NEAR) * Math.pow(i / 13, 1.5);
      p0 = P(-520, 0, z); p1 = P(520, 0, z);
      var a = 0.20 * (1 - fogOf(z) * 0.85);
      ctx.strokeStyle = 'rgba(120,205,255,' + a.toFixed(3) + ')';
      ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
    }
    // 纵线（等 x）：投影后自然汇聚到灭点
    for (i = -6; i <= 6; i++) {
      var wx = i * 80;
      var za = Z_NEAR, zb = Z_FAR;
      var q0 = P(wx, 0, za), q1 = P(wx, 0, zb);
      ctx.strokeStyle = 'rgba(120,205,255,.13)';
      ctx.beginPath(); ctx.moveTo(q0.x, q0.y); ctx.lineTo(q1.x, q1.y); ctx.stroke();
    }

    // 场地边界两条发光竖线（玩法范围的可视化）
    [-1, 1].forEach(function (sgn) {
      var bx = sgn * (VW / 2 - 6);
      var t0 = P(bx, 0, Z_NEAR), t1 = P(bx, 0, Z_FAR);
      var lg = ctx.createLinearGradient(t0.x, t0.y, t1.x, t1.y);
      lg.addColorStop(0, 'rgba(140,230,255,.30)');
      lg.addColorStop(1, 'rgba(140,230,255,0)');
      ctx.strokeStyle = lg; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(t0.x, t0.y); ctx.lineTo(t1.x, t1.y); ctx.stroke();
    });
    // 近端边界
    var n0 = P(-VW / 2, 0, Z_NEAR), n1 = P(VW / 2, 0, Z_NEAR);
    ctx.strokeStyle = 'rgba(140,230,255,.16)'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(n0.x, n0.y); ctx.lineTo(n1.x, n1.y); ctx.stroke();
  }

  /* ============================================================
     角色：全部用方块拼，带走路摆动、朝向、受击闪白
     ============================================================ */
  function figure3(gx, gy, o) {
    var z = o.z === undefined ? depthOf(gy) : o.z;
    var wx = WX(gx);
    var f = fogOf(z);
    var H = o.h;
    var hurt = o.hurt > 0;
    var lift = o.lift || 0;
    var sw = Math.sin(o.step || 0);
    var walk = (o.moving ? 1 : 0) * sw;

    var legH = H * 0.28, bodyH = H * 0.33, headH = H * 0.24;
    var bodyW = H * 0.34, bodyD = H * 0.24;
    var headW = H * 0.30, headD = H * 0.26;
    var pal = hurt ? '#ffffff' : null;
    function C(hex) { return pal || hex; }

    // 影子（先画，压在地上）
    disc3(gx, gy, H * 0.30, 'rgba(0,0,0,.42)', 0.55);
    disc3(gx, gy, H * 0.44, 'rgba(0,0,0,.20)', 0.35);

    var y = lift;
    // 腿
    var legW = H * 0.115, legGap = H * 0.085;
    box3(wx - legGap, y, z, legW, legH, legW, C(o.leg || '#1b2340'), { fog: f, kSide: -0.4 });
    box3(wx + legGap, y, z, legW, legH, legW, C(o.leg || '#1b2340'), { fog: f, kSide: -0.4 });
    y += legH * 0.92;

    // 躯干
    box3(wx, y, z, bodyW, bodyH, bodyD, C(o.body), { fog: f });
    // 腰带
    box3(wx, y + bodyH * 0.62, z, bodyW * 1.04, bodyH * 0.16, bodyD * 1.05, C(o.trim || '#0d1428'),
         { fog: f, kTop: 0.2 });

    // 手臂（攻击时前伸）
    var armH = bodyH * 0.78, armW = H * 0.10;
    var armOut = H * 0.205;
    var aoff = o.atk > 0 ? H * 0.16 : 0;
    box3(wx - armOut, y + bodyH * 0.14, z + (o.atk > 0 && o.face < 0 ? aoff : 0) - (o.atk > 0 && o.face < 0 ? 0 : 0),
         armW, armH, armW, C(o.body), { fog: f, kSide: -0.22 });
    box3(wx + armOut, y + bodyH * 0.14, z, armW, armH, armW, C(o.body), { fog: f, kSide: -0.22 });

    var headY = y + bodyH * 0.94;
    // 头
    box3(wx, headY, z, headW, headH, headD, C(o.head), { fog: f });
    // 眼睛（贴在正面）
    var eyeW = headW * 0.19, eyeH = headH * 0.20;
    var eyeZ = z - headD / 2 - 1;
    var ex = headW * 0.19, ey = headY + headH * 0.52;
    var ecol = hurt ? '#ffdddd' : (o.eye || '#ffffff');
    box3(wx - ex, ey, eyeZ, eyeW, eyeH, 2, ecol, { fog: f, shade: false, flat: true });
    box3(wx + ex, ey, eyeZ, eyeW, eyeH, 2, ecol, { fog: f, shade: false, flat: true });
    // 瞳孔（朝向）
    var px = wx + (o.face || 1) * headW * 0.06;
    box3(px - ex, ey + eyeH * 0.16, eyeZ - 1, eyeW * 0.5, eyeH * 0.55, 2, '#08101f',
         { fog: f, shade: false, flat: true });
    box3(px + ex, ey + eyeH * 0.16, eyeZ - 1, eyeW * 0.5, eyeH * 0.55, 2, '#08101f',
         { fog: f, shade: false, flat: true });

    if (o.horns) {
      var hz = z - headD * 0.2;
      box3(wx - headW * 0.34, headY + headH * 0.9, hz, headW * 0.13, headH * 0.6, headD * 0.3,
           o.hornCol || '#ffe0b0', { fog: f, kSide: -0.1 });
      box3(wx + headW * 0.34, headY + headH * 0.9, hz, headW * 0.13, headH * 0.6, headD * 0.3,
           o.hornCol || '#ffe0b0', { fog: f, kSide: -0.1 });
    }
    if (o.scarf) {          // 围巾 / 披风：身后一块飘动
      var sc = Math.sin((o.step || 0) * 0.7) * H * 0.03;
      box3(wx - (o.face || 1) * H * 0.06, y + bodyH * 0.55 + sc, z + bodyD * 0.5,
           H * 0.20, H * 0.30, H * 0.04, o.scarf, { fog: f, kSide: -0.3, kTop: 0.18 });
    }
    if (o.crown) {          // 妖王头顶的环
      var cy = headY + headH + H * 0.06;
      box3(wx, cy, z, headW * 1.7, H * 0.035, headD * 1.7, o.crown, { fog: f, kTop: 0.4 });
    }
    return { headY: headY, headH: headH, z: z, wx: wx, fog: f };
  }

  /* 在世界坐标的某一点上画一段 2D 内容（汉字、血条这类广告牌） */
  function billboard(gx, gy, wy, scale, fn) {
    var p = P(WX(gx), wy, depthOf(gy));
    ctx.save();
    ctx.translate(p.x, p.y);
    var s = p.s * (scale || 1);
    ctx.scale(s, s);
    fn(s);
    ctx.restore();
    return p;
  }

  function drawPlayer() {
    var p = player;
    var f = figure3(p.x, p.y, {
      h: 62, body: '#2ee0c4', head: '#ffd9ab', trim: '#0a2a2e',
      eye: '#ffffff', step: p.step, moving: Math.hypot(stick.x, stick.y) > 0.15 || keys['a'] || keys['d'] || keys['w'] || keys['s'],
      face: p.face, atk: p.atk, hurt: p.hurt, scarf: '#ff5a7a', leg: '#123a3a'
    });
    // 攻击弧光（3D 里贴在地面高度扫过）
    if (p.atk > 0) {
      var k = 1 - p.atk / 0.16;
      var cx = WX(p.x), cz = depthOf(p.y);
      var pts = [];
      for (var i = 0; i <= 9; i++) {
        var a = -1.1 + i / 9 * 2.2;
        var ax = a * p.face;
        pts.push(P(cx + Math.sin(ax) * 86, 30 + Math.cos(a) * 8, cz - Math.cos(ax) * 40 * 0.35));
      }
      ctx.globalAlpha = 0.9 * (1 - k * 0.6);
      ctx.strokeStyle = '#fff5c0'; ctx.lineWidth = 6 - k * 2;
      ctx.beginPath();
      pts.forEach(function (q, i) { i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y); });
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
    if (p.dead) {
      ctx.globalAlpha = 0.35;
      var pp = P(WX(p.x), 90, depthOf(p.y));
      ctx.fillStyle = 'rgba(255,120,120,.9)';
      ctx.font = '900 34px system-ui,sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('✖', pp.x, pp.y);
      ctx.globalAlpha = 1;
    }
  }

  var BOSS_Z = 600;                          // 妖王固定悬停在场地后方，够大才有压迫感

  function drawBoss() {
    var b = boss;
    var lift = 26 + Math.sin(b.bob) * 7;
    /* 妖王只有一头一影，没有纵深排序问题：直接给它一个固定 z，比按 y 推更稳 */
    var info = figure3(b.x, b.y, {
      z: BOSS_Z, h: 132, body: '#3a1020', head: '#5a1830', trim: '#ff3355',
      eye: '#ff3a3a', horns: true, hornCol: '#ffd8a8', crown: 'rgba(255,80,110,.55)',
      step: b.bob, lift: lift, hurt: b.hurt, face: -1, leg: '#240a14'
    });

    // 脚下法阵（真正的透视椭圆环）
    disc3(b.x, b.y, 96, 'rgba(255,60,90,.16)', 0.9, 0);
    var pul = 0.6 + 0.4 * Math.sin(Date.now() / 260);
    ctx.save();
    ctx.globalAlpha = 0.5 * pul;
    ctx.strokeStyle = '#ff5577'; ctx.lineWidth = 2;
    var zB = depthOf(b.y), wxB = WX(b.x);
    for (var r2 = 0; r2 < 2; r2++) {
      var rad = 104 + r2 * 22;
      ctx.beginPath();
      for (var i = 0; i <= 22; i++) {
        var a = i / 22 * 6.2832;
        var q = P(wxB + Math.cos(a) * rad, 1, zB + Math.sin(a) * rad * 0.9);
        i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
      }
      ctx.closePath(); ctx.stroke();
    }
    ctx.restore();

    // 头顶妖气
    var pp = P(wxB, 132 + lift + 40, BOSS_Z);
    var gg = ctx.createRadialGradient(pp.x, pp.y, 2, pp.x, pp.y, 78 * pp.s);
    gg.addColorStop(0, 'rgba(255,60,90,.32)');
    gg.addColorStop(1, 'rgba(255,60,90,0)');
    ctx.fillStyle = gg;
    ctx.beginPath(); ctx.arc(pp.x, pp.y, 78 * pp.s, 0, 6.2832); ctx.fill();
  }

  function drawEnemy(e) {
    var elite = e.elite;
    figure3(e.x, e.y, {
      h: elite ? 68 : 58,
      body: elite ? '#c84a4a' : '#8a52c8',
      head: elite ? '#ffb0b0' : '#d8aef2',
      trim: '#2a1436', eye: elite ? '#fff6a0' : '#ffe14a',
      step: e.bob, hurt: e.hurt, face: e.face, leg: '#241436'
    });
    // 头顶部件
    if (e.carry) {
      var t = curTarget();
      var ch = e.carry === 'p0' ? t.parts[0] : e.carry === 'p1' ? t.parts[1] : '?';
      var wob = Math.sin(e.bob * 1.4) * 3;
      billboard(e.x, e.y, (elite ? 68 : 58) + 30 + wob, 1.0, function () {
        var bad = e.carry === 'bad';
        var col = bad ? '#ff9a9a' : '#bfe4ff';
        roundRect(-17, -16, 34, 32, 8);
        ctx.fillStyle = bad ? 'rgba(60,14,20,.94)' : 'rgba(8,20,38,.94)'; ctx.fill();
        ctx.strokeStyle = bad ? 'rgba(255,150,150,.95)' : 'rgba(140,215,255,.95)';
        ctx.lineWidth = 2.4; roundRect(-17, -16, 34, 32, 8); ctx.stroke();
        ctx.fillStyle = col;
        ctx.font = '900 21px system-ui,sans-serif';
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText(ch, 0, 1);
      });
    }
    // 血条（只在掉血后显示），贴在头顶上方
    if (e.hp < e.maxhp) {
      var wy = (elite ? 68 : 58) + (e.carry ? 52 : 18);
      billboard(e.x, e.y, wy, 1.0, function () {
        var r = Math.max(0, e.hp / e.maxhp);
        ctx.fillStyle = 'rgba(0,0,0,.55)'; ctx.fillRect(-22, -3, 44, 6);
        ctx.fillStyle = r > 0.5 ? '#5be08f' : '#ffb44a';
        ctx.fillRect(-22, -3, 44 * r, 6);
      });
    }
  }

  function drawDrop(d) {
    var yBase = 30 + d.z * 0.5 + Math.abs(Math.sin(d.t * 5)) * 10;
    var spin = d.t * 2.4;
    var z = depthOf(d.y), wx = WX(d.x), f = fogOf(z);
    var col = d.ok ? '#ffd964' : '#ff9a9a';
    var sz = 30;

    // 影子 + 地面光斑
    disc3(d.x, d.y, 13, 'rgba(0,0,0,.35)', 0.5);
    disc3(d.x, d.y, 26, d.ok ? 'rgba(255,214,100,.16)' : 'rgba(255,140,140,.14)', 0.85);

    ctx.save();
    ctx.globalAlpha = 0.5;
    box3(wx, yBase - 3, z, sz * 0.9, 6, sz * 0.9, col, { fog: f, kTop: 0.5 });
    ctx.restore();
    box3(wx, yBase, z, sz, sz, sz, col, { fog: f, stroke: true, kTop: 0.36, kSide: -0.3 });

    // 正面贴字（随旋转做左右偏移，看起来在转）
    var off = Math.sin(spin) * sz * 0.35;
    billboard(d.x + off * 0.5, d.y, yBase + sz * 0.5, 1.0, function () {
      ctx.fillStyle = d.ok ? '#5a3600' : '#5a1010';
      ctx.font = '900 21px system-ui,sans-serif';
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(d.ch, 0, 1);
    });
  }

  function drawBullets() {
    for (var i = 0; i < bullets.length; i++) {
      var b = bullets[i];
      var wy = 56 + Math.sin(b.t * 5) * 5;
      var z = depthOf(b.y), wx = WX(b.x), f = fogOf(z);
      disc3(b.x, b.y, 16, 'rgba(0,0,0,.30)', 0.5);
      // 近似球体：三个叠方块做出体积
      var s = 17;
      box3(wx, wy - s, z, s * 2, s * 2, 4, b.col, { fog: f, kTop: 0.42, kFront: 0.1, kSide: -0.2 });
      box3(wx - s * 0.55, wy - s * 0.95, z - s * 0.6, s * 1.5, s * 1.9, 3, b.col,
           { fog: f, kTop: 0.3, kFront: 0.02, kSide: -0.3 });
      billboard(b.x, b.y, wy + 1, 0.95, function () {
        ctx.fillStyle = 'rgba(10,14,26,.92)';
        ctx.beginPath(); ctx.arc(0, 0, 15, 0, 6.2832); ctx.fill();
        ctx.fillStyle = b.col;
        ctx.font = '900 20px system-ui,sans-serif';
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillText(b.ch, 0, 1);
      });
    }
  }

  function drawFx() {
    for (var i = 0; i < fx.length; i++) {
      var f = fx[i], k = f.t / f.dur;
      if (f.type === 'ring') {                       // 地面扩散环：最像 3D 的一个
        var r = f.rad + k * 250;
        ctx.save();
        ctx.globalAlpha = Math.max(0, 0.9 - k);
        ctx.strokeStyle = f.col; ctx.lineWidth = 8 * (1 - k) + 2;
        var pts = [];
        for (var q = 0; q <= 20; q++) {
          var a = q / 20 * 6.2832;
          pts.push(P(WX(f.x) + Math.cos(a) * r, 2, depthOf(f.y) + Math.sin(a) * r * 0.9));
        }
        ctx.beginPath();
        pts.forEach(function (pp, q2) { q2 ? ctx.lineTo(pp.x, pp.y) : ctx.moveTo(pp.x, pp.y); });
        ctx.stroke();
        ctx.restore();
        continue;
      }
      var wy = f.wy === undefined ? 28 : f.wy;
      var p = P(WX(f.x), wy, depthOf(f.y));
      var sc = p.s;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.scale(sc, sc);

      if (f.type === 'p') {
        ctx.globalAlpha = Math.max(0, 1 - k);
        ctx.fillStyle = f.col;
        ctx.beginPath(); ctx.arc(0, 0, f.r, 0, 6.2832); ctx.fill();
      } else if (f.type === 'band') {
        ctx.globalAlpha = Math.max(0, 0.85 - k * 0.85);
        ctx.fillStyle = f.col;
        ctx.fillRect(-46, -f.h / 2, 92, f.h);
        ctx.globalAlpha = Math.max(0, 0.5 - k * 0.5);
        ctx.fillRect(-70, -f.h / 4, 140, f.h / 2);
      } else if (f.type === 'spin') {
        ctx.globalAlpha = Math.max(0, 0.9 - k);
        ctx.strokeStyle = f.col; ctx.lineWidth = 5;
        for (var s2 = 0; s2 < 4; s2++) {
          ctx.beginPath();
          for (var a2 = 0; a2 < 14; a2++) {
            var ang = a2 / 14 * 6.283 + s2 * 1.57 + k * 16;
            var rr = 20 + a2 * 10 + k * 70;
            var xx = Math.cos(ang) * rr, yy = Math.sin(ang) * rr * 0.5;
            if (a2 === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
          }
          ctx.stroke();
        }
      } else if (f.type === 'bolt') {                // 从天而降，落到地面
        var top = P(WX(f.x), 620, depthOf(f.y)), bot = P(WX(f.x), 0, depthOf(f.y));
        ctx.globalAlpha = Math.max(0, f.life);
        ctx.strokeStyle = f.col; ctx.lineWidth = 4 * sc;
        ctx.beginPath();
        var seg = 8, cx2 = top.x, cy2 = top.y;
        ctx.moveTo(cx2, cy2);
        for (var s3 = 1; s3 <= seg; s3++) {
          cx2 = top.x + (bot.x - top.x) * s3 / seg + (Math.random() - 0.5) * 22 * sc;
          cy2 = top.y + (bot.y - top.y) * s3 / seg;
          ctx.lineTo(cx2, cy2);
        }
        ctx.stroke();
        ctx.globalAlpha *= 0.35; ctx.lineWidth *= 3;
        ctx.stroke();
      } else if (f.type === 'rain') {
        ctx.globalAlpha = 0.9;
        ctx.fillStyle = f.col;
        ctx.beginPath(); ctx.arc(0, 0, f.r, 0, 6.2832); ctx.fill();
        ctx.globalAlpha = 0.35;
        ctx.fillRect(-1.5, -f.r * 3.4, 3, f.r * 3);
      } else if (f.type === 'vine') {
        ctx.globalAlpha = Math.max(0, 0.95 - k * 0.7);
        ctx.strokeStyle = f.col; ctx.lineWidth = 9;
        var hh = f.h * Math.min(1, k * 2.4);
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(Math.sin(k * 6) * 12, -hh); ctx.stroke();
        ctx.lineWidth = 4; ctx.strokeStyle = '#ffffff';
        ctx.globalAlpha *= 0.35;
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(Math.sin(k * 6) * 12, -hh); ctx.stroke();
      } else if (f.type === 'fall') {
        ctx.globalAlpha = 0.95;
        ctx.fillStyle = f.col;
        ctx.save(); ctx.rotate(k * 4);
        ctx.fillRect(-f.r, -f.r * 0.8, f.r * 2, f.r * 1.6);
        ctx.restore();
      } else if (f.type === 'blade') {
        ctx.globalAlpha = Math.max(0, 0.95 - k);
        ctx.strokeStyle = f.col; ctx.lineWidth = 6;
        ctx.beginPath(); ctx.arc(0, 0, 20, -1.1, 1.1); ctx.stroke();
      } else if (f.type === 'beam') {
        ctx.globalAlpha = Math.max(0, 0.9 - k);
        var L = 520, th = 30 * (1 - k * 0.5);
        var gr = ctx.createLinearGradient(0, 0, f.face * L, 0);
        gr.addColorStop(0, f.col); gr.addColorStop(1, 'rgba(255,255,255,0)');
        ctx.fillStyle = gr;
        ctx.fillRect(f.face > 0 ? 0 : -L, -th / 2, L, th);
      } else if (f.type === 'fist') {
        ctx.globalAlpha = Math.max(0, 0.95 - k * 0.8);
        ctx.fillStyle = f.col;
        ctx.beginPath(); ctx.ellipse(f.face * 56, 0, 50 * (1 - k * 0.3), 36 * (1 - k * 0.3), 0, 0, 6.2832); ctx.fill();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 3; ctx.stroke();
      } else if (f.type === 'dash') {
        ctx.globalAlpha = Math.max(0, 0.85 - k);
        ctx.strokeStyle = f.col; ctx.lineWidth = 8;
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(-f.vx * 9, 0); ctx.stroke();
      } else if (f.type === 'cloud') {
        ctx.globalAlpha = Math.max(0, 0.8 - k * 0.8);
        ctx.fillStyle = f.col;
        ctx.beginPath(); ctx.arc(0, 0, f.r + k * f.grow * 20, 0, 6.2832); ctx.fill();
      }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  /* ============================================================
     画面合成
     ============================================================ */
  var vignette = null;
  function buildVignette() {
    var v = document.createElement('canvas');
    v.width = VW; v.height = VH;
    var c = v.getContext('2d');
    var g = c.createRadialGradient(VW / 2, VH * 0.42, VH * 0.28, VW / 2, VH * 0.5, VH * 0.80);
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(1, 'rgba(0,0,0,.46)');
    c.fillStyle = g; c.fillRect(0, 0, VW, VH);
    return v;
  }

  function render() {
    ctx.save();
    if (shake > 0) ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);

    drawSky();
    drawGround();

    if (state === 'play' || state === 'clear' || state === 'actbreak') {
      var list = [];
      list.push({ y: player.y, f: drawPlayer });
      if (boss && boss.alive) list.push({ y: boss.y, f: drawBoss });
      for (var i = 0; i < enemies.length; i++) list.push({ y: enemies[i].y, f: drawEnemy, o: enemies[i] });
      for (var j = 0; j < drops.length; j++) list.push({ y: drops[j].y, f: drawDrop, o: drops[j] });
      list.sort(function (a, b) { return depthOf(b.y) - depthOf(a.y); });   // 远→近，画家算法
      list.forEach(function (it) { it.f(it.o); });
      drawFx();
      drawBullets();

      for (var m = 0; m < floats.length; m++) {
        var fl = floats[m];
        var p = P(WX(fl.x), fl.wy === undefined ? 62 : fl.wy, depthOf(fl.y));
        ctx.save();
        ctx.globalAlpha = Math.min(1, fl.life * 1.5);
        ctx.translate(p.x, p.y);
        ctx.scale(p.s, p.s);
        ctx.font = '900 ' + Math.round(18 * fl.scale) + 'px system-ui,sans-serif';
        ctx.textAlign = 'center';
        ctx.lineWidth = 5; ctx.strokeStyle = 'rgba(0,0,0,.68)';
        ctx.strokeText(fl.text, 0, 0);
        ctx.fillStyle = fl.color; ctx.fillText(fl.text, 0, 0);
        ctx.restore();
      }
      ctx.globalAlpha = 1;
    }

    if (!vignette) vignette = buildVignette();
    ctx.drawImage(vignette, 0, 0);
    ctx.restore();

    if (flash > 0) {
      ctx.fillStyle = 'rgba(255,250,225,' + Math.min(0.8, flash * 0.55) + ')';
      ctx.fillRect(0, 0, VW, VH);
    }
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath(); ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }
