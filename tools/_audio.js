  /* ============================================================
     9.5 音效 / 音乐：动作游戏没声音是不成立的。
          全部用 WebAudio 现场合成，零音频文件、零加载。
          结构：master → 压缩器 → 输出，另有一条混响支路（反馈延迟+低通）
          sfx 一律走 master，并按需送一点混响，避免干瘪。
     ============================================================ */
  var AC = null, muted = false, musicOn = true;
  try { muted = localStorage.getItem('ziling.war.mute') === '1'; } catch (e) {}
  try { musicOn = localStorage.getItem('ziling.war.music') !== '0'; } catch (e) {}

  var master = null, revIn = null, sfxBus = null, musicBus = null;

  function actx() {
    try {
      if (!AC) {
        var Ctor = window.AudioContext || window.webkitAudioContext;
        if (!Ctor) return null;
        AC = new Ctor();
        master = AC.createGain(); master.gain.value = 0.85;
        var comp = AC.createDynamicsCompressor();
        comp.threshold.value = -12; comp.ratio.value = 6;
        master.connect(comp); comp.connect(AC.destination);

        /* 混响：反馈延迟 + 低通，成本几乎为零，但空间感立刻出来 */
        revIn = AC.createGain(); revIn.gain.value = 1;
        var dly = AC.createDelay(0.6); dly.delayTime.value = 0.115;
        var fb = AC.createGain(); fb.gain.value = 0.34;
        var lp = AC.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2000;
        var wet = AC.createGain(); wet.gain.value = 0.42;
        revIn.connect(dly); dly.connect(lp); lp.connect(fb); fb.connect(dly);
        lp.connect(wet); wet.connect(master);

        sfxBus = AC.createGain(); sfxBus.gain.value = 1; sfxBus.connect(master);
        musicBus = AC.createGain(); musicBus.gain.value = 0.32; musicBus.connect(master);
      }
      if (AC.state === 'suspended' && AC.resume) AC.resume();
      return AC;
    } catch (e) { return null; }
  }

  /* 音高轻微抖动：同一音效连播几十次也不会腻 */
  function vary(f, cents) {
    return f * Math.pow(2, (Math.random() * 2 - 1) * (cents || 30) / 1200);
  }
  function tone(freq, dur, type, vol, slideTo, delay, wet, dest) {
    var a = actx();
    if (!a || muted) return;
    try {
      var t0 = a.currentTime + (delay || 0);
      var o = a.createOscillator(), g = a.createGain();
      o.type = type || 'square';
      o.frequency.setValueAtTime(Math.max(20, freq), t0);
      if (slideTo) o.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), t0 + dur);
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(Math.max(0.0002, vol || 0.1), t0 + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      o.connect(g);
      g.connect(dest || sfxBus || a.destination);
      if (wet) { var w = a.createGain(); w.gain.value = wet; g.connect(w); w.connect(revIn); }
      o.start(t0); o.stop(t0 + dur + 0.04);
    } catch (e) {}
  }
  /* 噪声：带通/低通可选，做打击、爆炸、风声、脚步 */
  function noise(dur, vol, o) {
    var a = actx();
    if (!a || muted) return;
    o = o || {};
    try {
      var n = Math.floor(a.sampleRate * dur);
      if (n < 1) return;
      var buf = a.createBuffer(1, n, a.sampleRate), d = buf.getChannelData(0);
      for (var i = 0; i < n; i++) {
        var k = 1 - i / n;
        d[i] = (Math.random() * 2 - 1) * (o.flat ? 1 : k * k);
      }
      var s = a.createBufferSource(), g = a.createGain();
      s.buffer = buf;
      var node = g;
      if (o.hz) {
        var f = a.createBiquadFilter();
        f.type = o.type || 'bandpass'; f.frequency.value = o.hz; f.Q.value = o.q || 1.2;
        g.connect(f); node = f;
      }
      g.gain.value = vol || 0.12;
      s.connect(g); node.connect(o.dest || sfxBus || a.destination);
      if (o.wet) { var w = a.createGain(); w.gain.value = o.wet; node.connect(w); w.connect(revIn); }
      s.start();
    } catch (e) {}
  }

  /* ------------------------------------------------------------
     音效表。分四层音量：反馈 0.05 / 打击 0.10 / 特殊 0.12 / 过场 0.14
     ------------------------------------------------------------ */
  function sfx(name, arg) {
    if (muted) return;
    var a = actx();
    if (!a) return;
    switch (name) {

      /* —— 战斗 —— */
      case 'swing':                                  // 挥空
        noise(0.09, 0.05, { hz: 1400, type: 'highpass', q: 0.7 });
        break;
      case 'hit': {                                  // 命中，音高随连击升高
        var step = Math.min(12, (arg || 0));
        var f = vary(330 * Math.pow(1.06, step));
        noise(0.06, 0.11, { hz: 900, q: 0.9 });
        tone(f, 0.07, 'square', 0.06, f * 0.45);
        break;
      }
      case 'crit': {                                 // 暴击
        noise(0.1, 0.13, { hz: 1500, q: 1 });
        tone(vary(900), 0.12, 'square', 0.08, 260);
        tone(vary(1800), 0.08, 'sine', 0.05, 900, 0.02, 0.3);
        break;
      }
      case 'ko':                                     // 击杀
        noise(0.18, 0.14, { hz: 500, q: 0.8 });
        tone(vary(180), 0.22, 'sawtooth', 0.08, 55);
        tone(vary(520), 0.14, 'triangle', 0.04, 160, 0.03, 0.35);
        break;
      case 'shatter':                                // 碎裂（妖王被打掉一格）
        noise(0.26, 0.15, { hz: 2600, type: 'highpass', q: 0.6, wet: 0.3 });
        tone(vary(1200), 0.2, 'triangle', 0.06, 300);
        break;
      case 'enemy':                                  // 妖怪冒出来
        tone(vary(300), 0.14, 'sawtooth', 0.05, 520);
        noise(0.1, 0.05, { hz: 800, q: 1 });
        break;
      case 'hurt':                                   // 玩家受伤
        noise(0.12, 0.09, { hz: 400, q: 0.8 });
        tone(230, 0.16, 'square', 0.08, 85);
        break;
      case 'shield':                                 // 无敌/格挡
        tone(1400, 0.18, 'sine', 0.06, 700, 0, 0.4);
        break;

      /* —— 收集 / 拼字 —— */
      case 'pick':
        tone(vary(760, 60), 0.09, 'sine', 0.09, 1140);
        tone(1140, 0.1, 'sine', 0.05, 0, 0.07, 0.25);
        break;
      case 'bad':
        tone(200, 0.15, 'triangle', 0.06, 130);
        tone(150, 0.2, 'sine', 0.04, 110, 0.05);
        break;
      case 'assemble':                               // 拼出字：上行琶音 = 成就感
        [660, 880, 1174, 1568].forEach(function (f, i) {
          tone(f, 0.16, 'sine', 0.09, f * 1.5, i * 0.075, 0.3);
        });
        tone(1320, 0.4, 'sine', 0.04, 1980, 0.3, 0.5);
        break;
      case 'oneself':                                // 独体字「找回」
        [523, 784, 1046].forEach(function (f, i) {
          tone(f, 0.2, 'triangle', 0.08, f * 1.25, i * 0.1, 0.35);
        });
        break;
      case 'newchar':                                // 第一次收集到这个字
        [880, 1320, 1760].forEach(function (f, i) {
          tone(f, 0.12, 'sine', 0.06, f * 1.2, i * 0.05, 0.4);
        });
        break;
      case 'drop':                                   // 部件掉出
        tone(vary(520, 50), 0.1, 'triangle', 0.05, 320);
        break;

      /* —— 技能 —— */
      case 'charge':                                 // 蓄力
        tone(180, 0.22, 'sine', 0.07, 920);
        noise(0.22, 0.05, { hz: 600, type: 'lowpass' });
        break;
      case 'skill':                                  // 放大招（按技能类型微调音色）
        tone(90, 0.5, 'sawtooth', 0.11, 820, 0, 0.45);
        noise(0.34, 0.1, { hz: 1200, q: 0.7, wet: 0.4 });
        tone(vary(1600, 80), 0.3, 'sine', 0.05, 2400, 0.05, 0.5);
        break;
      case 'skill_fire':
        noise(0.42, 0.13, { hz: 700, type: 'lowpass', wet: 0.35 });
        tone(120, 0.45, 'sawtooth', 0.09, 420);
        break;
      case 'skill_ice':
        [2100, 2600, 3100].forEach(function (f, i) { tone(f, 0.2, 'sine', 0.05, f * 0.7, i * 0.03, 0.5); });
        noise(0.3, 0.07, { hz: 4200, type: 'highpass' });
        break;
      case 'skill_thunder':
        noise(0.38, 0.16, { hz: 2000, q: 0.5, wet: 0.5 });
        tone(70, 0.5, 'square', 0.1, 40);
        tone(2400, 0.1, 'sine', 0.05, 600);
        break;
      case 'skill_nature':
        noise(0.4, 0.08, { hz: 500, type: 'lowpass', wet: 0.3 });
        tone(300, 0.3, 'triangle', 0.07, 700);
        break;
      case 'skill_beam':
        tone(280, 0.42, 'sawtooth', 0.09, 1800, 0, 0.4);
        noise(0.3, 0.06, { hz: 3200, type: 'highpass', wet: 0.4 });
        break;
      case 'skill_wind':
        noise(0.55, 0.09, { hz: 900, type: 'bandpass', q: 0.5, flat: true, wet: 0.5 });
        break;

      /* —— 妖王 —— */
      case 'bossIntro':
        tone(110, 0.9, 'sawtooth', 0.12, 55, 0, 0.7);
        tone(164, 0.9, 'sawtooth', 0.08, 82, 0.02, 0.7);
        noise(0.9, 0.08, { hz: 300, type: 'lowpass', wet: 0.6 });
        break;
      case 'bossCast':
        tone(420, 0.22, 'triangle', 0.07, 190, 0, 0.4);
        tone(630, 0.18, 'sine', 0.04, 300, 0.03, 0.4);
        break;
      case 'bosshit':
        noise(0.22, 0.13, { hz: 600, q: 0.8 });
        tone(85, 0.34, 'square', 0.1, 40);
        break;
      case 'bossDie':
        noise(0.9, 0.16, { hz: 800, q: 0.5, wet: 0.6 });
        tone(200, 1.0, 'sawtooth', 0.11, 40, 0, 0.7);
        tone(300, 0.7, 'square', 0.06, 60, 0.06, 0.7);
        break;

      /* —— 界面 / 流程 —— */
      case 'ui': tone(660, 0.05, 'sine', 0.05); break;
      case 'uiBack': tone(440, 0.08, 'sine', 0.05, 300); break;
      case 'story':
        [392, 523, 659].forEach(function (f, i) { tone(f, 0.5, 'sine', 0.06, 0, i * 0.12, 0.6); });
        break;
      case 'actClear':                               // 一幕完成
        [523, 659, 784, 1046, 1318].forEach(function (f, i) {
          tone(f, 0.24, 'triangle', 0.09, 0, i * 0.1, 0.45);
        });
        break;
      case 'clear':                                  // 整个单元通关
        [523, 659, 784, 1046, 1318, 1568, 2093].forEach(function (f, i) {
          tone(f, 0.5, 'sine', 0.1, 0, i * 0.13, 0.6);
        });
        noise(0.7, 0.06, { hz: 3000, type: 'highpass', wet: 0.5 });
        break;
      case 'revive':
        [300, 450, 700, 1000].forEach(function (f, i) { tone(f, 0.3, 'sine', 0.07, f * 1.3, i * 0.08, 0.5); });
        break;
      case 'warn':                                   // 血量低
        tone(880, 0.1, 'square', 0.05);
        tone(660, 0.14, 'square', 0.05, 0, 0.13);
        break;
      case 'step':
        noise(0.035, 0.028, { hz: 300, type: 'lowpass' });
        break;
      case 'combo': {                                // 连击里程碑
        var b = 440 * Math.pow(1.12, Math.min(20, arg || 0));
        [b, b * 1.5].forEach(function (f, i) { tone(f, 0.14, 'triangle', 0.07, f * 1.2, i * 0.05, 0.35); });
        break;
      }
    }
  }

  /* ------------------------------------------------------------
     背景音乐：程序化循环（低音 + 和弦垫 + 琶音），用前瞻调度器排音符
     两套：menu（安静）/ battle（紧张），按状态自动切换
     ------------------------------------------------------------ */
  var MUS = {
    menu: {
      bpm: 76, root: 220,
      chords: [[0, 3, 7], [-4, 0, 5], [-7, -3, 0], [-5, -1, 4]],
      arp: [0, 7, 12, 7, 3, 10, 15, 10]
    },
    battle: {
      bpm: 132, root: 165,
      chords: [[0, 3, 7], [0, 3, 7], [-2, 1, 5], [-5, -1, 2]],
      arp: [0, 12, 7, 15, 0, 12, 19, 15]
    }
  };
  var musTimer = null, musNext = 0, musStep = 0, musKind = null;

  function semi(f, n) { return f * Math.pow(2, n / 12); }
  function scheduleMusic() {
    var a = actx();
    if (!a || muted || !musicOn || !musKind) return;
    var cfg = MUS[musKind];
    var spb = 60 / cfg.bpm / 2;                    // 八分音符
    while (musNext < a.currentTime + 0.25) {
      var t = musNext - a.currentTime;
      var bar = Math.floor(musStep / 8) % cfg.chords.length;
      var ch = cfg.chords[bar];
      var s8 = musStep % 8;
      if (s8 === 0) {                              // 每小节：低音 + 和弦垫
        tone(semi(cfg.root / 2, ch[0]), spb * 7, 'triangle', 0.10, 0, t, 0.5, musicBus);
        ch.forEach(function (n, i) {
          tone(semi(cfg.root, n), spb * 7.5, 'sine', 0.045, 0, t + i * 0.01, 0.6, musicBus);
        });
      }
      var arpNote = semi(cfg.root, ch[0] + cfg.arp[s8]);
      tone(arpNote, spb * 0.9, 'square', musKind === 'battle' ? 0.035 : 0.026, 0, t, 0.4, musicBus);
      if (musKind === 'battle' && s8 % 4 === 2) {  // 战斗曲加军鼓
        noise(0.05, 0.04, { hz: 1800, type: 'highpass', dest: musicBus });
      }
      musStep++;
      musNext += spb;
    }
  }
  function setMusic(kind) {
    if (musKind === kind) return;
    musKind = kind;
    if (!kind) { if (musTimer) { clearInterval(musTimer); musTimer = null; } return; }
    var a = actx();
    if (!a) { musKind = null; return; }
    musNext = a.currentTime + 0.08; musStep = 0;
    if (!musTimer) musTimer = setInterval(scheduleMusic, 90);
  }
  function toggleMusic() {
    musicOn = !musicOn;
    try { localStorage.setItem('ziling.war.music', musicOn ? '1' : '0'); } catch (e) {}
    el('btnMusic').textContent = musicOn ? '🎵 音乐已开' : '🎵 音乐已关';
    if (musicOn) { actx(); var k = musKind; musKind = null; setMusic(k || 'menu'); }
  }

  function toggleMute() {
    muted = !muted;
    try { localStorage.setItem('ziling.war.mute', muted ? '1' : '0'); } catch (e) {}
    el('btnMute').textContent = muted ? '🔇 音效已关' : '🔊 音效已开';
    if (muted) { if (musTimer) { clearInterval(musTimer); musTimer = null; } musKind = null; }
    else { actx(); sfx('pick'); setMusic(state === 'play' ? 'battle' : 'menu'); }
  }
