#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
依赖方向检查 —— 防止五层架构退化成一团

允许方向（严格单向）：
    ui  →  domain  →  data  →  common
                 ↘ scheduler ↗

禁止：
    · 反向依赖（common 引用 data 等）
    · 跨层依赖（ui 直接引用 data）
    · 循环依赖（任意两层互相引用）
    · common 层引用任何上层（common 必须是最底层）

用法：
    python3 scripts/check_deps.py           # 检查并报告
    python3 scripts/check_deps.py --strict  # 有问题时退出码非 0（建议挂 CI / git pre-commit）
"""

import os
import re
import sys
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..',
                    'entry', 'src', 'main', 'ets')

# 层级：数字越小越底层
LAYERS = {
    'common': 0,
    'data': 1,
    'domain': 2,
    'ui': 3,
}

SKIP_DIRS = {'entryability', 'resources', 'test'}

IMPORT_RE = re.compile(r"""import\s+(?:\{[^}]*\}|\w+)\s+from\s+['"]([^'"]+)['"]""")


def layer_of(rel_path: str):
    """返回文件所属层名，不属于任何层返回 None"""
    parts = rel_path.split(os.sep)
    for p in parts:
        if p in LAYERS:
            return p
    return None


def resolve(cur_dir: str, spec: str):
    """把相对 import 解析成相对 ets 的路径"""
    if not spec.startswith('.'):
        return None  # 三方包 / 系统包，不检查
    target = os.path.normpath(os.path.join(cur_dir, spec))
    return target


def main():
    strict = '--strict' in sys.argv
    root = os.path.abspath(ROOT)
    if not os.path.isdir(root):
        print('找不到源码目录：%s' % root)
        return 2

    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith('.ets'):
                files.append(os.path.join(dirpath, fn))

    # 文件 → 层
    file_layer = {}
    for f in files:
        rel = os.path.relpath(f, root)
        file_layer[f] = layer_of(rel)

    # 层 → 引用了哪些层
    edges = defaultdict(set)
    problems = []

    for f in files:
        rel = os.path.relpath(f, root)
        cur_layer = layer_of(rel)
        cur_dir = os.path.dirname(f)
        try:
            src = open(f, encoding='utf-8').read()
        except Exception:
            continue
        for m in IMPORT_RE.finditer(src):
            spec = m.group(1)
            tgt = resolve(cur_dir, spec)
            if tgt is None:
                continue
            # 补扩展名
            for cand in (tgt + '.ets', os.path.join(tgt, 'index.ets')):
                if os.path.exists(cand):
                    tgt = cand
                    break
            else:
                continue
            tgt_rel = os.path.relpath(tgt, root)
            tgt_layer = layer_of(tgt_rel)
            if tgt_layer is None or cur_layer is None:
                continue
            edges[cur_layer].add(tgt_layer)
            # 规则 1：不允许反向（引用更高层）
            if LAYERS[tgt_layer] > LAYERS[cur_layer]:
                problems.append('反向依赖  %s(%s) → %s(%s)'
                                % (rel, cur_layer, tgt_rel, tgt_layer))
            # 规则 2：不允许跨层 —— UI 不得绕过 domain 直接取数据
            #         注意 common 是横切工具层（日志 / 时间 / 结果类型），
            #         任何层都可以用，这是刻意开放的，不算违规
            if cur_layer == 'ui' and tgt_layer == 'data':
                problems.append('跨层依赖  %s(ui) → %s(data)，应改为依赖 domain'
                                % (rel, tgt_rel))
            # 规则 3：common 必须是最底层，不得反向依赖任何层
            if cur_layer == 'common' and tgt_layer != 'common':
                problems.append('common 层不得依赖上层  %s → %s' % (rel, tgt_rel))

    # 规则 4：循环依赖
    for a in LAYERS:
        for b in LAYERS:
            if a != b and b in edges.get(a, set()) and a in edges.get(b, set()):
                if a < b:
                    problems.append('循环依赖  %s ⇄ %s' % (a, b))

    print('=' * 56)
    print('依赖方向检查（%d 个 .ets 文件）' % len(files))
    print('=' * 56)
    print('\n允许方向：ui → domain → data → common\n')
    print('实际引用关系：')
    for a in sorted(LAYERS, key=lambda x: LAYERS[x]):
        deps = sorted(edges.get(a, set()), key=lambda x: LAYERS[x])
        print('  %-8s → %s' % (a, ', '.join(deps) if deps else '（无）'))

    print()
    if problems:
        # 去重
        seen = []
        for p in problems:
            if p not in seen:
                seen.append(p)
        print('发现 %d 处问题：' % len(seen))
        for p in seen:
            print('  ✗ ' + p)
        print()
        if strict:
            return 1
    else:
        print('✓ 依赖方向全部合规')
    return 0


if __name__ == '__main__':
    sys.exit(main())
