// 校验 data/curriculum.js 能否被浏览器式加载，并核对内容
global.window = {};
require('E:/AI agent/deepseek work/软件work/data/curriculum.js');
const c = global.window.CURRICULUM;
const bad = [];
let total = 0;
for (const b of c.books) {
  total += b.chars.length;
  for (const d of b.chars) {
    if (!d.c || d.c.length !== 1 || !/[\u4e00-\u9fff]/.test(d.c)) bad.push([b.book, 'char', d.c]);
    if (!d.py || /[\u4e00-\u9fff]/.test(d.py)) bad.push([b.book, 'py', d.c, d.py]);
  }
}
console.log('version   :', c.version);
console.log('domain    :', c.domain);
console.log('books     :', c.books.length);
console.log('total字   :', total);
console.log('每册      :', c.books.map(b => b.book + '=' + b.chars.length).join(' '));
console.log('已验证册  :', c.books.filter(b => b.verified).length, '/', c.books.length);
console.log('异常条目  :', bad.length, bad.slice(0, 5));
console.log('抽样      :', c.books[0].chars.slice(0, 8).map(d => d.c + '(' + d.py + ')').join(' '));
