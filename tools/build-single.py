# -*- coding: utf-8 -*-
"""把 index.html + style.css + data/*.js + app.js 打包成单文件「字灵图鉴.html」。
之前是手工拼的，容易和主版本脱节；固化成脚本，两版就永远一致。

用法： python tools/build-single.py
"""
import os, re, io, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)

def rd(p):
    return open(os.path.join(APP, p), encoding='utf-8').read()

html = rd('index.html')
css = rd('style.css')

# 1) 内联样式
html = html.replace('<link rel="stylesheet" href="style.css">',
                    '<style>\n' + css + '\n</style>')

# 2) 单文件不该依赖外部图标/清单（拷走一个文件也要能用）
html = re.sub(r'\n<link rel="manifest"[^>]*>', '', html)
html = re.sub(r'\n<link rel="apple-touch-icon"[^>]*>', '', html)
html = re.sub(r'\n<link rel="icon"[^>]*>', '', html)

# 3) 内联脚本，保持原有顺序（chars -> expand -> app）
order = ['data/chars.js', 'data/expand.js', 'app.js']
for src in order:
    tag = '<script src="%s"></script>' % src
    if tag not in html:
        raise SystemExit('index.html 里找不到 ' + tag)
    html = html.replace(tag, '<script>\n' + rd(src) + '\n</script>')

# 4) 打包标记
stamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
html = html.replace('<title>字灵图鉴</title>',
                    '<title>字灵图鉴</title>\n<!-- 单文件构建 · ' + stamp +
                    ' · 由 tools/build-single.py 生成，请勿手工编辑 -->')

out = os.path.join(APP, '字灵图鉴.html')
open(out, 'w', encoding='utf-8').write(html)

kb = os.path.getsize(out) / 1024.0
print('ok  %s  %.1f KB' % (out, kb))
print('   脚本 %d 个, 样式 %d 字符' % (len(order), len(css)))
