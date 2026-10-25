from __future__ import annotations

import sys
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SPEC_PATH = ROOT / "可视化冰箱APP开发说明.docx"
OUTPUT_SPEC_PATH = ROOT / "可视化冰箱APP开发说明-V1.3.docx"
DESKTOP_CONCEPT = ROOT / "docs/design/webgl-concepts/01-home-closed.jpg"
MOBILE_CONCEPT = ROOT / "docs/design/webgl-concepts/04-mobile-closed.jpg"
FIGMA_URL = "https://www.figma.com/design/dBXCo4YNTagNNs5cnvONEq"


def set_paragraph_text(paragraph, text: str) -> None:
    if not paragraph.runs:
        paragraph.add_run(text)
        return
    paragraph.runs[0].text = text
    for run in paragraph.runs[1:]:
        run._element.getparent().remove(run._element)


def find_paragraph(document: Document, prefix: str):
    for paragraph in document.paragraphs:
        if paragraph.text.strip().startswith(prefix):
            return paragraph
    raise ValueError(f"Paragraph not found: {prefix}")


def shade_cell(cell, fill: str) -> None:
    properties = cell._tc.get_or_add_tcPr()
    shading = properties.find(qn("w:shd"))
    if shading is None:
        shading = OxmlElement("w:shd")
        properties.append(shading)
    shading.set(qn("w:fill"), fill)


def set_cell_text(cell, text: str, *, bold: bool = False, white: bool = False) -> None:
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = paragraph.add_run(text)
    run.bold = bold
    run.font.name = "Microsoft YaHei"
    run.font.size = Pt(9)
    if white:
        run.font.color.rgb = RGBColor(255, 255, 255)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def set_cell_margins(cell, top: int = 90, start: int = 100, bottom: int = 90, end: int = 100) -> None:
    properties = cell._tc.get_or_add_tcPr()
    margins = OxmlElement("w:tcMar")
    for edge, value in (
        ("top", top),
        ("start", start),
        ("bottom", bottom),
        ("end", end),
    ):
        node = OxmlElement(f"w:{edge}")
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")
        margins.append(node)
    properties.append(margins)


def remove_drawings(paragraph) -> None:
    for drawing in list(paragraph._p.xpath(".//w:drawing")):
        drawing.getparent().remove(drawing)


def normalized_visual_text(text: str) -> str:
    replacements = (
        ("米色复古", "香槟米色"),
        ("手绘贴纸形式", "实时 3D 食材模型与信息标签"),
        ("手绘贴纸", "3D 食材模型与信息标签"),
        ("食材贴纸", "食材模型"),
        ("贴纸源文件", "食材模型源文件"),
        ("分层插画", "实时 3D 场景"),
        ("贴纸", "食材模型"),
        ("2.5D", "WebGL 真 3D"),
    )
    for source, target in replacements:
        text = text.replace(source, target)
    return text


def add_caption(document: Document, text: str) -> None:
    paragraph = document.add_paragraph(text)
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(4)
    paragraph.paragraph_format.space_after = Pt(10)
    for run in paragraph.runs:
        run.font.size = Pt(9)
        run.font.color.rgb = RGBColor(89, 89, 89)


def add_picture_paragraph(document: Document, image_path: Path, width: float):
    paragraph = document.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(8)
    paragraph.paragraph_format.space_after = Pt(2)
    paragraph.add_run().add_picture(str(image_path), width=Inches(width))
    return paragraph


def add_visual_matrix(document: Document) -> None:
    rows = [
        ("视口 / 状态", "画面内容", "必须通过的交互验收"),
        (
            "Web 桌面 · 关门",
            "四门立式冰箱完整居中；上方左右双门、中部变温抽屉与下部冷冻抽屉清晰分层。",
            "拖拽旋转；点击门或抽屉进入对应状态；不得出现静态截图冒充实时 3D。",
        ),
        (
            "Web 桌面 · 左门开启",
            "左门绕铰链开启，露出内腔、透明层架、食材与柔和照明。",
            "开门后可返回关门态；鼠标命中区域与可见门体一致。",
        ),
        (
            "Web 桌面 · 抽屉开启",
            "中部抽屉沿滑轨向前拉出，可看到抽屉深度、轨道与食材。",
            "门与抽屉互斥切换；动画结束后保持稳定可操作状态。",
        ),
        (
            "移动端 · 首屏",
            "冰箱保持第一视觉，标题、温度切换、摘要与底栏不得遮挡模型。",
            "360 至 430 逻辑像素无横向溢出；触控旋转与点击可正常使用。",
        ),
    ]
    table = document.add_table(rows=len(rows), cols=3)
    table.style = "Table Grid"
    table.autofit = False
    widths = (1.45, 2.55, 2.65)
    for row_index, values in enumerate(rows):
        for column_index, value in enumerate(values):
            cell = table.cell(row_index, column_index)
            cell.width = Inches(widths[column_index])
            set_cell_margins(cell)
            is_header = row_index == 0
            set_cell_text(
                cell,
                value,
                bold=is_header,
                white=is_header,
            )
            if is_header:
                shade_cell(cell, "2F4B5C")
            elif row_index % 2 == 0:
                shade_cell(cell, "EDF3F6")
    document.add_paragraph()


