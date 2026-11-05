"""Build the V1.4 design addendum with the bundled document runtime.

Previous product specifications are preserved. UI evidence is read from
docs/design/realistic-fridge/implementation when present.
"""
from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'docs/design/realistic-fridge'
OUTPUT = ROOT / '可视化冰箱APP开发设计说明-V1.4.docx'
doc = Document()
section = doc.sections[0]
section.page_width = Inches(8.27)
section.page_height = Inches(11.69)
section.top_margin = section.bottom_margin = Inches(.7)
section.left_margin = section.right_margin = Inches(.78)
section.footer_distance = Inches(.3)

for name in ['Normal', 'Title', 'Subtitle', 'Heading 1', 'Heading 2', 'Caption']:
    style = doc.styles[name]
    style.font.name = 'Microsoft YaHei'
    style.element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'), 'Microsoft YaHei')
    style.font.color.rgb = RGBColor(0, 0, 0)
    style.font.size = Pt(11)
    style.paragraph_format.space_after = Pt(8)
    style.paragraph_format.line_spacing = 1.25
doc.styles['Title'].font.size = Pt(25)
doc.styles['Title'].font.bold = True
doc.styles['Heading 1'].font.size = Pt(18)
doc.styles['Heading 1'].font.bold = True
doc.styles['Heading 1'].paragraph_format.space_before = Pt(0)
doc.styles['Heading 2'].font.size = Pt(13)
doc.styles['Heading 2'].font.bold = True
doc.styles['Caption'].font.size = Pt(9)
for style in doc.styles:
    for border in style.element.xpath('.//w:pBdr'):
        border.getparent().remove(border)

def para(text, style=None):
    return doc.add_paragraph(text, style)

def heading(text):
    doc.add_heading(text, 1)

def page(title):
    p = doc.add_heading(title, 1)
    p.paragraph_format.page_break_before = True

def picture(path, caption, width=6.45):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.keep_with_next = True
    run = p.add_run()
    run.add_picture(str(path), width=Inches(width))
    image = run._r.xpath('.//wp:docPr')[0]
    image.set('descr', caption)
    cap = para(caption, 'Caption')
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER

def table(headers, rows, widths):
    t = doc.add_table(rows=1, cols=len(headers))
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    for column, width in zip(t.columns, widths): column.width = Inches(width)
    properties = t._tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for edge in ['top','left','bottom','right','insideH','insideV']:
        element = OxmlElement(f'w:{edge}')
        for key, value in [('val','single'),('sz','4'),('color','D9D9D9')]: element.set(qn('w:'+key), value)
        borders.append(element)
    properties.append(borders)
    for index, values in enumerate([headers, *rows]):
        row = t.rows[0] if index == 0 else t.add_row()
        row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        if index == 0: row._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
        for cell, value, width in zip(row.cells, values, widths):
            cell.width = Inches(width)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            tcpr = cell._tc.get_or_add_tcPr()
            shade = OxmlElement('w:shd')
            shade.set(qn('w:fill'), '37413C' if index == 0 else ('F3F5F3' if index % 2 == 0 else 'FFFFFF'))
            tcpr.append(shade)
            margins = OxmlElement('w:tcMar')
            for edge in ['top','bottom','left','right']:
                node = OxmlElement('w:'+edge); node.set(qn('w:w'), '95'); node.set(qn('w:type'), 'dxa'); margins.append(node)
            tcpr.append(margins)
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.12
            run = p.add_run(str(value)); run.font.name = 'Microsoft YaHei'; run.font.size = Pt(10)
            run._r.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'), 'Microsoft YaHei')
            run.bold = index == 0
            if index == 0: run.font.color.rgb = RGBColor(255,255,255)
    para('')

footer = section.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
footer.add_run('小满冰箱  V1.4  |  ')
field = OxmlElement('w:fldSimple'); field.set(qn('w:instr'), 'PAGE'); footer._p.append(field)
for run in footer.runs: run.font.size = Pt(9)

doc.add_paragraph('可视化冰箱开发设计说明', 'Title')
para('V1.4  写实厨房与冰箱界面重构  |  2026年10月31日')
heading('1 设计决策')
para('本版采用已选定的 V1 冰箱与厨房概念图作为外观和结构参考，替换旧版香槟米色、复古把手和装饰贴纸风格。首页以可交互的不锈钢冰箱和真实比例的厨房空间为主体，用户可以查看库存、打开门与抽屉，并管理食材。')
picture(ASSETS / 'fridge-kitchen-v1.png', '图 1  已确认的 V1 厨房场景概念图')
para('V1.3 及更早文档保留为历史需求记录。本版优先约束视觉、结构和前端交互；账号、家庭权限、库存版本、接口安全与交易规则继续沿用工程契约。概念图与 PSD 为视觉参考，运行时厨房使用实时几何模型。')

