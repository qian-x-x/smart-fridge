"""Render the versioned beginner guide to Word using python-docx.

Usage: python scripts/Build-TechnicalGuide.py
The Markdown is the content source. Rendering to page images is a separate QA step.
"""

from pathlib import Path
import re

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.opc.constants import RELATIONSHIP_TYPE as RT
from docx.shared import Cm, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/交付/小易冰箱技术介绍.md"
TARGET = SOURCE.with_suffix(".docx")


def font(run, size=None, bold=None, color=None, mono=False):
    run.font.name = "Consolas" if mono else "Microsoft YaHei"
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), "微软雅黑")
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if color:
        run.font.color.rgb = RGBColor.from_string(color)


def inline(paragraph, text, size=None, bold=False):
    for piece in re.split(r"(\*\*.*?\*\*|`[^`]+`|\[[^\]]+\]\(https?://[^)]+\))", text):
        link = re.fullmatch(r"\[([^\]]+)\]\((https?://[^)]+)\)", piece)
        if link:
            relation = paragraph.part.relate_to(link[2], RT.HYPERLINK, is_external=True)
            element = OxmlElement("w:hyperlink")
            element.set(qn("r:id"), relation)
            run = OxmlElement("w:r")
            props = OxmlElement("w:rPr")
            color = OxmlElement("w:color")
            color.set(qn("w:val"), "98502E")
            props.append(color)
            run.append(props)
            label = OxmlElement("w:t")
            label.text = link[1]
            run.append(label)
            element.append(run)
            paragraph._p.append(element)
            continue
        marked = piece.startswith("**") and piece.endswith("**")
        mono = piece.startswith("`") and piece.endswith("`")
        body = piece[2:-2] if marked else piece[1:-1] if mono else piece
        run = paragraph.add_run(body)
        font(run, size, bold or marked, mono=mono)


def table(document, rows):
    parsed = [[cell.strip() for cell in row.strip().strip("|").split("|")] for row in rows]
    parsed = [row for row in parsed if not all(re.fullmatch(r":?-+:?", c) for c in row)]
    cols = len(parsed[0])
    obj = document.add_table(rows=0, cols=cols)
    obj.autofit = False
    widths = [3.6, 5.0, 8.4] if cols == 3 else [5.5, 11.5]
    for column, width in zip(obj.columns, widths):
        column.width = Cm(width)
    for index, values in enumerate(parsed):
        cells = obj.add_row().cells
        trpr = obj.rows[-1]._tr.get_or_add_trPr()
        no_split = OxmlElement("w:cantSplit")
        trpr.append(no_split)
        if index == 0:
            repeat = OxmlElement("w:tblHeader")
            trpr.append(repeat)
        for col, (cell, value) in enumerate(zip(cells, values)):
            cell.width = Cm(widths[col])
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            tcpr = cell._tc.get_or_add_tcPr()
            shading = OxmlElement("w:shd")
            shading.set(qn("w:fill"), "F2E7DD" if index == 0 else ("FAF8F4" if index % 2 else "FFFFFF"))
            tcpr.append(shading)
            margins = OxmlElement("w:tcMar")
            for edge, width in [("top", "45"), ("bottom", "45"), ("left", "75"), ("right", "75")]:
                el = OxmlElement("w:" + edge)
                el.set(qn("w:w"), width)
                el.set(qn("w:type"), "dxa")
                margins.append(el)
            tcpr.append(margins)
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(1)
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.line_spacing = 1.12
            inline(p, value, 9.3, bold=index == 0)
    document.add_paragraph().paragraph_format.space_after = Pt(1)


def main():
    document = Document()
    sec = document.sections[0]
    sec.page_width, sec.page_height = Cm(21), Cm(29.7)
    sec.top_margin, sec.bottom_margin = Cm(1.7), Cm(1.7)
    sec.left_margin, sec.right_margin = Cm(2), Cm(2)
    sec.footer_distance = Cm(0.7)
    normal = document.styles["Normal"]
    normal.font.name = "Microsoft YaHei"
    normal._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), "微软雅黑")
    normal.font.size = Pt(10.5)
    normal.paragraph_format.line_spacing = 1.18
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.widow_control = True
    normal.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
    for name, size, color in [("Title", 27, "000000"), ("Heading 1", 18, "000000"), ("Heading 2", 12, "A34F30")]:
        style = document.styles[name]
        style.font.name = "Microsoft YaHei"
        style._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), "微软雅黑")
        style.font.size = Pt(size)
        style.font.color.rgb = RGBColor.from_string(color)
        style.paragraph_format.space_before = Pt(9 if name != "Title" else 16)
        style.paragraph_format.space_after = Pt(6)
        style.paragraph_format.keep_with_next = True
        style.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
    # Some Word templates carry a decorative line in the Title style.
    # Remove inherited paragraph borders as well as directly formatted borders.
    for border in document.styles._element.xpath(".//w:pBdr"):
        border.getparent().remove(border)
    for border in document._element.xpath(".//w:pBdr"):
        border.getparent().remove(border)
    document.core_properties.title = "小易冰箱技术介绍"
    document.core_properties.subject = "面向技术新手的功能与实现说明"
    document.core_properties.author = "小易冰箱项目"
    document.core_properties.keywords = "Flutter, Feign, Sentinel, Seata, SkyWalking, 家庭冰箱"
    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    font(footer.add_run("小易冰箱技术介绍   "), 8, color="777777")
    field = OxmlElement("w:fldSimple")
    field.set(qn("w:instr"), "PAGE")
    footer._p.append(field)

    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        if line == "<!-- page -->":
            document.add_page_break()
        elif line.startswith("| "):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i])
                i += 1
            table(document, rows)
            continue
        elif line.startswith("```"):
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                p = document.add_paragraph()
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.line_spacing = 1.05
                p.paragraph_format.left_indent = Cm(0.3)
                font(p.add_run(lines[i]), 9, mono=True)
                i += 1
        elif line.startswith("# "):
            document.add_paragraph(line[2:], "Title")
        elif line.startswith("## "):
            document.add_paragraph(line[3:], "Heading 1")
        elif line.startswith("### "):
            document.add_paragraph(line[4:], "Heading 2")
        else:
            p = document.add_paragraph()
            if line.startswith("- "):
                line = "• " + line[2:]
            inline(p, line)
        i += 1
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    document.save(TARGET)
    print(f"Created {TARGET} ({TARGET.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
