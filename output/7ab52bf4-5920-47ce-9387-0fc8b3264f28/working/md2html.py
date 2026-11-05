import re, pathlib, html as ihtml

SRC = pathlib.Path(r"C:\Users\Lenovo\Desktop\软件开发实践\output\7ab52bf4-5920-47ce-9387-0fc8b3264f28\stage1\final_draft.md")
OUT = pathlib.Path(r"C:\Users\Lenovo\Desktop\软件开发实践\output\7ab52bf4-5920-47ce-9387-0fc8b3264f28\stage2\formatted-小易冰箱使用说明书.html")

lines = SRC.read_text(encoding="utf-8").split("\n")

def strip_num(t):
    return re.sub(r"^\s*\d+(\.\d+)*\s+", "", t).strip()

CN = "一二三四五六七八九十"
def cn_num(i):
    if i <= 10:
        return CN[i-1]
    if i < 20:
        return "十" + CN[i-11]
    return str(i)

def paren_num(i):
    return "（" + cn_num(i) + "）"

def inline(t):
    t = ihtml.escape(t, quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"`(.+?)`", r"<code>\1</code>", t)
    return t

body = []
toc = []          # (level, id, text)
chap_idx = 0
sec_idx = 0
fig_idx = 0
i = 0
n = len(lines)

while i < n:
    line = lines[i]
    s = line.rstrip()

    if not s.strip():
        i += 1
        continue

    # 代码块
    if s.startswith("```"):
        i += 1
        buf = []
        while i < n and not lines[i].startswith("```"):
            buf.append(lines[i].rstrip())
            i += 1
        i += 1
        code = "\n".join(buf)
        body.append(f'<p class="codeblock" style="font-family:Consolas,monospace;font-size:9.5pt;line-height:1.55;'
                    f'background:#f6f4ef;border:1px solid #d8d2c4;padding:9pt 11pt;text-indent:0;'
                    f'white-space:pre;margin:6pt 0 10pt 0;">{ihtml.escape(code)}</p>')
        continue

    # 图片
    m = re.match(r"!\[(.*?)\]\((.*?)\)", s.strip())
    if m:
        alt, src = m.group(1), m.group(2)
        fig_idx += 1
        cls = "phone-img" if "手机" in alt else "shot-img"
        body.append(
            f'<figure style="margin:10pt 0 12pt 0;text-align:center;">'
            f'<img class="{cls}" src="{src}" alt="{ihtml.escape(alt)}" style="display:block;margin:0 auto;"/>'
            f'<figcaption style="font-family:\'SimSun\',宋体,serif;font-size:9.5pt;color:#6b6b6b;'
            f'text-align:center;text-indent:0;margin-top:5pt;">图 {fig_idx}　{alt}</figcaption></figure>')
        i += 1
        continue

    # 标题
    if s.startswith("### "):
        txt = strip_num(s[4:])
        sec_idx += 1
        sid = f"section-{chap_idx}-{sec_idx}"
        body.append(f'<h2 id="{sid}" style="font-family:\'SimHei\',黑体,sans-serif;font-size:14pt;font-weight:700;'
                    f'color:#1a1a1a;text-indent:0;margin:16pt 0 8pt 0;">{paren_num(sec_idx)}{inline(txt)}</h2>')
        toc.append((2, sid, paren_num(sec_idx) + txt))
        i += 1
        continue

    if s.startswith("## "):
        txt = strip_num(s[3:])
        chap_idx += 1
        sec_idx = 0
        cid = f"section-{chap_idx}"
        label = txt if txt.startswith("附录") else f"{cn_num(chap_idx)}、{txt}"
        body.append(f'<h1 id="{cid}" style="font-family:\'SimHei\',黑体,sans-serif;font-size:17pt;font-weight:700;'
                    f'color:#1a1a1a;text-indent:0;margin:22pt 0 10pt 0;padding-bottom:6pt;'
                    f'border-bottom:1.2pt solid #c9c1b2;">{inline(label)}</h1>')
        toc.append((1, cid, label))
        i += 1
        continue

    if s.startswith("# "):
        i += 1
        continue

    # 表格
    if s.lstrip().startswith("|"):
        rows = []
        while i < n and lines[i].lstrip().startswith("|"):
            rows.append(lines[i].strip())
            i += 1
        cells = [[c.strip() for c in r.strip("|").split("|")] for r in rows]
        head = cells[0]
        data = [r for r in cells[2:]] if len(cells) > 1 else []
        th = "".join(
            f'<th style="font-family:\'SimHei\',黑体,sans-serif;font-size:10.5pt;font-weight:700;'
            f'background:#f3efe6;border:0.75pt solid #b9b2a2;padding:5pt 6pt;text-align:left;">{inline(c)}</th>'
            for c in head)
        trs = []
        for r in data:
            tds = "".join(
                f'<td style="font-family:\'SimSun\',宋体,serif;font-size:10.5pt;border:0.75pt solid #b9b2a2;'
                f'padding:5pt 6pt;text-indent:0;vertical-align:top;">{inline(c)}</td>' for c in r)
            trs.append(f"<tr>{tds}</tr>")
        body.append(f'<table style="border-collapse:collapse;width:100%;margin:6pt 0 12pt 0;">'
                    f'<thead><tr>{th}</tr></thead><tbody>{"".join(trs)}</tbody></table>')
        continue

    # 无序列表
    if re.match(r"^\s*-\s+", s):
        items = []
        while i < n and re.match(r"^\s*-\s+", lines[i]):
            items.append(re.sub(r"^\s*-\s+", "", lines[i]).strip())
            i += 1
        lis = "".join(
            f'<li style="font-family:\'SimSun\',宋体,serif;font-size:12pt;line-height:1.6;'
            f'text-indent:0;margin-bottom:3pt;">{inline(it)}</li>' for it in items)
        body.append(f'<ul style="margin:4pt 0 10pt 0;padding-left:20pt;">{lis}</ul>')
        continue

    # 有序列表
    if re.match(r"^\s*\d+\.\s+", s):
        items = []
        while i < n and re.match(r"^\s*\d+\.\s+", lines[i]):
            items.append(re.sub(r"^\s*\d+\.\s+", "", lines[i]).strip())
            i += 1
        lis = "".join(
            f'<li style="font-family:\'SimSun\',宋体,serif;font-size:12pt;line-height:1.6;'
            f'text-indent:0;margin-bottom:3pt;">{inline(it)}</li>' for it in items)
        body.append(f'<ol style="margin:4pt 0 10pt 0;padding-left:22pt;">{lis}</ol>')
        continue

    # 段落
    body.append(f'<p style="font-family:\'SimSun\',宋体,serif;font-size:12pt;line-height:1.62;'
                f'text-indent:2em;text-align:justify;margin:0 0 8pt 0;">{inline(s.strip())}</p>')
    i += 1

