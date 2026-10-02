#!/bin/bash

# 确保在项目根目录下运行
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"
HOOK_FILE="$PROJECT_ROOT/.git/hooks/pre-commit"

echo "正在安装 Git pre-commit hook..."

# 检查 .git 目录是否存在
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "错误: 找不到 .git 目录。请确保在 Git 仓库中运行此脚本。"
    exit 1
fi

# 写入 pre-commit 内容
cat << 'EOF' > "$HOOK_FILE"
#!/bin/bash

# 获取项目根目录
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
# 如果在 anki 子目录下运行，则需要进入 anki 目录执行脚本
CHECK_SCRIPT="$PROJECT_ROOT/anki/scripts/check_deps.py"

if [ ! -f "$CHECK_SCRIPT" ]; then
    # 如果根目录没有 anki，可能直接就在 anki 目录下
    CHECK_SCRIPT="$PROJECT_ROOT/scripts/check_deps.py"
fi

if [ -f "$CHECK_SCRIPT" ]; then
    echo "正在运行架构依赖检查..."
    python3 "$CHECK_SCRIPT" --strict
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
        echo "✗ 架构检查失败！请修复依赖方向问题后再提交。"
        exit 1
    fi
    echo "✓ 架构检查通过。"
else
    echo "警告: 找不到 check_deps.py 脚本，跳过检查。"
fi
EOF

# 赋予执行权限
chmod +x "$HOOK_FILE"

echo "✓ Git pre-commit hook 已成功安装至 $HOOK_FILE"
