import re, pathlib, html as ihtml, base64, mimetypes

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
    t = re.sub(r"`(.+?)`", r'<code class="ic">\1</code>', t)
    return t

body = []
toc = []
chap_idx = 0
sec_idx = 0
fig_idx = 0
i = 0
n = len(lines)

while i < n:
    s = lines[i].rstrip()
    if not s.strip():
        i += 1
        continue

    # 代码块 → 逐行段落（避免超长段落与无 thead 表格）
    if s.startswith("```"):
        i += 1
        buf = []
        while i < n and not lines[i].startswith("```"):
            buf.append(lines[i].rstrip())
            i += 1
        i += 1
        buf = [b if b.strip() else " " for b in buf] or [" "]
        for k, code in enumerate(buf):
            cls = "code-line"
            if k == 0:
                cls += " first"
            if k == len(buf) - 1:
                cls += " last"
            body.append(f'<p class="{cls}">{ihtml.escape(code)}</p>')
        continue

    # 图片
    m = re.match(r"!\[(.*?)\]\((.*?)\)", s.strip())
    if m:
        alt, src = m.group(1), m.group(2)
        fig_idx += 1
        cls = "phone-img" if "手机" in alt else "shot-img"
        img_path = OUT.parent / src
        if img_path.exists():
            mime = mimetypes.guess_type(str(img_path))[0] or "image/png"
            src = "data:%s;base64,%s" % (mime, base64.b64encode(img_path.read_bytes()).decode("ascii"))
        body.append(f'<figure class="fig"><img class="{cls}" src="{src}" alt="{ihtml.escape(alt)}"/>'
                    f'<figcaption class="cap">图 {fig_idx}　{alt}</figcaption></figure>')
        i += 1
        continue

    # 一级小节 → h3
    if s.startswith("### "):
        txt = strip_num(s[4:])
        sec_idx += 1
        sid = f"section-{chap_idx}-{sec_idx}"
        body.append(f'<h3 id="{sid}" class="section">{paren_num(sec_idx)}{inline(txt)}</h3>')
        toc.append((2, sid, paren_num(sec_idx) + txt))
        i += 1
        continue

    # 章 → h2
    if s.startswith("## "):
        txt = strip_num(s[3:])
        chap_idx += 1
        sec_idx = 0
        cid = f"section-{chap_idx}"
        label = txt if txt.startswith("附录") else f"{cn_num(chap_idx)}、{txt}"
        body.append(f'<h2 id="{cid}" class="chapter">{inline(label)}</h2>')
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
        data = cells[2:] if len(cells) > 2 else []
        th = "".join(f'<th class="cell th">{inline(c)}</th>' for c in head)
        trs = []
        for r in data:
            tds = "".join(f'<td class="cell">{inline(c)}</td>' for c in r)
            trs.append(f"<tr>{tds}</tr>")
        body.append(f'<table class="tbl"><thead><tr>{th}</tr></thead><tbody>{"".join(trs)}</tbody></table>')
        continue

    # 无序列表
    if re.match(r"^\s*-\s+", s):
        items = []
        while i < n and re.match(r"^\s*-\s+", lines[i]):
            items.append(re.sub(r"^\s*-\s+", "", lines[i]).strip())
            i += 1
        lis = "".join(f'<li class="li">{inline(it)}</li>' for it in items)
        body.append(f'<ul class="ul">{lis}</ul>')
        continue

    # 有序列表
    if re.match(r"^\s*\d+\.\s+", s):
        items = []
        while i < n and re.match(r"^\s*\d+\.\s+", lines[i]):
            items.append(re.sub(r"^\s*\d+\.\s+", "", lines[i]).strip())
            i += 1
        lis = "".join(f'<li class="li">{inline(it)}</li>' for it in items)
        body.append(f'<ol class="ol">{lis}</ol>')
        continue

    body.append(f'<p class="body-p">{inline(s.strip())}</p>')
    i += 1

# ---- 目录 ----
toc_items = []
for lvl, cid, text in toc:
    if lvl == 1:
        toc_items.append(f'<li class="toc-l1"><a href="#{cid}">{text}</a></li>')
    else:
        toc_items.append(f'<li class="toc-l2"><a href="#{cid}">{text}</a></li>')

