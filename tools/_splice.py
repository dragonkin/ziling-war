# -*- coding: utf-8 -*-
"""把新段落嵌进 字灵战记.html，替换 [start_marker, end_marker) 之间的内容。"""
import io, sys, os

sys.stdout.reconfigure(encoding='utf-8')
APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def splice(html_path, new_text, start_marker, end_marker):
    s = io.open(html_path, encoding='utf-8').read()
    i = s.find(start_marker)
    j = s.find(end_marker)
    if i < 0:
        raise SystemExit('找不到起始标记: ' + start_marker[:60])
    if j < 0:
        raise SystemExit('找不到结束标记: ' + end_marker[:60])
    if j <= i:
        raise SystemExit('标记顺序不对')
    out = s[:i] + new_text + s[j:]
    io.open(html_path, 'w', encoding='utf-8').write(out)
    return len(s), len(out)

if __name__ == '__main__':
    which = sys.argv[1]
    html = os.path.join(APP, '字灵战记.html')
    if which == 'audio':
        new = io.open(os.path.join(APP, 'tools', '_audio.js'), encoding='utf-8').read()
        a, b = splice(html, new,
                      '  /* ============================================================\n     9.5 音效',
                      '  /* ============================================================\n     10. 渲染')
    elif which == 'render':
        new = io.open(os.path.join(APP, 'tools', '_render3d.js'), encoding='utf-8').read()
        a, b = splice(html, new,
                      '  /* ============================================================\n     10. 渲染',
                      '  /* ============================================================\n     11. UI')
    else:
        raise SystemExit('未知段落: ' + which)
    print('%s: %d -> %d 字符' % (which, a, b))