def update_spec() -> None:
    document = Document(SOURCE_SPEC_PATH)

    replacements = {
        "项目必须形成一条可以完整演示的业务闭环": (
            "项目必须形成一条可以完整演示的业务闭环：家庭成员把食材和调料放入实时 "
            "WebGL 真 3D 冰箱，系统计算临期状态并推荐菜谱，做饭确认后自动扣减库存，"
            "库存不足时进入一键补货，订单提交时通过 Seata 协调库存与优惠券，"
            "再由消息中心通知家庭成员。该闭环同时承载课程要求的 Nacos、Gateway、"
            "OpenFeign、Sentinel、Seata、SkyWalking、Maven 多模块和 BOM。"
        ),
        "2.5D 冰箱首页必须": (
            "WebGL 真 3D 冰箱首页必须由实时几何模型、PBR 材质、场景灯光和可独立响应的"
            "门体/抽屉组成，不能用一张烘焙好的截图或分层插画替代 3D 交互。"
        ),
        "以 2.5D 冰箱视图": "以 WebGL 真 3D 冰箱视图和表格两种方式浏览食材。",
        "甲方提供项目主题": (
            "甲方提供项目主题、课程要求、功能清单和最终验收标准；产品文案可在开发中"
            "共同确认。"
        ),
        "参考小红书帖子只提供功能灵感": (
            "视觉设计不以任何外部帖子的版式或素材为依据；功能范围仅以本文件确认的"
            "条款为准。第三方素材必须具有明确授权。"
        ),
        "需求灵感来自两篇公开分享内容": (
            "本版不采用需求来源帖子的视觉版式、图片素材或界面结构。功能范围只以本文件"
            "列出的账号、家庭协作、冰箱分区、食材管理、临期提醒、菜谱推荐、库存扣减和"
            "补货交易为依据；视觉方向另行由 WebGL 3D 冰箱主视觉定义。"
        ),
        "4.2  2.5D 冰箱与食材管理": "4.2  WebGL 真 3D 冰箱与食材管理",
        "5  视觉与 2.5D 交互设计": "5  视觉与 WebGL 真 3D 交互设计",
        "方案 A 采用场景化正视图": (
            "方案 A 采用实时 WebGL 3D 正视图。主视觉是一台可旋转、可开门的四门立式冰箱："
            "上方为左右双开门，中部为变温抽屉，下部为宽冷冻抽屉。外壳使用香槟米色拉丝"
            "金属和深可可色把手，内部使用柔白照明、透明层架与低饱和食材材质。页面背景"
            "保持温暖米白，标题和数据使用深棕，临期状态使用陶土红。产品模型必须来自"
            "实时几何、PBR 材质和场景灯光，不能以静态截图冒充 3D。"
        ),
        "5.2  2.5D 实现约束": "5.2  WebGL 真 3D 实现约束",
        "不使用 Three.js、GLB 模型": (
            "Web 端使用 Three.js r180 与 WebGL2 实时渲染四门立式冰箱；Flutter 负责响应式"
            "外壳、可访问控件、数据状态和 3D 视口嵌入。Three.js 运行文件随 Web 构建产物"
            "本地打包，不依赖 CDN。"
        ),
        "首页拆成外壳层、腔体层": (
            "冰箱必须包含可辨识的真实体积：上方两扇带铰链的 French door、中部变温抽屉、"
            "下方冷冻抽屉、拉丝金属外壳、深可可色把手、内部层架和食材几何体。所有块面"
            "必须有合理厚度、倒角、接缝、接触阴影与金属反射。"
        ),
        "隔层滑出使用 AnimatedSlide": (
            "交互使用相机轨道、射线拾取和确定性状态动画。拖拽旋转视口；点击左门、右门、"
            "变温抽屉或冷冻抽屉时，仅打开目标部件；再次点击关闭。动画结束后必须保持稳定"
            "可操作状态，并能将区域选择同步回 Flutter 当前分区。"
        ),
        "贴纸位置由区域": (
            "食材改为 3D 场景中的真实几何对象或透明信息标签，不把大量 emoji 贴纸漂浮在"
            "关闭的门体表面。食材数据仍由区域、隔层、位置和层序共同决定；选中食材后打开"
            "Flutter 详情面板，保留记录使用、移动和吃完的入口。"
        ),
        "外壳与首个可见区域": (
            "Three.js 入口与核心模块内部控制压缩后总量不超过 1 MB；场景像素比不超过 2，"
            "阴影贴图不高于 2048。WebGL 不可用或模块加载失败时显示明确错误说明，并提供"
            "同数据的表格视图作为完整降级路径。"
        ),
        "使用 LayoutBuilder、MediaQuery": (
            "使用 LayoutBuilder、MediaQuery 和 SafeArea 适配 360 至 1440 像素宽度。"
            "桌面使用左侧导航、中央 3D 舞台和右侧状态栏；移动端保留底栏并将冰箱作为首屏"
            "主视觉。不得出现 RenderFlex overflow、文字遮挡、固定宽度裁切或模型底部被"
            "控件覆盖。"
        ),
        "甲方支付项目费用后": (
            "甲方支付项目费用后，定制代码、3D 模型、UI 文案、数据结构和项目文档的"
            "交付使用权归甲方所有；第三方开源依赖继续适用其许可证。"
        ),
        "参考帖中的原创图片": (
            "外部原创图片、UI 布局、文字和冰箱造型素材不得直接复用；功能关系可以"
            "独立实现，视觉资产必须具备明确授权。"
        ),
        "版本记录：V1.0": (
            "版本记录：V1.0 建立外包开发基线，明确可视化冰箱、手绘贴纸、家庭共享、"
            "菜谱扣减、补货交易和课程组件验收要求。V1.1 曾采用 2.5D 可视化路线。"
            "V1.2 将用户端技术基线改为 Flutter，统一 Android APK 与 Flutter Web/PWA 的"
            "交付、测试和验收要求。V1.3 于 2026-10-26 将冰箱首页升级为 WebGL 真 3D，"
            "采用真实四门立式冰箱、French door 与上下抽屉结构；设计只采用本文件功能，"
            "不采用需求来源帖子的视觉样式。"
        ),
    }

    for paragraph in document.paragraphs:
        text = paragraph.text.strip()
        for prefix, replacement in replacements.items():
            if text.startswith(prefix):
                set_paragraph_text(paragraph, replacement)
                break

    for paragraph in document.paragraphs:
        if "2.5D" not in paragraph.text:
            continue
        if paragraph.text.startswith("版本记录"):
            continue
        if paragraph.text.startswith("功能"):
            continue
        set_paragraph_text(
            paragraph,
            paragraph.text.replace("2.5D", "WebGL 真 3D"),
        )

    specific_cells = {
        "方案 A：米色复古 2.5D 立式冰箱正视图": (
            "方案 A（V1.3 起）：香槟米色 WebGL 真 3D 四门立式冰箱；"
            "使用实时几何、PBR 材质和真实灯光的门与抽屉交互。"
        ),
        "Flutter 3.x stable + Dart 3.x": (
            "Flutter 3.x stable + Dart 3.x；同一代码库构建 Android APK 与 "
            "Flutter Web/PWA；Web 端 3D 由 Three.js/WebGL2 完成。"
        ),
        "原型、2.5D 冰箱分层源文件": (
            "原型、Three.js 3D 场景源文件、PBR 材质配置、食材模型源文件、"
            "色彩和字体规范、图标及第三方许可证。"
        ),
        "2.5D 分层插画、贴纸与菜谱素材来源": (
            "WebGL 3D 场景、食材模型与菜谱素材来源"
        ),
    }
    for table in document.tables:
        for row in table.rows:
            for cell in row.cells:
                text = cell.text.strip()
                if not text:
                    continue
                replacement = next(
                    (
                        target
                        for prefix, target in specific_cells.items()
                        if text.startswith(prefix)
                    ),
                    None,
                )
                if replacement is not None:
                    set_cell_text(cell, replacement)
                elif "2.5D" in text or "贴纸" in text or "米色复古" in text:
                    set_cell_text(cell, normalized_visual_text(text))

    for paragraph in document.paragraphs:
        if paragraph.text.startswith("版本记录"):
            continue
        if any(token in paragraph.text for token in ("贴纸", "米色复古", "分层插画")):
            set_paragraph_text(paragraph, normalized_visual_text(paragraph.text))

    old_figure = find_paragraph(document, "图 1")
    set_paragraph_text(old_figure, "图 1  WebGL 真 3D 冰箱首页视觉基准")
    figure_index = next(
        index
        for index, paragraph in enumerate(document.paragraphs)
        if paragraph._p is old_figure._p
    )
    figure_paragraph = document.paragraphs[figure_index - 1]
    remove_drawings(figure_paragraph)
    figure_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    figure_paragraph.add_run().add_picture(
        str(DESKTOP_CONCEPT),
        width=Inches(6.3),
    )

    confirmation_heading = next(
        paragraph
        for paragraph in document.paragraphs
        if paragraph.style.name == "Heading 1" and "开工确认" in paragraph.text
    )
    anchor = confirmation_heading._p

    def insert_paragraph_before(text: str = "", style: str | None = None):
        paragraph = document.add_paragraph(style=style)
        anchor.addprevious(paragraph._p)
        if text:
            paragraph.add_run(text)
        return paragraph

    heading = insert_paragraph_before(
        "附录 A  WebGL 真 3D 视觉基线",
        "Heading 1",
    )
    heading.paragraph_format.page_break_before = True
    intro = insert_paragraph_before()
    intro.add_run(
        "本附录是 V1.3 的视觉与交互验收口径。概念稿位于 Figma："
    )
    link_run = intro.add_run(FIGMA_URL)
    link_run.font.color.rgb = RGBColor(47, 75, 92)
    link_run.underline = True

    basis = insert_paragraph_before("A.1  视觉与组件基线", "Heading 2")
    basis.paragraph_format.space_before = Pt(10)
    basis_text = insert_paragraph_before()
    basis_text.add_run(
        "视觉主题为温暖现代家电：米白画布、香槟米色拉丝金属、深可可色文字与把手、"
        "鼠尾草绿运行状态和陶土红临期提示。冰箱是唯一主视觉，不使用外部帖子版式、"
        "大面积玻璃拟态、紫色渐变、重复卡片网格或漂浮 emoji 云。"
    )

    matrix_heading = insert_paragraph_before("A.2  状态与验收矩阵", "Heading 2")
    matrix_heading.paragraph_format.space_before = Pt(8)

    # Build the matrix immediately after its heading, before the confirmation heading.
    table = document.add_table(rows=5, cols=3)
    table.style = "Table Grid"
    table.autofit = False
    rows = [
        ("视口 / 状态", "画面内容", "必须通过的交互验收"),
        (
            "Web 桌面 · 关门",
            "四门立式冰箱完整居中；上方左右双门、中部变温抽屉与下部冷冻抽屉清晰分层。",
            "拖拽旋转；点击门或抽屉进入对应状态；不得出现静态截图冒充实时 3D。",
        ),
        (
            "Web 桌面 · 左门开启",
            "左门绕铰链开启，露出内腔、透明层架、食材与柔和照明。",
            "开门后可返回关门态；鼠标命中区域与可见门体一致。",
        ),
        (
            "Web 桌面 · 抽屉开启",
            "中部抽屉沿滑轨向前拉出，可看到抽屉深度、轨道与食材。",
            "门与抽屉互斥切换；动画结束后保持稳定可操作状态。",
        ),
        (
            "移动端 · 首屏",
            "冰箱保持第一视觉，标题、温度切换、摘要与底栏不得遮挡模型。",
            "360 至 430 逻辑像素无横向溢出；触控旋转与点击可正常使用。",
        ),
    ]
    widths = (1.45, 2.55, 2.65)
    for row_index, values in enumerate(rows):
        for column_index, value in enumerate(values):
            cell = table.cell(row_index, column_index)
            cell.width = Inches(widths[column_index])
            set_cell_margins(cell)
            is_header = row_index == 0
            set_cell_text(
                cell,
                value,
                bold=is_header,
                white=is_header,
            )
            if is_header:
                shade_cell(cell, "2F4B5C")
            elif row_index % 2 == 0:
                shade_cell(cell, "EDF3F6")
    anchor.addprevious(table._tbl)

    spacer = insert_paragraph_before()
    spacer.paragraph_format.space_after = Pt(0)

    desktop_image = insert_paragraph_before()
    desktop_image.alignment = WD_ALIGN_PARAGRAPH.CENTER
    desktop_image.add_run().add_picture(
        str(DESKTOP_CONCEPT),
        width=Inches(6.1),
    )
    desktop_caption = insert_paragraph_before("图 A-1  WebGL 真 3D 桌面主屏", "Caption")
    desktop_caption.alignment = WD_ALIGN_PARAGRAPH.CENTER

    mobile_image = insert_paragraph_before()
    mobile_image.alignment = WD_ALIGN_PARAGRAPH.CENTER
    mobile_image.add_run().add_picture(
        str(MOBILE_CONCEPT),
        width=Inches(3.05),
    )
    mobile_caption = insert_paragraph_before("图 A-2  WebGL 真 3D 移动端主屏", "Caption")
    mobile_caption.alignment = WD_ALIGN_PARAGRAPH.CENTER

    document.core_properties.comments = (
        "V1.3 于 2026-10-26 将 2.5D 冰箱首页修订为 WebGL 真 3D。"
    )
    document.save(OUTPUT_SPEC_PATH)


if __name__ == "__main__":
    if len(sys.argv) != 1:
        raise SystemExit("This script updates the repository specification in place.")
    update_spec()
