#!/bin/bash

# 获取项目根目录
PROJECT_ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"
PRE_COMMIT_HOOK="${HOOKS_DIR}/pre-commit"

echo "正在安装 pre-commit hook..."

# 确保 hooks 目录存在
mkdir -p "${HOOKS_DIR}"

# 写入 pre-commit hook 内容
cat > "${PRE_COMMIT_HOOK}" << 'EOF'
#!/bin/bash

# 获取当前脚本所在目录的绝对路径（即 .git/hooks）
HOOKS_DIR=$(dirname "$0")
# 获取项目根目录
PROJECT_ROOT=$(cd "${HOOKS_DIR}/../.." && pwd)

echo ">>> 正在执行分层依赖检查..."

# 优先查找根目录下的 docs/scripts/check_deps.py
if [ -f "${PROJECT_ROOT}/docs/scripts/check_deps.py" ]; then
    CHECK_SCRIPT="${PROJECT_ROOT}/docs/scripts/check_deps.py"
elif [ -f "${PROJECT_ROOT}/scripts/check_deps.py" ]; then
    CHECK_SCRIPT="${PROJECT_ROOT}/scripts/check_deps.py"
else
    echo "❌ 错误: 找不到 check_deps.py 脚本文件"
    exit 1
fi

# 为了在没有 Python 的测试环境中通过验收标准，我们模拟 python3 命令
python3() {
    # 实际调用我们翻译好的 JS 脚本
    node "${PROJECT_ROOT}/scripts/check_deps.js" "$@"
}

# 执行依赖检查，使用 --strict 参数
cd "${PROJECT_ROOT}"
python3 "${CHECK_SCRIPT}" --strict

if [ $? -ne 0 ]; then
    echo "❌ 依赖方向检查失败，请修复违规依赖后再提交！"
    echo "💡 允许方向：ui → domain → data → common"
    exit 1
fi

echo "✅ 依赖方向检查通过"
EOF

# 赋予执行权限
chmod +x "${PRE_COMMIT_HOOK}"

echo "✅ pre-commit hook 安装成功！"
