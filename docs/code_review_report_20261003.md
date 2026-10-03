# 代码审查报告 (2026-10-03)

## 1. 总体结论
项目架构设计清晰，严格遵守了 `ui → domain → data → common` 的单向依赖约束。核心算法（FSRS-6）与数据库设计符合高性能与健壮性要求。但在 UI 层资源管理方面存在多处**高风险内存泄漏**，需立即修复以确保内测期间 0.1% 崩溃率的目标。

## 2. 架构与设计审计
- **依赖合规性**：经 `check_deps.py` 验证，全量 72 个文件均符合单向分层，未发现反向引用或跨层耦合。
- **数据库约束**：`card.deck_id` 与 `revlog.card_id` 刻意去外键化设计已在 `Schema.ets` 中落实，支持业务上的软删除逻辑。
- **职责划分**：
    - `data` 层：仅负责持久化与事务。
    - `domain` 层：封装调度算法与生命周期服务。
    - `ui` 层：负责视觉呈现与用户交互，逻辑通过服务解耦。

## 3. 核心问题汇总 (P0)

### 3.1 内存泄漏：WindowSizeChange 监听未释放
- **文件**：`entry/src/main/ets/entryability/EntryAbility.ets`
- **问题**：在 `onWindowStageCreate` 中注册了 `windowSizeChange` 监听器，但在 `onWindowStageDestroy` 中未执行 `off` 操作。
- **影响**：导致 Ability 销毁后窗口对象仍持有 Ability 引用，产生内存泄漏。

### 3.2 内存泄漏：AVPlayer 状态监听未清理
- **文件**：`entry/src/main/ets/ui/pages/ReviewPage.ets`
- **问题**：`playAudio` 方法在 `this.audioPlayer` 上重复注册 `stateChange` 监听器，且在 `aboutToDisappear` 中仅执行了 `release()`，未清理监听器。
- **影响**：多次播放音频会导致监听器堆积，增加 OOM 风险。

### 3.3 内存泄漏：CustomDialogController 未置空
- **文件**：`entry/src/main/ets/ui/pages/CardsPage.ets`, `entry/src/main/ets/ui/pages/CardEditPage.ets`
- **问题**：使用了 `CustomDialogController` 但未在 `aboutToDisappear` 中将其显式置为 `null`。
- **影响**：根据 HarmonyOS 开发规范，这是 ArkUI 常见的泄漏点，会导致页面销毁后弹窗控制器及关联 UI 树无法回收。

### 3.4 安全漏洞：导入模块的任意文件读取 (Zip Slip / Path Traversal)
- **文件**：`entry/src/main/ets/domain/io/ImportService.ets`
- **问题**：在处理 `.apkg` 媒体映射表时，未校验内部文件名是否包含路径穿越字符（如 `../`），直接将其拼接用于本地文件读取。
- **影响**：恶意伪造的导入包可通过目录穿越，读取应用沙箱内任意敏感文件并打包为学习媒体，造成严重的数据泄露。
- **修复**：已在 `fetchAnkiMediaMapping` 数据解析后加入路径安全校验，过滤所有含 `/`, `\`, `..` 的非法映射键。

## 4. 逻辑漏洞与变量完整性
- **类型安全**：`SettingsPage.ets` 中存在多处 `as any` 强制转换（Line 48, 52），建议定义索引签名或使用泛型以增强编译期检查。
- **冗余变量**：`CardEditPage.ets` 中的 `isSaving` 状态已定义但目前无实际赋值逻辑，建议在更新功能上线时补全或先移除。
- **空值保护**：`ReviewPage.ets` 的 `loadCard` 中已包含 `cardId` 校验，但建议在 `MediaItem` 中增加对 `path` 的二次存在性检查。

## 5. 修复建议与行动项
1.  **立即修复**：针对上述 P0 级内存泄漏点编写修复补丁。
2.  **规范同步**：更新 `aboutToDisappear` 的标准实现模板，要求包含所有 Controller 的置空。
3.  **类型重构**：消除 `SettingsPage` 中的 `any` 类型转换。

---
报告人：TRAE 代码助手
日期：2026-10-03
