# 鸿蒙工程外宿测试（不参与 App 编译）

## 为什么放在这里

`entry/src/main/ets/` 下的所有 `.ets` 都会被编译进 App。
FSRS 自检脚本依赖 `fs` / `path` / `process.cwd()` / `process.exit()` 与顶层 `await`，
这些在 ArkTS 中不存在 —— **放在源码树里会直接导致工程编译失败**。

因此它移到本目录，作为开发期工具保留，运行方式不变：

```bash
# 在 fsrs/ 目录下（那里有配套的 mjs 版本）
cd /data/workspace/fsrs && node _selftest.mjs
```

## 上架鸿蒙需要什么

鸿蒙的单元测试框架是 **Hypium**（`@ohos/hypium`），不支持 Node 内置模块。
若要纳入 CI（对应 todo T1-04），需要：

1. 在 `entry/src/ohosTest/ets/test/` 下新建测试文件
2. 用 `describe` / `it` / `expect` 组织断言
3. 读取黄金向量改用 `@ohos.file.fs` 与应用沙箱路径：
   ```ts
   import { fileIo } from '@kit.CoreFileKit';
   // 路径应取 context.filesDir，而非 process.cwd()
   ```
4. 在 `entry/oh-package.json5` 中确认已配置 hypium 依赖（工程骨架里已写入 devDependencies）

## 当前状态

- A 类断言（32 项恒等式）：已可在 Node 下全绿运行
- B 类断言（黄金向量）：需先在本机用 Rust 生成 `vectors.json`，**这是 M2 入口红线**
