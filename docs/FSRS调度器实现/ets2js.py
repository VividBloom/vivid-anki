#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 FsrsScheduler.ets 转成可直接在 Node 里跑的 ESM。
只做「去类型」处理，逻辑逐行对应 —— 保证测试跑的就是交付的那份代码。
"""
import re, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "FsrsScheduler.ets")
DST = os.path.join(HERE, "_FsrsScheduler.mjs")

s = open(SRC, encoding="utf-8").read()

# 0) 先把跨行函数签名折叠成单行：",\n    参数名: Type" -> ", 参数名: Type"
for _ in range(4):
    s2 = re.sub(r",\n\s+(\w+)\s*:\s*", r", \1: ", s)
    if s2 == s:
        break
    s = s2

# 1) enum -> const 对象
def enum_sub(m):
    name = m.group(1)
    body = m.group(2)
    pairs = re.findall(r"(\w+)\s*=\s*(-?\d+)", body)
    items = ", ".join(f"{k}: {v}" for k, v in pairs)
    return f"export const {name} = {{ {items} }};"

s = re.sub(r"export\s+enum\s+(\w+)\s*\{([^}]*)\}", enum_sub, s)

# 2) export const X: type =  ->  export const X =
s = re.sub(r"(export\s+const\s+\w+)\s*:\s*[\w\[\]<>.]+\s*=", r"\1 =", s)

# 3) 方法返回类型  ): Type {  ->  ) {
s = re.sub(r"\)\s*:\s*[\w\[\]<>.|]+\s*\{", ") {", s)

# 4) 参数类型  (a: number, b: number = 0)  ->  (a, b = 0)
def params_sub(m):
    inner = m.group(1)
    # 逐个参数：去掉 `name: type` 中的 `: type`
    parts = []
    depth = 0
    cur = ""
    for ch in inner:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)

    out = []
    for p in parts:
        # 匹配  name: Type  （Type 不含 = 和逗号）
        mm = re.match(r"^(\s*)(\w+)\s*:\s*([A-Za-z_][\w\[\]<>.|]*)\s*(.*)$", p)
        if mm:
            indent, name, typ, rest = mm.groups()
            out.append(f"{indent}{name} {rest}".rstrip())
        else:
            out.append(p)
    return "(" + ",".join(out) + ")"

s = re.sub(r"\(([^\n()]*\w\s*:\s*[\w\[\]<>.|]+[^\n()]*)\)", params_sub, s)

# 5) 类字段 / 私有字段声明：  private w: number;   或   stability: number;
s = re.sub(r"^\s*(private\s+)?\w+\s*:\s*[\w\[\]<>.]+;\s*$", "", s, flags=re.M)

# 6) 类字段带初始值：  stability: number = 0;
s = re.sub(r"^(\s*)(private\s+)?(\w+)\s*:\s*[\w\[\]<>.]+\s*=\s*(.+);\s*$",
           r"\1\3 = \4;", s, flags=re.M)

# 7) 局部变量类型：  let x: number = 0;
s = re.sub(r"\b(let|const|var)\s+(\w+)\s*:\s*[\w\[\]<>.]+(\s*=)", r"\1 \2\3", s)
s = re.sub(r"\b(let|const|var)\s+(\w+)\s*:\s*[\w\[\]<>.]+\s*;", r"\1 \2;", s)

# 8) 剩余的类型注解兜底（如 catch (e: any) ）
s = re.sub(r"catch\s*\((\w+)\s*:\s*[\w\[\]<>.|]+\)", r"catch (\1)", s)

# 8.5) JS class 不支持 private 修饰符
s = re.sub(r"^(\s*)private\s+(?=\w)", r"\1", s, flags=re.M)

# 9) 移除 import type 行
s = re.sub(r"^import\s+type\s+.*$", "", s, flags=re.M)

open(DST, "w", encoding="utf-8").write(s)
print("已生成 %s (%d 行)" % (DST, len(s.splitlines())))

# 粗查：是否还有明显的类型注解残留
bad = []
for i, ln in enumerate(s.splitlines(), 1):
    t = ln.strip()
    if t.startswith("*") or t.startswith("//") or t.startswith("/*"):
        continue
    if re.search(r"\w\s*:\s*(number|string|boolean|MemoryState|SchedulingInfo|Rating)\b", t):
        # 排除三元表达式与对象字面量
        if "?" in t or "{" in t:
            continue
        bad.append((i, t))
if bad:
    print("!! 可能残留类型注解：")
    for i, t in bad[:12]:
        print("   %d: %s" % (i, t[:90]))
    sys.exit(1)
print("类型注解清理完成")