# ---- 目录 ----
toc_html = ['<p class="toc-title" style="font-family:\'SimHei\',黑体,sans-serif;font-size:16pt;'
            'font-weight:700;text-align:center;text-indent:0;margin:0 0 14pt 0;letter-spacing:4pt;">目 录</p>']
toc_html.append('<ol class="toc-list" style="list-style:none;padding-left:0;margin:0;">')
for lvl, cid, text in toc:
    if lvl == 1:
        toc_html.append(
            f'<li style="font-family:\'SimSun\',宋体,serif;font-size:12pt;text-indent:0;margin:7pt 0 3pt 0;'
            f'font-weight:700;"><a href="#{cid}" style="color:#1a1a1a;text-decoration:none;">{text}</a></li>')
    else:
        toc_html.append(
            f'<li style="font-family:\'SimSun\',宋体,serif;font-size:11pt;text-indent:0;margin:2pt 0 2pt 18pt;">'
            f'<a href="#{cid}" style="color:#444;text-decoration:none;">{text}</a></li>')
toc_html.append("</ol>")

css = """
:root {
  --fs-h1: 17pt;
  --fs-h2: 14pt;
  --fs-body: 12pt;
  --fs-small: 9.5pt;
  --ff-heading: "SimHei", 黑体, sans-serif;
  --ff-body: "SimSun", 宋体, serif;
  --lh-body: 1.62;
  --color-text: #1a1a1a;
  --color-muted: #6b6b6b;
  --color-border: #b9b2a2;
  --color-accent: #8a5a3b;
  --page-content-width: 15.6cm;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: "SimSun", 宋体, serif;
  font-size: 12pt;
  line-height: 1.62;
  color: #1a1a1a;
  background: #ffffff;
  max-width: 15.6cm;
  margin-left: auto;
  margin-right: auto;
}
img.shot-img { width: 100%; }
img.phone-img { width: 6.2cm; }
.toc-list, .toc-list ol, .toc-list ul { list-style: none; list-style-type: none; }
code { font-family: Consolas, monospace; font-size: 10.5pt; background: #f4f1ea; padding: 0 2pt; }

@page {
  @bottom-center { content: counter(page); }
}
@page cover {
  @bottom-center { content: none; }
}
section[role="cover"] { page: cover; }
"""