page('2 冰箱外观与内部结构')
picture(ASSETS / 'fridge-concept-v1.png', '图 2  V1 不锈钢冰箱和内部储存结构', 5.2)
para('建模采用约 900 × 1850 × 720 mm 的宽高深比例，不作为家电生产工程尺寸。柜体由侧壁、后壁、顶板与隔板围成开放内腔，门和抽屉以真实支点运动。')
table(['结构', '实现要求', '存储语义'], [
    ['上部双门', '两扇保温门独立绕侧铰链旋转，配灰色密封条和内侧瓶架', '左右门共用冷藏室'],
    ['冷藏内腔', '三层玻璃搁板、金属边条、安装导轨和后部风道', '冷藏食材按当前快照放置'],
    ['双保鲜盒', '左右两个透明盒体，白色底板与前沿把手', '冷藏室内部结构'],
    ['中部变温', '浅抽屉、分隔托盘和金属滑轨', '独立变温区'],
    ['下部冷冻', '深抽屉、上滑篮和下分隔篮', '独立冷冻区'],
    ['厨房常温柜台', '木色柜台上的独立储物位置', '常温食品不放在冷藏门内'],
], [1.1, 3.5, 1.95])

page('3 桌面界面与视觉规范')
para('桌面采用固定侧导航、页面标题、宽厨房视口和库存侧栏。标题显示真实冰箱名称、当前家庭与角色；库存摘要使用完整快照。厨房视口上方选择分区，下方提示拖动和开合方式。')
desktop = ASSETS / 'implementation/desktop-home.png'
if desktop.exists(): picture(desktop, '图 3  V1.4 桌面界面真实浏览器截图')
table(['用途', '色值', '规则'], [
    ['页面底色', '#F4F5F2', '石材灰，避免大面积渐变和装饰圆球'],
    ['卡片表面', '#FFFFFF', '1 px 浅灰边框，圆角 8 至 16 px'],
    ['主要文字', '#222C27', '深灰，正文保持清晰对比'],
    ['主要操作', '#293D32', '深绿色，用于选中和确认'],
    ['辅助木色', '#AE9370', '来自厨房橱柜材质，克制使用'],
    ['过期与临期', '#AF5147', '同时提供文字状态，不仅依赖颜色'],
], [1.35, 1.15, 4.05])
para('温度显示为储存参考，不表示已有传感器遥测。首页菜谱入口读取用户的后续操作意图，不再展示写死的匹配百分比；真实覆盖率由菜谱页结合库存计算。')

page('4 移动端与降级体验')
para('移动端保留底部导航，标题和库存摘要在上，厨房模型占据主要视区，分区库存与操作位于下方。分区选择横向滚动；主页面纵向滚动，模型视口内的拖动用于观察结构。')
mobile = ASSETS / 'implementation/mobile-home.png'
if mobile.exists(): picture(mobile, '图 4  390 像素宽度的真实浏览器界面', 2.7)
para('Web 使用同源三维场景。浏览器不支持 WebGL、模块加载失败或上下文丢失时，显示可读提示，食材清单继续可用。Android 兼容视图明确标注 V1 外观参考图，并说明实际食材以清单为准，不将参考图当作实时库存。')
para('触控和键盘均可控制门体与抽屉。模型按钮提供明确名称；降低动态效果偏好时直接到达目标状态。小屏幕不得出现横向溢出，正文放大后仍可滚动访问业务操作。')

page('5 交互状态与数据同步')
table(['操作', '视觉变化', '数据影响'], [
    ['展开概览', '双门打开，变温与冷冻部分拉出，回到默认镜头', '仅视图状态'],
    ['左门或右门', '对应门绕自己的外侧铰链开合', '均选择冷藏分区'],
    ['变温或冷冻', '对应抽屉沿滑轨移动，其他部件保留状态', '选择对应分区'],
    ['全部关闭', '门与抽屉全部关闭', '不修改库存'],
    ['常温分区', '视角关注厨房侧柜台', '不将冷藏门当作常温室'],
    ['家庭切换', '重新加载该家庭快照，重建或清空食材几何', '仍通过 Gateway 校验权限'],
    ['筛选清单', '独立展示筛选结果', '完整库存和三维快照不变'],
], [1.2, 3.55, 1.8])
para('Flutter 与 iframe 通过同源 postMessage 交换数据。父页面同时校验消息来源窗口、origin 和消息类型，忽略无效 JSON；场景只接收父窗口消息。ready 握手和 load 兜底都可重发当前库存，避免首次加载漏传。')
para('库存消息只包含记录 ID、名称、分类、数量和分区，不携带令牌。数量为正的食材记录转换为简化模型；真实空库存显示空层架。每个分区最多展示 12 条几何记录，更多数据仍在清单中完整呈现。一个模型代表一条记录，不等同于件数。')
para('键盘数字 1 至 4 对应冷藏、变温、冷冻和常温；0 回到概览；Escape 关闭冰箱。相机根据视口比例计算距离，并限制旋转范围，保证冰箱的门、顶板和抽屉不被裁切。')

