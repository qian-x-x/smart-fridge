# 答辩资料整理与内容审查

日期：2026-11-10（Asia/Shanghai）。用户要求根据根目录评分表，总结本作品的技术使用说明及可能提问。本轮为文档工作，没有切换产品开发阶段，没有修改业务源码、数据库、运行配置或评分表，没有提交、推送、部署。

## 范围与结论

读取 `docs/开发状态.md` 后，逐项提取评分表前3个工作表，并核对最终F1至F10的分值与要求。围绕当前正式家庭业务，检查Java、Flutter、SQL、配置、OpenAPI、启动说明与历史验收材料的相应实现。审查本次新增说明文档的完整内容与Word输出，不将工作区此前的UI差异描述为本次新修改或再次审查通过。

交付 [Word文档](../答辩/小易冰箱技术使用说明与答辩问答.docx) 及 [Markdown源稿](../答辩/小易冰箱技术使用说明与答辩问答.md)。共20页、19章、50道问答，包含评分重点、8分钟演示、真实技术用途、故障推理、边界和代码查阅位置。最终评分表合计75分，其中F3至F8技术解释共40分，已准确区分两门课程的分项归属。

**本轮文档内容审查、15项自动核对和20页逐页视觉检查通过。没有执行本轮产品自动化测试或真实环境端到端验收，不宣布新的产品阶段或安全验收通过。**

## 内容核对与纠正

| 重点 | 本轮处理 |
| --- | --- |
| 权限与信任边界 | 对照 `JwtGatewayFilter`、auth的 `JwtAuthInterceptor`、fridge和recipe的 `GatewayUserInterceptor`。明确网关会清理伪造身份头，auth会重新验证令牌；不能说所有下游都已独立验签。业务端口直接暴露时的身份伪造或操作人归属风险记录为待办，未在本轮修复。 |
| 家庭与数据归属 | 按auth、fridge、recipe分库说明职责，解释跨家庭角色校验；区分逻辑引用和物理外键。旧order、stock和Vue后台只列为历史示例，不作为家庭补货实现。 |
| 异步及幂等 | 家庭创建按用户与requestId唯一；客户端仅当前进程保留失败键。做饭服务端同键幂等，但Flutter每次cook生成新键，且同键异载荷没有统一比较，故不声称所有失败重试均安全。 |
| 失败恢复 | 对照AT阶段一提交、pending家庭可见性、新事务读取及AsyncCommitting处理。明确HTTP失败不能证明远端没写，Trace也不能独立证明回滚。 |
| 配置刷新 | `FridgeSettings`支持刷新，`WorkspaceProtection`启动时装载规则而未监听刷新。区分Nacos配置刷新和前端实时推送；不能把所有阈值描述为可热更新。 |
| 接口及结果 | 区分首次201、重放200、冲突409、入口429、依赖503；区分requestId、XID、自定义X-Request-Id和SkyWalking Trace ID。保留旧创建接口兼容性的事实，没有修改接口。 |
| 当前功能边界 | Web实时Three.js，Android参考图；菜谱按种类规则匹配；18道新菜谱在隔离运行链路验收。明确未做真机、正式签名、实时同步、生产高可用和持续压测。 |
| 验收日期 | 11月9日业务223项、11月10日V2首次实施及后续色调/家庭入口检查分别列出，未相加冒充唯一总量，也没有当作本轮重新执行。 |

## 文档生成及检查中的修正

1. **证据文件名大小写**：把Nacos审查路径纠正为仓库实际存在的 `2026-11-08-N1-nacos.md`；所有可解析完整仓库路径经过存在性检查。
2. **渲染依赖缺失**：先执行技能提供的 `render_docx.py`，日志确认Windows运行包缺少LibreOffice，报 `FileNotFoundError: LibreOffice soffice.exe was not found on PATH`。改用专用隐藏Word实例只读打开文档、导出内部检查PDF，再由运行包Poppler生成20张PNG。没有使用用户安装的LibreOffice。首次Word导出后退出清理报RPC不可用，文件已经导出；修正仅忽略该特定退出状态，最终完整导出命令退出0。
3. **内容一致性校验误判**：第一次比对将API通配符 `/api/v1/**` 的星号当作Markdown加粗标记，导致1项校验失败。修正校验器保留行内代码中的通配符，最终15项全部通过；并非删掉通配符规避检查。
4. **表达及最终分页**：将无实际图片的“服务边界图”标签改为“服务关系”。重建并再次导出20页，比较页图哈希，只有第5页变化；再次查看第5页，其余19页与此前逐页查看版本相同。

## 本轮实际验证

下列命令使用workspace依赖加载器返回的Python、Node和Poppler。生成器、PDF及页图为 `output/defense-2026-11-10/` 下的内部材料，最终交付只链接Word与Markdown。

| 检查 | 命令或方式 | 本轮结果 |
| --- | --- | --- |
| 评分表只读提取 | Python标准库ZIP和XML读取，保存JSON，不导出或改写xlsx | 4个工作表读取，前3表用于备考 |
| Word生成 | `python output/defense-2026-11-10/build_defense.py` | 成功，50题、10张表、20个计划页 |
| 首选渲染器 | `python <documents-skill>/render_docx.py <docx> --output_dir <render> --emit_pdf --verbose` | 依赖缺失，已诊断并采用上述回退 |
| 最终Word导出 | `./output/defense-2026-11-10/export_word_pdf.ps1` | 退出0，20页；只关闭本次专用实例 |
| PNG生成与视觉检查 | bundled `pdf2image`及Poppler，137 DPI，逐页查看1至20页；最终第5页复查 | 无裁切、重叠、缺字、表格截断或空白溢出页 |
| 内容与结构 | `python output/defense-2026-11-10/validate_defense.py` | 15/15：题号、评分、分值合计、Word逐段内容、ZIP CRC、表格、路径、页数、PNG及历史证据核对等 |
| 差异格式 | `git diff --check -- docs/答辩 docs/开发状态.md docs/reviews/2026-11-10-defense-materials.md docs/reviews/evidence/2026-11-10-defense-materials`，新增文本另扫尾部空格 | 通过 |

机器可读结果与源文件/产物SHA256见 [validation.json](evidence/2026-11-10-defense-materials/validation.json)。历史业务JSON只是读取检查，没有重新运行对应接口，也没有生成新的业务通过数。

## 尚未完成及验收边界

- 新电脑部署复现、最终PPT、当前工作区完整交付包尚未完成；旧归档不包含本次全部改动。
- 本轮没有重跑Maven、Flutter、真实API、Nacos动态发布、Seata故障注入或SkyWalking新请求；没有重新构建Web或APK。
- Android真机、硬件GPU、多浏览器、正式签名、持续压测和中间件高可用仍待验收。
- 业务端口信任边界、做饭未知结果重试和同键异载荷处理为源码复核发现的现有待办。本轮只准确记录，不把未修复问题标为通过，也不以文档任务为由擅自扩大到产品实现。