cover = """
<section role="cover">
  <p style="text-align:center;text-indent:0;font-family:'SimHei',黑体,sans-serif;font-size:12pt;
     letter-spacing:6pt;color:#8a5a3b;margin-top:120pt;">XIAOYI FRIDGE</p>
  <p style="text-align:center;text-indent:0;font-family:'SimHei',黑体,sans-serif;font-size:35pt;
     font-weight:700;letter-spacing:6pt;margin-top:26pt;">小 易 冰 箱</p>
  <p style="text-align:center;text-indent:0;font-family:'SimSun',宋体,serif;font-size:15pt;
     letter-spacing:3pt;color:#3d3d3d;margin-top:10pt;">查 食 材 ， 看 菜 谱 ， 都 容 易</p>
  <p style="text-align:center;text-indent:0;font-family:'SimHei',黑体,sans-serif;font-size:26pt;
     font-weight:700;letter-spacing:8pt;margin-top:95pt;">使 用 说 明 书</p>
  <p style="text-align:center;text-indent:0;font-family:'SimSun',宋体,serif;font-size:11.5pt;
     color:#5b5b5b;margin-top:14pt;">项目初代作品 · 配套源码交付</p>
  <table style="width:12.4cm;margin:140pt auto 0 auto;border-collapse:collapse;">
    <tr>
      <td style="font-family:'SimSun',宋体,serif;font-size:10.5pt;color:#6b6b6b;padding:5pt 0;
          text-indent:0;border-bottom:0.6pt solid #ddd6c8;width:4cm;">文档版本</td>
      <td style="font-family:'SimSun',宋体,serif;font-size:10.5pt;color:#1a1a1a;padding:5pt 0;
          text-indent:0;border-bottom:0.6pt solid #ddd6c8;">V1.0（初代）</td>
    </tr>
    <tr>
      <td style="font-family:'SimSun',宋体,serif;font-size:10.5pt;color:#6b6b6b;padding:5pt 0;
          text-indent:0;border-bottom:0.6pt solid #ddd6c8;">技术构成</td>
      <td style="font-family:'SimSun',宋体,serif;font-size:10.5pt;color:#1a1a1a;padding:5pt 0;
          text-indent:0;border-bottom:0.6pt solid #ddd6c8;">Flutter / Vue 3 / Spring Cloud</td>
    </tr>
    <tr>
      <td style="font-family:'SimSun',宋体,serif;font-size:10.5pt;color:#6b6b6b;padding:5pt 0;
          text-indent:0;border-bottom:0.6pt solid #ddd6c8;">编写日期</td>
      <td style="font-family:'SimSun',宋体,serif;font-size:10.5pt;color:#1a1a1a;padding:5pt 0;
          text-indent:0;border-bottom:0.6pt solid #ddd6c8;">2026 年 11 月</td>
    </tr>
  </table>
</section>
"""

toc_section = """
<section role="cover">
  <nav class="doc-toc" aria-label="文档目录" style="margin-top:40pt;">
    %s
  </nav>
</section>
""" % "\n    ".join(toc_html)

doc = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="docx-page-size" content="A4">
<title>小易冰箱 使用说明书</title>
<style>{css}</style>
</head>
<body>
{cover}
{toc_section}
<section role="body" data-page-restart="1">
{chr(10).join(body)}
</section>
</body>
</html>
"""

OUT.write_text(doc, encoding="utf-8")
print("chapters:", chap_idx, "sections:", len(toc), "size:", len(doc))