page('6 业务能力与权限保持')
para('本轮重构用户端表现层，不改变现有服务边界和接口响应。Maven 服务、Flyway 迁移、库存乐观锁及家庭权限继续作为业务真实性的来源，用户端不因视觉状态而绕过鉴权。')
table(['业务', '现有能力', '角色或状态约束'], [
    ['账号会话', '注册、登录、刷新、退出', '安全保存会话，失效返回登录页'],
    ['家庭协作', '创建、邀请码加入、切换、成员治理、转交', 'OWNER 管理，EDITOR/VIEWER 受限'],
    ['冰箱引导', '无家庭入口、OWNER 创建冰箱', '不把 403 或网络错误伪装为空库存'],
    ['食材管理', '添加、详情、使用、移动、丢弃', 'OWNER/EDITOR 写入，VIEWER 只读'],
    ['组合筛选', '名称、分类、标签交集、分区、日期和排序', '独立结果，失败保留条件可重试'],
    ['菜谱匹配', '目录、详情、库存覆盖率、临期匹配', '跟随当前家庭完整库存'],
], [1.1, 3.35, 2.1])
para('服务端写入继续使用 version 乐观锁。冲突、无权限或网络失败时，应显示错误并允许刷新，不能用视觉动画制造成功假象。真实账号与演示模式保持区分，演示入口不能写入真实冰箱。')
para('时间线撤销与恢复、WebSocket 同步、做饭扣减、交易闭环及运营后台真实 API 尚属于后续业务阶段。本轮不以界面重构完成为由将这些功能标为已完成。')

page('7 工程实现与资源管理')
para('用户端仍为 Flutter Android/Web。首页、登录注册壳、侧导航、家庭和菜谱页面采用统一主题。3D 使用本地 Three.js 运行文件，不依赖 CDN。V1 概念 PNG、PSD 与生成说明保存在仓库设计目录中。')
table(['模块', '职责'], [
    ['fridge-model.js', '开放柜体、门铰链、密封条、层架、保鲜盒、抽屉、篮筐与食材几何'],
    ['kitchen-scene.js', '木纹与石材纹理、橱柜、窗户、墙砖、地面、水槽和常温柜台'],
    ['fridge-state.js', '可测试的分区、部件状态、输入规范化和相机适配'],
    ['fridge3d.js', '渲染器、灯光、相机、拾取、动画、事件与资源清理'],
    ['webgl_fridge_view_web.dart', '同源 iframe、握手、消息校验、分区与库存同步'],
    ['fridge_home_page.dart', '家庭快照、响应式页面、真实摘要与业务操作入口'],
], [2.35, 4.2])
para('渲染采用金属与玻璃材质、程序化纹理、环境光及软阴影。像素比上限为 1.75，阴影贴图上限 2048。减少动态效果时跳过渐进动画；页面退出时停止渲染循环并释放 GPU 资源。')
para('场景入口与模块使用 realistic-v1.4 资源修订参数，避免已有客户端的旧缓存将新界面与旧冰箱模型混用。外观参考图通过 Flutter assets 打包，PSD 不进入运行包。依赖锁文件保持原版本，本轮不升级 Flutter 第三方依赖。')
para('本地验证命令为 node --test scripts/tests/fridge3d.test.mjs、dart analyze lib test、flutter test --no-pub、flutter build web --release --no-pub。真实环境验收使用 Smoke-FamilyWorkspace.ps1 与 Smoke-FoodFilters.ps1，所有请求经过 Gateway。')

page('8 验收要求与阶段审查')
table(['编号', '验收要求', '证据方式'], [
    ['UI 01', '桌面显示写实厨房和完整冰箱，库存摘要真实', '桌面浏览器与截图'],
    ['UI 02', '390 像素无横向溢出，按钮和清单可达', '移动浏览器与 Widget 回归'],
    ['3D 01', '左右门共用冷藏，常温位于厨房柜台', '结构测试与浏览器分区检查'],
    ['3D 02', '铰链、独立抽屉、双层篮和全部关闭可用', '状态测试与开合截图'],
    ['DATA 01', '真实库存传入模型，空库存清除几何', '输入规范化与真实账号检查'],
    ['DATA 02', '筛选、使用、移动、丢弃和权限保持', 'Flutter 测试及 Gateway 验收'],
    ['DOC 01', '设计基线、阶段状态和验收记录一致', '文档内容审查与逐页渲染'],
], [1.0, 3.5, 2.05])
para('每个阶段必须先完成代码审查，修复正确性问题并验证，再进入下一阶段。本轮已先检查结构和状态机，再集成界面与库存消息，最后审查响应式布局、消息边界、错误恢复和业务回归。最终执行结果以 docs/开发状态.md 和 docs/reviews 下本轮记录为准。')
para('前一业务阶段记录的 Flutter 焦点渲染异常继续跟踪，不能因为新页面可用就将历史异常默认为已修复。概念图的摄影质感是后续材质优化参考；实时模型保留简化食材几何，尚未提供扫描级食品资产和生产家电工程结构。')
para('后续依次推进操作时间线及撤销恢复、家庭实时同步、做饭扣减和交易闭环。正式发布前仍需 Android 独立签名、完整基础设施验证、授权素材补齐和最终验收。')

doc.core_properties.title = '可视化冰箱开发设计说明'
doc.core_properties.subject = 'V1.4 写实厨房与冰箱界面重构'
doc.core_properties.author = 'Smart Fridge'
doc.save(OUTPUT)
print(OUTPUT)
