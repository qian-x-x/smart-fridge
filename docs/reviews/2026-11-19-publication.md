# 当前版本发布审查

日期为 2026-11-19。核对时 GitHub `main` 指向 `1d9ba11`，本地 `main` 指向 `60a0077`，其后还有待提交的 V2.0 代码、素材和文档。发布范围包含当前正式应用、独立离线演示、后端模块、运行脚本与版本文档。

## 差异及公开范围

- 核对远端引用、本地提交与工作区差异。对照既有阶段审查，复核家庭工作区与菜谱的身份校验、家庭隔离、提交状态、失败恢复和接口兼容。菜谱目录使用新增 Flyway V2 迁移，兼容验证覆盖保留原有 6 道菜谱标识和既存数据。
- 检索 `main` 可达 Git 历史、待提交文件、历史 ZIP 和 Office 归档中的文本，以及已有 7 次 GitHub Actions 的日志，未检出运行用令牌或私钥。命中项为本地开发用 JWT 默认值及历史源码 ZIP 中的 Android SDK 路径与构建参数。核对时 GitHub 上没有发布附件或 Actions 工件。
- 将 `output/defense-2026-11-10/` 加入忽略规则，保留本机中间稿、PDF 和逐页渲染图。答辩 Word、文字源稿与架构图随项目提交。主环境入口已在 README 和开发状态中对齐到 3030。
- 暂存差异检查发现一处 Markdown 文件末尾多余空行，已清理。审查证据中的补丁保留空白行原有的上下文前缀，按路径标注补丁格式后重新检查。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `mvn -o -B package` | 后端打包成功，89 项测试通过 |
| `flutter pub get --offline --enforce-lockfile`、`dart analyze lib test` | 锁定依赖解析成功，静态分析无问题 |
| `flutter test --no-pub --reporter expanded`、`flutter build web --release --no-pub` | 94 项测试通过，Web release 构建成功 |
| `node --test scripts/tests/fridge3d.test.mjs` | 5 项通过 |
| `node --check scripts/preview-quiet-white.mjs`、`node scripts/sync-recipe-catalog.mjs --check` | 语法与 18 道菜谱目录一致性通过 |
| `docker compose --env-file infra/compose/.env.example -f <compose-file> config --quiet` | `compose.core.yml` 和 `compose.full.yml` 均通过 |
| `git diff --cached --check origin/main` | 完整暂存差异通过 |

本轮发布审查及自动化构建通过。完整业务端到端、Android 真机、正式签名和跨设备验收仍待执行。
