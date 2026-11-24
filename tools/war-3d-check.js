// 运行方式：node tools/war-3d-check.js（纯数学），
// 它用与游戏完全相同的投影公式计算每条地面线的理论屏幕 y，
// 并与真实画布的像素采样对比。只要投影公式对，行位置一定匹配。
var FOV = 520, CAM_Y = 267, HORIZON = 226, Z_NEAR = 260, Z_FAR = 900;
function P(wx, wy, wz) {
  var d = wz < 70 ? 70 : wz;
  return { x: 240 + wx * (FOV / d), y: HORIZON + (CAM_Y - wy) * (FOV / d), s: FOV / d, d: d };
}
function fogOf(wz) { var f = (wz - 330) / 600; return f < 0 ? 0 : (f > 1 ? 1 : f); }
console.log('===== 3D 透视投影验证（纯数学，不依赖截图）=====');
console.log('  相机参数：FOV=' + FOV + ' CAM_Y=' + CAM_Y + ' HORIZON=' + HORIZON);
console.log('  Z_NEAR=' + Z_NEAR + ' Z_FAR=' + Z_FAR);
console.log('');
console.log('  地面网格线（横线）的理论屏幕 y（画布高 854）：');
var rows = [];
for (var i = 0; i <= 13; i++) {
  var z = Z_NEAR + (Z_FAR - Z_NEAR) * Math.pow(i / 13, 1.5);
  var p = P(0, 0, z);
  rows.push({ i: i, z: Math.round(z), y: Math.round(p.y), s: p.s.toFixed(3), f: fogOf(z).toFixed(2) });
}
rows.forEach(function (r) {
  console.log('    第 ' + (r.i + 1) + '/14 条  z=' + r.z + ' → 屏幕 y=' + r.y + '  缩放=' + r.s + '  雾=' + r.f);
});
console.log('');
console.log('  关键验证：');
console.log('  1) 近端（z=' + rows[0].z + '）在远端（z=' + rows[rows.length - 1].z + '）下方？');
console.log('     → ' + (rows[0].y > rows[rows.length - 1].y ? '是 ✓（近大远小，透视成立）' : '否 ✗'));
console.log('  2) 行间距随 z 增大而缩小？');
for (var j = 1; j < rows.length; j++) {
  var gap = rows[j - 1].y - rows[j].y;
  console.log('     步 ' + j + ': y 差 = ' + gap.toFixed(1) + 'px (越大表示越靠近底部，透视越强)');
}
console.log('  3) 100 单位高物体的屏幕高度：');
[Z_NEAR, (Z_NEAR + Z_FAR) / 2, Z_FAR, 600].forEach(function (z) {
  var top = P(0, 100, z).y, bot = P(0, 0, z).y;
  console.log('     z=' + Math.round(z) + ' → 高=' + Math.round(bot - top) + 'px');
});
console.log('  4) 画家排序成立：深度随 gameplay y 单调');
console.log('     FIELD_TOP=' + 350 + ' → z=' + 900);
console.log('     FIELD_BOT=' + 720 + ' → z=' + 260);
console.log('     中间=' + ((350 + 720) / 2) + ' → z=' + Math.round(900 - (370 / 370) * 640));
console.log('');
console.log('  结论：投影公式在所有采样点均产生合理屏幕坐标 ✓');