css = """
:root {
  --ff-body: "SimSun", 宋体, serif;
  --ff-head: "SimHei", 黑体, sans-serif;
  --ff-mono: Consolas, "Courier New", monospace;
  --fs-chapter: 17pt;
  --fs-section: 14pt;
  --fs-body: 12pt;
  --fs-table: 10.5pt;
  --fs-th: 10.5pt;
  --fs-code: 9.5pt;
  --fs-cap: 9.5pt;
  --fs-inline-code: 10.5pt;
  --fs-cover-s: 12pt;
  --fs-cover-xl: 35pt;
  --fs-cover-m: 15pt;
  --fs-cover-l: 26pt;
  --fs-cover-info: 10.5pt;
  --fs-toc-title: 16pt;
  --fs-toc-1: 12pt;
  --fs-toc-2: 11pt;
  --color-text: #1a1a1a;
  --color-sub: #3d3d3d;
  --color-weak: #6b6b6b;
  --color-border: #b9b2a2;
  --color-rule: #c9c1b2;
  --color-accent: #8a5a3b;
  --color-white: #ffffff;
  --color-thbg: #f3efe6;
  --color-codebg: #f6f4ef;
  --color-inlinebg: #f4f1ea;
  --sp-0: 0;
  --sp-2: 2pt;
  --sp-3: 3pt;
  --sp-5: 5pt;
  --sp-6: 6pt;
  --sp-7: 7pt;
  --sp-8: 8pt;
  --sp-10: 10pt;
  --sp-12: 12pt;
  --sp-14: 14pt;
  --sp-16: 16pt;
  --sp-18: 18pt;
  --sp-22: 22pt;
  --sp-26: 26pt;
  --sp-40: 40pt;
  --sp-95: 95pt;
  --sp-120: 120pt;
  --sp-135: 135pt;
}
* { box-sizing: border-box; margin: var(--sp-0); padding: var(--sp-0); }
body {
  font-family: var(--ff-body);
  font-size: var(--fs-body);
  line-height: 1.62;
  color: var(--color-text);
  background: var(--color-white);
  max-width: 15.6cm;
  margin: var(--sp-0) auto;
}
h1.cover-name {
  font-family: var(--ff-head);
  font-size: var(--fs-cover-xl);
  font-weight: 700;
  color: var(--color-text);
  text-align: center;
  text-indent: var(--sp-0);
  letter-spacing: 6pt;
  margin-top: var(--sp-26);
}
p.cover-brand, p.cover-tagline, p.cover-doc, p.cover-sub, p.cover-info {
  text-align: center;
  text-indent: var(--sp-0);
}
p.cover-brand {
  font-family: var(--ff-head);
  font-size: var(--fs-cover-s);
  color: var(--color-accent);
  letter-spacing: 6pt;
  margin-top: var(--sp-120);
}
p.cover-tagline {
  font-family: var(--ff-body);
  font-size: var(--fs-cover-m);
  color: var(--color-sub);
  letter-spacing: 3pt;
  margin-top: var(--sp-10);
}
p.cover-doc {
  font-family: var(--ff-head);
  font-size: var(--fs-cover-l);
  font-weight: 700;
  color: var(--color-text);
  letter-spacing: 8pt;
  margin-top: var(--sp-95);
}
p.cover-sub {
  font-size: var(--fs-cover-info);
  color: var(--color-weak);
  margin-top: var(--sp-14);
}
p.cover-info {
  font-size: var(--fs-cover-info);
  color: var(--color-weak);
  line-height: 2.1;
  margin-top: var(--sp-135);
}
h2.chapter {
  font-family: var(--ff-head);
  font-size: var(--fs-chapter);
  font-weight: 700;
  color: var(--color-text);
  text-indent: var(--sp-0);
  margin: var(--sp-22) var(--sp-0) var(--sp-10) var(--sp-0);
  padding-bottom: var(--sp-6);
  border-bottom: 1.2pt solid var(--color-rule);
}
h3.section {
  font-family: var(--ff-head);
  font-size: var(--fs-section);
  font-weight: 700;
  color: var(--color-text);
  text-indent: var(--sp-0);
  margin: var(--sp-16) var(--sp-0) var(--sp-8) var(--sp-0);
}
p.body-p {
  text-indent: 2em;
  text-align: justify;
  margin: var(--sp-0) var(--sp-0) var(--sp-8) var(--sp-0);
}
ul.ul, ol.ol { margin: var(--sp-0) var(--sp-0) var(--sp-10) var(--sp-0); padding-left: var(--sp-18); }
li.li { text-indent: var(--sp-0); margin-bottom: var(--sp-3); }
table.tbl {
  border-collapse: collapse;
  width: 100%;
  margin: var(--sp-6) var(--sp-0) var(--sp-12) var(--sp-0);
}
th.cell.th {
  font-family: var(--ff-head);
  font-size: var(--fs-th);
  font-weight: 700;
  color: var(--color-text);
  background: var(--color-thbg);
  border: 0.75pt solid var(--color-border);
  padding: var(--sp-5) var(--sp-6);
  text-align: left;
  text-indent: var(--sp-0);
}
td.cell {
  font-family: var(--ff-body);
  font-size: var(--fs-table);
  color: var(--color-text);
  border: 0.75pt solid var(--color-border);
  padding: var(--sp-5) var(--sp-6);
  text-indent: var(--sp-0);
  vertical-align: top;
}
p.code-line {
  font-family: var(--ff-mono);
  font-size: var(--fs-code);
  line-height: 1.5;
  color: var(--color-text);
  background: var(--color-codebg);
  text-indent: var(--sp-0);
  margin: var(--sp-0);
  padding: var(--sp-0) var(--sp-10);
  white-space: pre-wrap;
}
p.code-line.first { padding-top: var(--sp-6); border-top: 0.75pt solid var(--color-border); }
p.code-line.last { padding-bottom: var(--sp-6); border-bottom: 0.75pt solid var(--color-border); }
figure.fig { text-align: center; margin: var(--sp-8) var(--sp-0) var(--sp-10) var(--sp-0); }
img.shot-img { width: 100%; }
img.phone-img { width: 6.2cm; }
figcaption.cap {
  font-family: var(--ff-body);
  font-size: var(--fs-cap);
  color: var(--color-weak);
  text-align: center;
  text-indent: var(--sp-0);
  margin-top: var(--sp-5);
}
code.ic {
  font-family: var(--ff-mono);
  font-size: var(--fs-inline-code);
  background: var(--color-inlinebg);
}
nav.doc-toc { margin-top: var(--sp-40); }
p.toc-title {
  font-family: var(--ff-head);
  font-size: var(--fs-toc-title);
  font-weight: 700;
  text-align: center;
  text-indent: var(--sp-0);
  letter-spacing: 4pt;
  margin: var(--sp-0) var(--sp-0) var(--sp-14) var(--sp-0);
}
ol.toc-list, .toc-list ol, .toc-list ul { list-style: none; list-style-type: none; padding-left: var(--sp-0); }
li.toc-l1 {
  font-size: var(--fs-toc-1);
  font-weight: 700;
  text-indent: var(--sp-0);
  margin: var(--sp-7) var(--sp-0) var(--sp-3) var(--sp-0);
}
li.toc-l2 {
  font-size: var(--fs-toc-2);
  text-indent: var(--sp-0);
  margin: var(--sp-2) var(--sp-0) var(--sp-2) var(--sp-18);
}
li.toc-l1 a, li.toc-l2 a { color: var(--color-text); text-decoration: none; }

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
  <p class="cover-brand">XIAOYI FRIDGE</p>
  <h1 class="cover-name">小 易 冰 箱</h1>
  <p class="cover-tagline">查 食 材 ， 看 菜 谱 ， 都 容 易</p>
  <p class="cover-doc">使 用 说 明 书</p>
  <p class="cover-sub">项目初代作品 · 配套源码交付</p>
  <p class="cover-info">文档版本　V1.0（初代）<br/>技术构成　Flutter / Vue 3 / Spring Cloud<br/>编写日期　2026 年 11 月</p>
</section>
"""

toc_section = """
<section role="cover">
  <nav class="doc-toc" aria-label="文档目录">
    <p class="toc-title">目 录</p>
    <ol class="toc-list">
      %s
    </ol>
  </nav>
</section>
""" % "\n      ".join(toc_items)

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
<section role="body" data-page-restart="1" data-margin-top="2.54cm" data-margin-bottom="2.54cm" data-margin-left="3.17cm" data-margin-right="2.23cm">
{chr(10).join(body)}
</section>
</body>
</html>
"""

OUT.write_text(doc, encoding="utf-8")
print("chapters:", chap_idx, "toc items:", len(toc), "figures:", fig_idx, "size:", len(doc))
